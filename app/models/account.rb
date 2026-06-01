# frozen_string_literal: true

class Account < ApplicationRecord
  include Rodauth::Rails.model

  self.table_name = "accounts"

  enum :status, { unverified: 1, verified: 2, closed: 3 }

  def tsuzura_api_token_configured?
    tsuzura_api_token_digest.present?
  end

  def generate_tsuzura_api_token!
    raw = "tsuzura_#{SecureRandom.urlsafe_base64(32)}"
    update!(
      tsuzura_api_token_digest: self.class.digest_tsuzura_api_token(raw),
      tsuzura_api_token_prefix: raw[0, 16],
      tsuzura_api_token_created_at: Time.current
    )
    raw
  end

  def self.find_by_tsuzura_api_token(token)
    digest = digest_tsuzura_api_token(token)
    return nil if digest.blank?

    find_by(tsuzura_api_token_digest: digest)
  end

  def self.digest_tsuzura_api_token(token)
    value = token.to_s.strip
    return nil if value.blank?

    Digest::SHA256.hexdigest(value)
  end
end
