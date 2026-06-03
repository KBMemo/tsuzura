# frozen_string_literal: true

require "test_helper"

class Tsuzura::MediaMetadataTest < ActiveSupport::TestCase
  test "parse_capture_time normalizes EXIF date colons" do
    time = Tsuzura::MediaMetadata.parse_capture_time("2026:06:01 12:00:00")

    assert_equal Time.zone.parse("2026-06-01 12:00:00"), time
  end

  test "apply_from_path sets file_mtime without exif_captured_at for PNG" do
    account = create_tsuzura_account!
    item = MediaItem.new(owner_account_id: account.id, kind: "image")
    item.assign_ulid
    path = Rails.root.join("test/fixtures/files/sample.png")
    mtime = Time.zone.parse("2025-03-15 08:30:00")
    utime_file(path, mtime)

    Tsuzura::MediaMetadata.apply_from_path!(item, path.to_s, fallback_mtime: mtime)
    item.save!

    assert_nil item.exif_captured_at
    assert_equal mtime, item.file_mtime
    assert_equal mtime, item.captured_at
    assert_nil item.latitude
    assert_nil item.longitude
  end

  test "apply_from_upload records file_mtime on attach" do
    account = create_tsuzura_account!
    path = Rails.root.join("test/fixtures/files/sample.jpg")
    mtime = Time.zone.parse("2024-07-04 18:00:00")
    upload = Rack::Test::UploadedFile.new(path, "image/jpeg")
    utime_file(upload.path, mtime)

    item = MediaItem.new(owner_account_id: account.id, kind: "image")
    item.assign_ulid
    item.attach_upload!(upload)

    assert item.file_mtime.present?
    assert item.captured_at.present?
  end
end
