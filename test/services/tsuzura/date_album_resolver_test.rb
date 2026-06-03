# frozen_string_literal: true

require "test_helper"

class Tsuzura::DateAlbumResolverTest < ActiveSupport::TestCase
  setup do
    @account = create_tsuzura_account!
    @resolver = Tsuzura::DateAlbumResolver.new(
      account: @account,
      inbox_album_title: "Camera Upload"
    )
  end

  test "inbox only when exif_captured_at is absent" do
    item = MediaItem.new(owner_account_id: @account.id, kind: "image")

    assert_difference -> { Album.count }, 1 do
      albums = @resolver.albums_for_item(item)
      assert_equal [ "Camera Upload" ], albums.map(&:title)
    end
  end

  test "inbox and date album when exif_captured_at is present" do
    item = MediaItem.new(
      owner_account_id: @account.id,
      kind: "image",
      exif_captured_at: Time.zone.parse("2026-06-01 14:22:00")
    )

    assert_difference -> { Album.count }, 2 do
      albums = @resolver.albums_for_item(item)
      assert_equal [ "2026-06-01", "Camera Upload" ], albums.map(&:title).sort
    end

    assert_no_difference -> { Album.count } do
      again = @resolver.albums_for_item(item)
      assert_equal [ "2026-06-01", "Camera Upload" ], again.map(&:title).sort
    end
  end
end
