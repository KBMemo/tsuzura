# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "bcrypt"

module TsuzuraTestData
  def create_tsuzura_account!(suffix: SecureRandom.hex(4))
    Account.create!(
      email: "tsuzura-#{suffix}@example.com",
      password_hash: BCrypt::Password.create("password"),
      status: :verified,
      google_calendar_meta: {},
      theme_preference: {}
    )
  end

  def create_tsuzura_album!(account:, title: "Test Album")
    Album.create!(owner_account_id: account.id, title: title)
  end

  def utime_file(path, time)
    t = time.in_time_zone
    atime = Time.at(t.to_i).utc
    File.utime(atime, atime, path)
  end

  def create_tsuzura_media_item!(account:, filename: "sample.png", content_type: nil)
    content_type ||= filename.end_with?(".jpg", ".jpeg") ? "image/jpeg" : "image/png"
    fixture = filename.end_with?(".jpg", ".jpeg") ? "sample.jpg" : "sample.png"
    item = MediaItem.new(owner_account_id: account.id, kind: "image", original_filename: filename)
    item.assign_ulid
    item.file.attach(
      io: File.open(Rails.root.join("test/fixtures/files", fixture)),
      filename: filename,
      content_type: content_type
    )
    item.checksum = item.file.blob&.checksum
    item.save!
    item
  end
end

module ActiveSupport
  class TestCase
    parallelize(workers: 1)
    include TsuzuraTestData

    setup do
      ENV["TSUZURA_URL_SIGNING_SECRET"] = "test-url-signing-secret"
      ENV["KBMEMO_TSUZURA_INTERNAL_SECRET"] = "test-internal-secret"
      ENV["TSUZURA_PUBLIC_URL"] = "http://media.example.com"
    end
  end
end

module TsuzuraApiTestAuth
  def tsuzura_auth_headers(account)
    token = account.generate_tsuzura_api_token!
    {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json"
    }
  end

  def internal_auth_headers
    {
      "X-Kbmemo-Internal-Secret" => ENV.fetch("KBMEMO_TSUZURA_INTERNAL_SECRET"),
      "Accept" => "application/json"
    }
  end
end

class ActionDispatch::IntegrationTest
  include TsuzuraApiTestAuth
end
