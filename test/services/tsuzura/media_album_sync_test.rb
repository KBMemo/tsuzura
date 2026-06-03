# frozen_string_literal: true

require "test_helper"

class Tsuzura::MediaAlbumSyncTest < ActiveSupport::TestCase
  setup do
    @account = create_tsuzura_account!
    @targeting = Tsuzura::ImportTargeting.new(account: @account, auto_date_albums: true)
    @item = create_tsuzura_media_item!(account: @account)
  end

  test "links inbox and prunes date album when exif_captured_at is absent" do
    wrong_date = create_tsuzura_album!(account: @account, title: "2020-01-01")
    wrong_date.album_items.create!(media_item: @item, position: 0)
    @item.update!(exif_captured_at: nil, file_mtime: Time.zone.parse("2020-01-01"))

    result = Tsuzura::MediaAlbumSync.new(
      account: @account,
      targeting: @targeting,
      refresh_metadata: false
    ).call

    @item.reload
    titles = @item.albums.map(&:title).sort
    assert_equal [ "Camera Upload" ], titles
    assert_includes result[:pruned_album_ids], wrong_date.id
    assert_includes result[:linked], @item.id
  end

  test "links inbox and date album when exif_captured_at is set" do
    @item.update!(
      exif_captured_at: Time.zone.parse("2026-04-15 10:00:00"),
      file_mtime: Time.zone.parse("2020-01-01")
    )

    Tsuzura::MediaAlbumSync.new(
      account: @account,
      targeting: @targeting,
      refresh_metadata: false,
      prune_date_albums: false
    ).call

    @item.reload
    assert_equal [ "2026-04-15", "Camera Upload" ], @item.albums.map(&:title).sort
  end

  test "refresh_metadata reads attachment" do
    @item.update_columns(exif_captured_at: Time.current, file_mtime: nil)

    Tsuzura::MediaAlbumSync.new(
      account: @account,
      targeting: @targeting,
      prune_date_albums: false
    ).call(media_ids: [ @item.id ])

    @item.reload
    assert_nil @item.exif_captured_at
    assert @item.file_mtime.present?
    assert @item.captured_at.present?
  end
end
