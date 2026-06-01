# frozen_string_literal: true

require "test_helper"

class Internal::AlbumsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_tsuzura_account!
    @album = create_tsuzura_album!(account: @account)
    @item = create_tsuzura_media_item!(account: @account)
    AlbumItem.create!(album: @album, media_item: @item, position: 0)
  end

  test "show returns album media ids with internal secret" do
    get internal_album_path(@album.id), headers: internal_auth_headers

    assert_response :success
    body = response.parsed_body
    assert_equal @album.id, body["id"]
    assert_equal [ @item.id ], body["media_item_ids"]
  end

  test "show rejects missing internal secret" do
    get internal_album_path(@album.id)

    assert_response :forbidden
  end
end
