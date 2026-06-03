# frozen_string_literal: true

require "mini_magick"

module Tsuzura
  # Applies edit_stack to the original file attachment and writes the web JPEG.
  class EditStackRenderer
    MAX_EDGE = 2048
    JPEG_QUALITY = 85

    class << self
      def processing_available?
        return @processing_available unless @processing_available.nil?

        sample = Rails.root.join("test/fixtures/files/sample.jpg")
        @processing_available = sample.exist? && probe_processor(sample)
      end

      def probe_processor(path)
        if vips_available?
          Vips::Image.new_from_file(path.to_s)
          return true
        end

        out = Tempfile.new(["tsuzura-probe", ".jpg"])
        ImageProcessing::MiniMagick.source(path).resize_to_limit(8, 8).call(out.path)
        true
      rescue StandardError
        false
      ensure
        out&.close!
      end

      def vips_available?
        require "vips"
        true
      rescue LoadError
        false
      end
    end

    def initialize(media_item)
      @item = media_item
    end

    def call
      return false unless @item.file.attached?
      return false unless @item.file.content_type.in?(MediaItem::IMAGE_CONTENT_TYPES)

      stack = EditStack.normalize(@item.edit_stack)
      src = download_original_to_tempfile
      processed = render_stack(src.path, stack)
      attach_web!(processed.path)
      update_dimensions!(processed.path)
      true
    ensure
      src&.close!
      processed&.close! if processed && processed != src
    end

    private

    def download_original_to_tempfile
      ext = File.extname(@item.original_filename.to_s).presence || ".jpg"
      file = Tempfile.new(["tsuzura-original", ext])
      file.binmode
      file.write(@item.file.download)
      file.flush
      file.rewind
      file
    end

    def render_stack(path, stack)
      if vips_available?
        render_stack_vips(path, stack)
      else
        render_stack_magick(path, stack)
      end
    end

    def render_stack_vips(path, stack)
      require "vips"
      image = Vips::Image.new_from_file(path)

      case stack["rotate"].to_i
      when 90 then image = image.rot90
      when 180 then image = image.rot180
      when 270 then image = image.rot270
      end

      image = apply_crop_vips(image, stack["crop"]) if stack["crop"]
      image = apply_blur_regions_vips(image, stack["blur_regions"] || [])

      longest = [image.width, image.height].max
      if longest > MAX_EDGE
        scale = MAX_EDGE.to_f / longest
        image = image.resize(scale)
      end

      out = Tempfile.new(["tsuzura-web", ".jpg"])
      image.jpegsave(out.path, Q: JPEG_QUALITY)
      out
    end

    def render_stack_magick(path, stack)
      pipeline = ImageProcessing::MiniMagick.source(path)
      rotate = stack["rotate"].to_i
      pipeline = pipeline.rotate(rotate) if rotate.positive?

      image = MiniMagick::Image.open(pipeline.call)
      image = apply_crop_magick(image, stack["crop"]) if stack["crop"]

      regions = stack["blur_regions"] || []
      image = apply_blur_regions_magick(image, regions) if regions.any?

      image = downscale_magick(image)
      out = Tempfile.new(["tsuzura-web", ".jpg"])
      image.format("jpg")
      image.quality(JPEG_QUALITY.to_s)
      image.write(out.path)
      out
    end

    def vips_available?
      self.class.vips_available?
    end

    def apply_crop_vips(image, crop)
      x, y, w, h = pixel_rect(crop, image.width, image.height)
      image.crop(x, y, w, h)
    end

    def apply_blur_regions_vips(image, regions)
      regions.each do |region|
        x, y, w, h = pixel_rect(region, image.width, image.height)
        patch = image.crop(x, y, w, h)
        blurred = patch.gaussblur(region["strength"].to_f)
        image = image.insert(blurred, x, y)
      end
      image
    end

    def apply_crop_magick(image, crop)
      x, y, w, h = pixel_rect(crop, image.width, image.height)
      image.crop("#{w}x#{h}+#{x}+#{y}")
    end

    def apply_blur_regions_magick(image, regions)
      regions.each do |region|
        x, y, w, h = pixel_rect(region, image.width, image.height)
        strength = region["strength"]
        patch = image.dup.crop("#{w}x#{h}+#{x}+#{y}")
        patch.blur("0x#{strength}")
        image = image.composite(patch, "png", x, y)
      end
      image
    end

    def pixel_rect(rect, width, height)
      x = (rect["x"] * width).round
      y = (rect["y"] * height).round
      w = [ (rect["w"] * width).round, 1 ].max
      h = [ (rect["h"] * height).round, 1 ].max
      w = [w, width - x].min
      h = [h, height - y].min
      [x, y, w, h]
    end

    def downscale_magick(image)
      longest = [image.width, image.height].max
      return image if longest <= MAX_EDGE

      scale = MAX_EDGE.to_f / longest
      image.resize("#{(image.width * scale).round}x#{(image.height * scale).round}")
    end

    def attach_web!(path)
      @item.web.purge if @item.web.attached?
      @item.web.attach(
        io: File.open(path),
        filename: "web-#{@item.id}.jpg",
        content_type: "image/jpeg"
      )
    end

    def update_dimensions!(path)
      if vips_available?
        image = Vips::Image.new_from_file(path)
        @item.update!(width: image.width, height: image.height)
      else
        image = MiniMagick::Image.open(path)
        @item.update!(width: image.width, height: image.height)
      end
    end
  end
end
