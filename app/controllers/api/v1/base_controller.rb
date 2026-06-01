# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include AuthenticatedAccount

      before_action :authenticate_account!
    end
  end
end
