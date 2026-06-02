# frozen_string_literal: true

module Web
  class BaseController < ActionController::Base
    include Rodauth::Rails::ControllerMethods

    protect_from_forgery with: :exception

    before_action :require_web_account!

    layout "application"
    helper ::WebHelper

    private

    def require_web_account!
      return if rodauth.rails_account

      redirect_to web_login_url, allow_other_host: true
    end

    def web_login_url
      ENV.fetch("KBMEMO_LOGIN_URL", "http://localhost:3000/login")
    end

    def current_account
      rodauth.rails_account
    end
    helper_method :current_account
  end
end
