# frozen_string_literal: true

require "test_helper"

class Internal::AlbumsIndexTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_tsuzura_account!
    @album = create_tsuzura_album!(account: @account, title: "Summer")
  end

  test "index returns albums for owner" do
    get "/internal/albums", params: { owner_account_id: @account.id }, headers: internal_auth_headers

    assert_response :success
    body = response.parsed_body
    assert_equal 1, body["albums"].size
    assert_equal @album.id, body["albums"].first["id"]
    assert_equal "Summer", body["albums"].first["title"]
  end

  test "index rejects missing internal secret" do
    get "/internal/albums", params: { owner_account_id: @account.id }

    assert_response :forbidden
  end
end
