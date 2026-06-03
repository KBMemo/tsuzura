# frozen_string_literal: true

require "exifr/jpeg"

module Tsuzura
  # EXIF / ファイル日時から captured_at・exif JSON・寸法・位置を埋める。
  class MediaMetadata
    CAPTURE_TIME_KEYS = %w[DateTimeOriginal CreateDate DateTime].freeze

    class << self
      def apply_from_upload!(item, upload)
        path, cleanup = upload_path(upload)
        fallback_mtime = upload_mtime(upload)
        apply_from_path!(item, path, fallback_mtime: fallback_mtime)
      ensure
        cleanup&.call
      end

      def apply_from_attachment!(item)
        return item unless item.file.attached?

        item.file.blob.open do |tempfile|
          apply_from_path!(item, tempfile.path, fallback_mtime: nil)
        end
      end

      def apply_from_path!(item, path, fallback_mtime: nil)
        return item unless path.present? && File.file?(path)

        data = extract(path, fallback_mtime: fallback_mtime)
        item.exif_captured_at = data[:exif_captured_at]
        item.file_mtime = data[:file_mtime]
        item.captured_at = data[:captured_at]
        item.latitude = data[:latitude]
        item.longitude = data[:longitude]
        item.exif = data[:exif]
        item.width = data[:width] if data[:width]
        item.height = data[:height] if data[:height]
        item.save! if item.changed?
        item
      end

      def parse_capture_time(value)
        return nil if value.blank?

        text = value.to_s.strip
        normalized = text.gsub(/\A(\d{4}):(\d{2}):(\d{2})/, '\1-\2-\3')
        Time.zone.parse(normalized)
      rescue ArgumentError, TypeError
        nil
      end

      def upload_mtime(upload)
        path = upload.path if upload.respond_to?(:path)
        return File.mtime(path).in_time_zone if path.present? && File.file?(path)

        nil
      end

      private

      def extract(path, fallback_mtime:)
        stat = File.stat(path)
        file_mtime = stat.mtime.in_time_zone
        exif_hash = read_exif_hash(path)
        exif_captured_at = capture_time_from_exif(exif_hash)
        latitude, longitude = coordinates_from_exif(path, exif_hash)
        captured_at = exif_captured_at || fallback_mtime || file_mtime || Time.current
        width, height = dimensions_from_exif(exif_hash, path)

        {
          exif_captured_at: exif_captured_at,
          file_mtime: file_mtime,
          captured_at: captured_at,
          latitude: latitude,
          longitude: longitude,
          exif: exif_hash,
          width: width,
          height: height
        }
      end

      def read_exif_hash(path)
        case File.extname(path).downcase
        when ".jpg", ".jpeg"
          jpeg = EXIFR::JPEG.new(path)
          return {} unless jpeg.exif

          jpeg.exif.to_hash.transform_keys(&:to_s).transform_values { |v| serialize_exif_value(v) }
        else
          {}
        end
      rescue EXIFR::MalformedImage, EXIFR::MalformedJPEG, Errno::ENOENT, StandardError => e
        Rails.logger.debug("Tsuzura EXIF read skipped for #{path}: #{e.class}")
        {}
      end

      def coordinates_from_exif(path, _exif_hash)
        read_gps(path)
      end

      def read_gps(path)
        return [ nil, nil ] unless %w[.jpg .jpeg].include?(File.extname(path).downcase)

        jpeg = EXIFR::JPEG.new(path)
        gps = jpeg.gps
        return [ nil, nil ] unless gps

        [ gps.latitude, gps.longitude ]
      rescue EXIFR::MalformedImage, EXIFR::MalformedJPEG, StandardError
        [ nil, nil ]
      end

      def serialize_exif_value(value)
        case value
        when Time, DateTime, Date
          value.iso8601
        when Rational
          value.to_f
        else
          value
        end
      end

      def capture_time_from_exif(exif_hash)
        CAPTURE_TIME_KEYS.each do |key|
          parsed = parse_capture_time(exif_hash[key])
          return parsed if parsed
        end

        nil
      end

      def dimensions_from_exif(exif_hash, path)
        width = exif_hash["PixelXDimension"] || exif_hash["ImageWidth"]
        height = exif_hash["PixelYDimension"] || exif_hash["ImageHeight"]
        return [ width, height ] if width.present? && height.present?

        probe_dimensions(path)
      end

      def probe_dimensions(path)
        if EditStackRenderer.vips_available?
          image = Vips::Image.new_from_file(path)
          return [ image.width, image.height ]
        end

        require "mini_magick"
        image = MiniMagick::Image.open(path)
        [ image.width, image.height ]
      rescue StandardError
        [ nil, nil ]
      end

      def upload_path(upload)
        if upload.respond_to?(:tempfile) && upload.tempfile&.path.present? && File.file?(upload.tempfile.path)
          return [ upload.tempfile.path, nil ]
        end

        if upload.respond_to?(:path) && upload.path.present? && File.file?(upload.path)
          return [ upload.path, nil ]
        end

        temp = Tempfile.new([ "tsuzura-upload", upload_extension(upload) ])
        temp.binmode
        io = upload.respond_to?(:open) ? upload.open : upload
        IO.copy_stream(io, temp)
        io.rewind if io.respond_to?(:rewind)
        temp.flush
        [ temp.path, -> { temp.close! } ]
      end

      def upload_extension(upload)
        name = upload.original_filename if upload.respond_to?(:original_filename)
        ext = File.extname(name.to_s)
        ext.presence || ".bin"
      end
    end
  end
end
