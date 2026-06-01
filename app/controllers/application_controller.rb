# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Rodauth::Rails::ControllerMethods
end
