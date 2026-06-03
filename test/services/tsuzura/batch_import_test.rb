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

  test "reuses existing media item by checksum without creating duplicate" do
    upload = sample_upload
    first = Tsuzura::BatchImport.new(account: @account, album_title: "First").call(uploads: [ upload ])
    item_id = first[:items].first.id

    assert_no_difference -> { MediaItem.count } do
      second = Tsuzura::BatchImport.new(account: @account, album_title: "Second").call(uploads: [ sample_upload ])
      assert_equal item_id, second[:items].first.id
      assert_empty second[:created_items]
      assert_includes second[:linked_items].map(&:id), item_id
    end

    assert_equal 2, MediaItem.find(item_id).album_items.count
  end

  test "links to multiple albums in one batch" do
    album_a = create_tsuzura_album!(account: @account, title: "A")
    album_b = create_tsuzura_album!(account: @account, title: "B")
    upload = sample_upload

    result = Tsuzura::BatchImport.new(
      account: @account,
      album_ids: [ album_a.id, album_b.id ]
    ).call(uploads: [ upload ])

    assert_equal 2, result[:albums].size
    assert_equal 1, result[:items].size
    assert_equal 2, result[:items].first.album_items.count
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
