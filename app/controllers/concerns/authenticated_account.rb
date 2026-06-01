# frozen_string_literal: true

module AuthenticatedAccount
  extend ActiveSupport::Concern

  included do
    attr_reader :current_account
  end

  private

  def authenticate_account!
    @current_account = account_from_bearer_token || account_from_rodauth
    return if @current_account

    render json: { error: "unauthorized" }, status: :unauthorized
  end

  def account_from_bearer_token
    token = bearer_token
    return nil if token.blank?

    Account.find_by_tsuzura_api_token(token)
  end

  def account_from_rodauth
    rodauth.rails_account
  end

  def bearer_token
    header = request.authorization.to_s
    return nil unless header.start_with?("Bearer ")

    header.delete_prefix("Bearer ").strip.presence
  end
end
