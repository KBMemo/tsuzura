# frozen_string_literal: true

module Tsuzura
  # 非破壊編集パラメータ（正規化・検証）。
  class EditStack
    VALID_ROTATES = [0, 90, 180, 270].freeze
    MAX_BLUR_REGIONS = 20

    class ValidationError < StandardError; end

    class << self
      def normalize(raw)
        h = raw.is_a?(Hash) ? raw.deep_stringify_keys : {}
        rotate = h["rotate"].to_i
        rotate = 0 unless VALID_ROTATES.include?(rotate)

        stack = { "rotate" => rotate }
        crop = normalize_crop(h["crop"])
        stack["crop"] = crop if crop
        regions = normalize_blur_regions(h["blur_regions"])
        stack["blur_regions"] = regions if regions.any?
        stack
      end

      private

      def normalize_crop(raw)
        return nil if raw.blank?

        h = raw.is_a?(Hash) ? raw.stringify_keys : {}
        x = clamp01(h["x"])
        y = clamp01(h["y"])
        w = clamp01(h["w"])
        height = clamp01(h["h"])
        raise ValidationError, "crop width/height must be positive" if w <= 0 || height <= 0
        raise ValidationError, "crop exceeds image bounds" if x + w > 1.001 || y + height > 1.001

        { "x" => x, "y" => y, "w" => w, "h" => height }
      end

      def normalize_blur_regions(raw)
        list = Array(raw)
        raise ValidationError, "too many blur_regions" if list.size > MAX_BLUR_REGIONS

        list.filter_map do |entry|
          next unless entry.is_a?(Hash)

          h = entry.stringify_keys
          x = clamp01(h["x"])
          y = clamp01(h["y"])
          w = clamp01(h["w"])
          height = clamp01(h["h"])
          next if w <= 0 || height <= 0

          strength = h["strength"].to_i
          strength = 12 if strength <= 0
          strength = [strength, 64].min
          { "x" => x, "y" => y, "w" => w, "h" => height, "strength" => strength }
        end
      end

      def clamp01(value)
        value.to_f.clamp(0.0, 1.0)
      end
    end
  end
end
