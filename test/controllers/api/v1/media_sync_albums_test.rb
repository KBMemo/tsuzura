# frozen_string_literal: true

require "test_helper"

class Api::V1::MediaSyncAlbumsTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_tsuzura_account!
    @item = create_tsuzura_media_item!(account: @account)
    @item.update!(exif_captured_at: nil)
  end

  test "sync_albums links inbox for items without exif date" do
    post v1_media_sync_albums_path,
      params: { auto_date_albums: true },
      headers: tsuzura_auth_headers(@account)

    assert_response :success
    stats = response.parsed_body.fetch("stats")
    assert stats["total"].positive?
    assert_includes @item.reload.albums.map(&:title), "Camera Upload"
  end

  test "sync_albums requires targeting options" do
    post v1_media_sync_albums_path, headers: tsuzura_auth_headers(@account)

    assert_response :unprocessable_entity
  end
end
