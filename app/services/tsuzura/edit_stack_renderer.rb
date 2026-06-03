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
      pipeline = image_processor.source(path)
      rotate = stack["rotate"].to_i
      pipeline = pipeline.rotate(rotate) if rotate.positive?

      image = open_magick(pipeline.call)
      crop = stack["crop"]
      image = apply_crop(image, crop) if crop

      regions = stack["blur_regions"] || []
      image = apply_blur_regions(image, regions) if regions.any?

      image = downscale(image)
      out = Tempfile.new(["tsuzura-web", ".jpg"])
      image.format("jpg")
      image.quality(JPEG_QUALITY.to_s)
      image.write(out.path)
      out
    end

    def image_processor
      if vips_available?
        ImageProcessing::Vips
      else
        ImageProcessing::MiniMagick
      end
    end

    def vips_available?
      self.class.vips_available?
    end

    def open_magick(path)
      MiniMagick::Image.open(path)
    end

    def apply_crop(image, crop)
      width = image.width
      height = image.height
      x = (crop["x"] * width).round
      y = (crop["y"] * height).round
      w = [ (crop["w"] * width).round, 1 ].max
      h = [ (crop["h"] * height).round, 1 ].max
      w = [w, width - x].min
      h = [h, height - y].min
      image.crop("#{w}x#{h}+#{x}+#{y}")
    end

    def apply_blur_regions(image, regions)
      width = image.width
      height = image.height
      regions.each do |region|
        x = (region["x"] * width).round
        y = (region["y"] * height).round
        w = [ (region["w"] * width).round, 1 ].max
        h = [ (region["h"] * height).round, 1 ].max
        w = [w, width - x].min
        h = [h, height - y].min
        strength = region["strength"]
        patch = image.dup.crop("#{w}x#{h}+#{x}+#{y}")
        patch.blur("0x#{strength}")
        image = image.composite(patch, "png", x, y)
      end
      image
    end

    def downscale(image)
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
      image = MiniMagick::Image.open(path)
      @item.update!(width: image.width, height: image.height)
    end
  end
end
