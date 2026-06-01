# frozen_string_literal: true

require "sequel/core"

class RodauthMain < Rodauth::Rails::Auth
  configure do
    enable :login, :logout, :remember

    db Sequel.postgres(extensions: :activerecord_connection, keep_reference: false)
    convert_token_id_to_integer? { Account.columns_hash["id"].type == :integer }

    account_status_column :status
    account_password_hash_column :password_hash

    login_param "email"
    rails_controller { RodauthController }

    after_login { remember_login }
    extend_remember_deadline? true
  end
end
