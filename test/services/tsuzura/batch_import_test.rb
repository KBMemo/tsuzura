# frozen_string_literal: true

require "test_helper"

class Tsuzura::BatchImportTest < ActiveSupport::TestCase
  setup do
    @account = create_tsuzura_account!
  end

  test "creates album and media items from uploads" do
    upload = sample_upload

    result = Tsuzura::BatchImport.new(account: @account, album_title: "Batch Test").call(uploads: [ upload ])

    album = result[:album]
    items = result[:items]
    assert_equal "Batch Test", album.title
    assert_equal 1, items.size
    assert items.first.file.attached?
    assert_equal 1, album.album_items.count
  end

  test "appends to existing album by id" do
    album = create_tsuzura_album!(account: @account)
    upload = sample_upload

    assert_difference -> { album.album_items.count }, 1 do
      Tsuzura::BatchImport.new(account: @account, album_id: album.id).call(uploads: [ upload ])
    end
  end

  test "rejects album owned by another account" do
    other_album = create_tsuzura_album!(account: create_tsuzura_account!, title: "Other")
    upload = sample_upload

    assert_raises(ActiveRecord::RecordNotFound) do
      Tsuzura::BatchImport.new(account: @account, album_id: other_album.id).call(uploads: [ upload ])
    end
  end

  private

  def sample_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/sample.png"),
      "image/png"
    )
  end
end
