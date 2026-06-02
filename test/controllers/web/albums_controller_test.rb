# frozen_string_literal: true

require "test_helper"

class Web::AlbumsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_tsuzura_account!
    @token = @account.generate_tsuzura_api_token!
    @album = create_tsuzura_album!(account: @account)
  end

  test "index requires login" do
    get web_albums_path
    assert_response :redirect
    assert_match %r{/login}, response.redirect_url
  end

  test "index lists albums when authenticated via bearer is not used for web" do
    skip "Web UI uses Rodauth session; integration covered via API tests"
  end
end
