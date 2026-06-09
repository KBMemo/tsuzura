# frozen_string_literal: true

require "test_helper"

class WebHelperTest < ActionView::TestCase
  test "media item metadata labels include capture time location dimensions and blob info" do
    item = create_tsuzura_media_item!(account: create_tsuzura_account!)
    item.update!(
      exif_captured_at: Time.zone.parse("2026-06-01 12:34:00"),
      latitude: BigDecimal("35.681236"),
      longitude: BigDecimal("139.767125"),
      width: 640,
      height: 480
    )

    assert_equal "撮影 2026-06-01", media_item_capture_time_label(item)
    assert_equal "35.68124, 139.76712", media_item_location_label(item)
    assert_equal "https://www.google.com/maps/search/?api=1&query=35.681236,139.767125", media_item_location_map_url(item)
    assert_equal "640 x 480px", media_item_dimensions_label(item)
    assert_equal "image/png", media_item_content_type_label(item)
    assert_match(/\A[0-9.]+\s?(Bytes|KB)\z/, media_item_file_size_label(item))
  end

  test "media item metadata labels fall back when data is absent" do
    item = MediaItem.new(kind: "image")

    assert_equal "-", media_item_capture_time_label(item)
    assert_equal "-", media_item_location_label(item)
    assert_nil media_item_location_map_url(item)
    assert_equal "-", media_item_dimensions_label(item)
    assert_equal "-", media_item_content_type_label(item)
    assert_equal "-", media_item_file_size_label(item)
  end
end
