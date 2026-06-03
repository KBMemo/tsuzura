# frozen_string_literal: true

require "test_helper"

class Api::V1::MediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_tsuzura_account!
    @item = create_tsuzura_media_item!(account: @account)
  end

  test "batch upload returns album items and asciidoc" do
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/sample.jpg"),
      "image/jpeg"
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

  test "lookup returns item by checksum for owner" do
    @item.reload
    assert @item.checksum.present?

    get v1_media_lookup_path,
      params: { checksum: @item.checksum },
      headers: tsuzura_auth_headers(@account)

    assert_response :success
    assert_equal @item.id, response.parsed_body.dig("item", "id")
  end

  test "lookup returns null when checksum unknown" do
    get v1_media_lookup_path,
      params: { checksum: "unknown-checksum" },
      headers: tsuzura_auth_headers(@account)

    assert_response :success
    assert_nil response.parsed_body["item"]
  end

  test "batch reuses checksum and links to second album" do
    album_a = create_tsuzura_album!(account: @account, title: "A")
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/sample.png"),
      "image/png"
    )

    post v1_media_batch_path,
      params: { album_id: album_a.id, files: [ upload ] },
      headers: tsuzura_auth_headers(@account)
    assert_response :created
    item_id = response.parsed_body.dig("items", 0, "id")
    checksum = response.parsed_body.dig("items", 0, "checksum")

    album_b = create_tsuzura_album!(account: @account, title: "B")
    assert_no_difference -> { MediaItem.count } do
      post v1_media_batch_path,
        params: { album_ids: [ album_b.id ], files: [ Rack::Test::UploadedFile.new(
          Rails.root.join("test/fixtures/files/sample.png"),
          "image/png"
        ) ] },
        headers: tsuzura_auth_headers(@account)
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 0, body.dig("stats", "created")
    assert_equal 1, body.dig("stats", "linked")
    assert_equal item_id, body.dig("items", 0, "id")
    assert_equal checksum, body.dig("items", 0, "checksum")
    assert_equal 2, MediaItem.find(item_id).album_items.count
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

  test "update_edits accepts rotation with blank crop dimensions" do
    patch v1_media_edits_path(@item.id),
      params: { edit_stack: { rotate: 90, crop: { x: 0, y: 0, w: "", h: "" } } },
      headers: tsuzura_auth_headers(@account).merge("Content-Type" => "application/json"),
      as: :json

    assert_response :success
    assert_equal 90, @item.reload.edit_stack["rotate"]
    assert_equal 1, @item.edit_stack.dig("crop", "w")
  end

  test "update_edits stores stack and enqueues render job" do
    assert_enqueued_with(job: ApplyEditStackJob) do
      patch v1_media_edits_path(@item.id),
        params: { edit_stack: { rotate: 90, crop: { x: 0, y: 0, w: 1, h: 1 } } },
        headers: tsuzura_auth_headers(@account).merge("Content-Type" => "application/json"),
        as: :json
    end

    assert_response :success
    assert_equal 90, response.parsed_body.dig("edit_stack", "rotate")
    assert_equal 90, @item.reload.edit_stack["rotate"]
  end

  test "update_edits stores blur_regions" do
    patch v1_media_edits_path(@item.id),
      params: {
        edit_stack: {
          rotate: 0,
          crop: { x: 0, y: 0, w: 1, h: 1 },
          blur_regions: [{ x: 0.1, y: 0.2, w: 0.15, h: 0.2, strength: 16 }]
        }
      },
      headers: tsuzura_auth_headers(@account).merge("Content-Type" => "application/json"),
      as: :json

    assert_response :success
    regions = @item.reload.edit_stack["blur_regions"]
    assert_equal 1, regions.size
    assert_equal 16, regions.first["strength"]
  end

  test "update_edits forbidden for other account" do
    other = create_tsuzura_account!
    patch v1_media_edits_path(@item.id),
      params: { edit_stack: { rotate: 90 } },
      headers: tsuzura_auth_headers(other).merge("Content-Type" => "application/json"),
      as: :json

    assert_response :forbidden
  end
end
