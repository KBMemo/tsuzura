# frozen_string_literal: true

require "test_helper"

class Api::V1::MediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_tsuzura_account!
    @item = create_tsuzura_media_item!(account: @account)
  end

  test "batch upload returns album items and asciidoc" do
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/sample.png"),
      "image/png"
    )

    assert_difference -> { MediaItem.count }, 1 do
      post v1_media_batch_path,
        params: { album_title: "CLI Import", files: [ upload ] },
        headers: tsuzura_auth_headers(@account)
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "CLI Import", body.dig("album", "title")
    assert body["items"].one?
    assert_includes body["asciidoc"], "album::"
    assert_includes body["asciidoc"], "image::media:"
  end

  test "batch upload requires bearer token" do
    post v1_media_batch_path, params: { album_title: "X", files: [] }

    assert_response :unauthorized
  end

  test "show returns metadata for owner" do
    get v1_media_path(@item.id), headers: tsuzura_auth_headers(@account)

    assert_response :success
    assert_equal @item.id, response.parsed_body["id"]
  end

  test "web serves file with valid signature" do
    memo_id = 99
    url = Tsuzura::MediaUrlSigner.sign(media_id: @item.id, memo_id: memo_id)
    uri = URI.parse(url)
    query = Rack::Utils.parse_query(uri.query)

    get "/v1/media/#{@item.id}/web",
      params: {
        memo_id: query["memo_id"],
        exp: query["exp"],
        sig: query["sig"]
      }

    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "web rejects invalid signature" do
    get "/v1/media/#{@item.id}/web",
      params: { memo_id: 1, exp: 1.hour.from_now.to_i, sig: "bad" }

    assert_response :forbidden
  end
end
