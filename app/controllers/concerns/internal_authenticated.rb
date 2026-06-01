# frozen_string_literal: true

module InternalAuthenticated
  extend ActiveSupport::Concern

  private

  def verify_internal_secret!
    expected = ENV["KBMEMO_TSUZURA_INTERNAL_SECRET"].presence ||
      Rails.application.credentials.dig(:tsuzura, :internal_secret).presence
    provided = request.headers["X-Kbmemo-Internal-Secret"].to_s
    return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, provided)

    render json: { error: "forbidden" }, status: :forbidden
  end
end
