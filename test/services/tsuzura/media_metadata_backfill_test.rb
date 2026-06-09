# frozen_string_literal: true

require "test_helper"

class Tsuzura::MediaMetadataBackfillTest < ActiveSupport::TestCase
  test "refreshes metadata from original attachment" do
    item = create_tsuzura_media_item!(account: create_tsuzura_account!, filename: "sample.png")
    item.update_columns(captured_at: nil, file_mtime: nil, width: nil, height: nil, exif: {})

    result = Tsuzura::MediaMetadataBackfill.new(scope: MediaItem.where(id: item.id)).call

    assert_equal 1, result.total
    assert_equal 1, result.updated
    assert_equal 0, result.failed
    item.reload
    assert item.captured_at.present?
    assert item.file_mtime.present?
    assert item.width.present?
    assert item.height.present?
  end

  test "refresh from attachment does not use temporary blob file mtime" do
    item = create_tsuzura_media_item!(account: create_tsuzura_account!, filename: "sample.png")
    blob_time = Time.zone.parse("2024-01-02 03:04:05")
    wrong_time = Time.zone.parse("2026-06-10 12:00:00")
    item.file.blob.update_column(:created_at, blob_time)
    item.update_columns(captured_at: wrong_time, file_mtime: nil)

    Tsuzura::MediaMetadataBackfill.new(scope: MediaItem.where(id: item.id)).call

    item.reload
    assert_in_delta blob_time.to_i, item.file_mtime.to_i, 1
    assert_in_delta blob_time.to_i, item.captured_at.to_i, 1
  end

  test "missing_only excludes items with core metadata" do
    item = create_tsuzura_media_item!(account: create_tsuzura_account!, filename: "sample.png")
    item.update!(
      captured_at: Time.current,
      width: 10,
      height: 10,
      latitude: BigDecimal("35.0"),
      longitude: BigDecimal("139.0"),
      exif: { "ImageWidth" => 10 }
    )

    result = Tsuzura::MediaMetadataBackfill.new(
      scope: MediaItem.where(id: item.id),
      missing_only: true
    ).call

    assert_equal 0, result.total
  end

  test "dry run does not change item" do
    item = create_tsuzura_media_item!(account: create_tsuzura_account!, filename: "sample.png")
    item.update_columns(captured_at: nil, width: nil, height: nil)

    result = Tsuzura::MediaMetadataBackfill.new(scope: MediaItem.where(id: item.id), dry_run: true).call

    assert_equal 1, result.total
    assert_equal 1, result.updated
    assert_nil item.reload.captured_at
  end
end
