# frozen_string_literal: true

require "test_helper"

class Tsuzura::EditStackRendererTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @account = create_tsuzura_account!
    @item = create_tsuzura_media_item!(account: @account, filename: "sample.jpg", content_type: "image/jpeg")
  end

  test "renders rotated web variant" do
    skip "libvips or ImageMagick with JPEG support required" unless Tsuzura::EditStackRenderer.processing_available?

    original_blob_id = @item.file.blob.id
    @item.update!(edit_stack: { "rotate" => 90 })

    assert Tsuzura::EditStackRenderer.new(@item).call
    @item.reload

    assert @item.web.attached?
    assert_equal original_blob_id, @item.file.blob.id
    assert_equal "image/jpeg", @item.web.blob.content_type
    assert @item.height.to_i.positive?
    assert @item.width.to_i.positive?
  end
end
