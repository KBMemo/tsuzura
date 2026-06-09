# frozen_string_literal: true

module WebHelper
  def kbmemo_home_url
    ENV.fetch("KBMEMO_HOME_URL", "http://localhost:3000")
  end

  def media_item_capture_time_label(item)
    time = item.exif_captured_at || item.captured_at || item.file_mtime
    return "-" unless time

    label = item.exif_captured_at.present? ? "撮影" : "日時"
    "#{label} #{l(time.in_time_zone, format: :short)}"
  end

  def media_item_location_label(item)
    return "-" if item.latitude.blank? || item.longitude.blank?

    lat = format("%.5f", item.latitude.to_f)
    lon = format("%.5f", item.longitude.to_f)
    "#{lat}, #{lon}"
  end

  def media_item_location_map_url(item)
    return nil if item.latitude.blank? || item.longitude.blank?

    lat = item.latitude.to_f
    lon = item.longitude.to_f
    "https://www.google.com/maps/search/?api=1&query=#{lat},#{lon}"
  end

  def media_item_dimensions_label(item)
    return "-" if item.width.blank? || item.height.blank?

    "#{item.width} x #{item.height}px"
  end

  def media_item_file_size_label(item)
    blob = media_item_source_blob(item)
    return "-" unless blob

    number_to_human_size(blob.byte_size)
  end

  def media_item_content_type_label(item)
    blob = media_item_source_blob(item)
    return "-" unless blob&.content_type

    blob.content_type
  end

  def media_item_source_blob(item)
    return item.file.blob if item.file.attached?
    return item.web.blob if item.web.attached?

    nil
  end

  # Header seal mark (app/assets/images/tsuzura1.svg).
  def tsuzura_brand_icon
    path = Rails.root.join("app/assets/images/tsuzura1.svg")
    svg = File.read(path)
    svg = svg.sub(
      /<svg\b[^>]*>/,
      '<svg class="app-brand-icon" width="28" height="28" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 373" role="img" aria-hidden="true">'
    )
    raw svg
  end
end
