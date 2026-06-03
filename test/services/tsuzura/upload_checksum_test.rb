# frozen_string_literal: true

require "test_helper"

class Tsuzura::UploadChecksumTest < ActiveSupport::TestCase
  test "from_upload matches Active Storage blob checksum" do
    path = Rails.root.join("test/fixtures/files/sample.png")
    upload = Rack::Test::UploadedFile.new(path, "image/png")

    pre = Tsuzura::UploadChecksum.from_upload(upload)
    item = MediaItem.new(owner_account_id: create_tsuzura_account!.id, kind: "image")
    item.assign_ulid
    item.attach_upload!(upload)

    assert_equal item.checksum, pre
  end
end
