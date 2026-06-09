# frozen_string_literal: true

require "base64"
require "exifr/jpeg"

module Tsuzura
  # EXIF / ファイル日時から captured_at・exif JSON・寸法・位置を埋める。
  class MediaMetadata
    CAPTURE_TIME_KEYS = %w[date_time_original date_time_digitized date_time DateTimeOriginal CreateDate DateTime].freeze

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
          apply_from_path!(
            item,
            tempfile.path,
            fallback_mtime: attachment_fallback_mtime(item),
            file_mtime: attachment_file_mtime(item)
          )
        end
      end

      def apply_from_path!(item, path, fallback_mtime: nil, file_mtime: nil)
        return item unless path.present? && File.file?(path)

        data = extract(path, fallback_mtime: fallback_mtime, file_mtime: file_mtime)
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

      def extract(path, fallback_mtime:, file_mtime:)
        file_mtime = (file_mtime || File.stat(path).mtime).in_time_zone
        jpeg = read_jpeg(path)
        exif_hash = read_exif_hash(path, jpeg: jpeg)
        exif_captured_at = capture_time_from_exif(exif_hash)
        latitude, longitude = coordinates_from_exif(path, jpeg: jpeg)
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

      def attachment_fallback_mtime(item)
        item.file.blob.created_at
      end

      def attachment_file_mtime(item)
        item.file.blob.created_at
      end

      def read_jpeg(path)
        return nil unless %w[.jpg .jpeg].include?(File.extname(path).downcase)

        EXIFR::JPEG.new(path)
      rescue EXIFR::MalformedImage, EXIFR::MalformedJPEG, Errno::ENOENT, StandardError => e
        Rails.logger.debug("Tsuzura EXIF read skipped for #{path}: #{e.class}")
        nil
      end

      def read_exif_hash(path, jpeg:)
        return {} unless jpeg

        raw = jpeg.exif ? jpeg.exif.to_hash.transform_keys(&:to_s).transform_values { |v| serialize_exif_value(v) } : {}
        raw.merge!(jpeg_method_metadata(jpeg))
        sanitize_exif_hash(raw)
      rescue StandardError => e
        Rails.logger.debug("Tsuzura EXIF hash read skipped for #{path}: #{e.class}")
        {}
      end

      def jpeg_method_metadata(jpeg)
        {
          "date_time_original" => jpeg.date_time_original,
          "date_time_digitized" => jpeg.date_time_digitized,
          "date_time" => jpeg.date_time,
          "image_width" => jpeg.width,
          "image_height" => jpeg.height,
          "make" => jpeg.make,
          "model" => jpeg.model
        }.compact
      end

      def coordinates_from_exif(_path, jpeg:)
        read_gps(jpeg)
      end

      def read_gps(jpeg)
        return [ nil, nil ] unless jpeg

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
        when Hash
          sanitize_exif_hash(value.transform_keys(&:to_s).transform_values { |v| serialize_exif_value(v) })
        when Array
          value.filter_map { |entry| sanitize_exif_value(entry) }
        when String, Symbol
          sanitize_json_string(value.to_s)
        else
          value
        end
      end

      def sanitize_exif_hash(hash)
        hash.each_with_object({}) do |(key, value), out|
          safe_key = sanitize_json_string(key.to_s)
          next if safe_key.blank?

          safe_value = sanitize_exif_value(value)
          next if safe_value.nil?

          out[safe_key] = safe_value
        end
      end

      def sanitize_exif_value(value)
        case value
        when Hash
          sanitize_exif_hash(value)
        when Array
          value.filter_map { |entry| sanitize_exif_value(entry) }
        when String, Symbol
          sanitize_json_string(value.to_s)
        when Numeric, TrueClass, FalseClass
          value
        else
          text = serialize_exif_value(value)
          text.is_a?(String) ? sanitize_json_string(text) : text
        end
      end

      # PostgreSQL jsonb は U+0000 を含む文字列を拒否する。バイナリ EXIF 値は Base64 にする。
      def sanitize_json_string(str)
        raw = str.to_s.dup.force_encoding(Encoding::BINARY)
        raw = raw.delete("\0")
        return "" if raw.empty?

        utf8 = raw.dup.force_encoding(Encoding::UTF_8)
        return utf8 if utf8.valid_encoding?

        Base64.strict_encode64(raw)
      end

      def capture_time_from_exif(exif_hash)
        CAPTURE_TIME_KEYS.each do |key|
          parsed = parse_capture_time(exif_hash[key])
          return parsed if parsed
        end

        nil
      end

      def dimensions_from_exif(exif_hash, path)
        width = exif_hash["pixel_x_dimension"] || exif_hash["image_width"] || exif_hash["PixelXDimension"] || exif_hash["ImageWidth"]
        height = exif_hash["pixel_y_dimension"] || exif_hash["image_height"] || exif_hash["PixelYDimension"] || exif_hash["ImageHeight"]
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
