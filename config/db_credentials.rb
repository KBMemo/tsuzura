# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module DbCredentials
  class << self
    def config(env = Rails.env, credentials: Rails.application.credentials)
      cfg = credentials.dig(:db, env.to_sym)
      if cfg.blank?
        raise KeyError,
          "Missing credentials db.#{env} — share RAILS_MASTER_KEY with kbmemo_site or set DATABASE_URL"
      end

      normalize_section(cfg)
    end

    def fetch(key, env = Rails.env, credentials: Rails.application.credentials)
      value = config(env, credentials: credentials)[key.to_s]
      if value.nil? || value == ""
        raise KeyError, "Missing credentials db.#{env}.#{key}"
      end

      value
    end

    def connection_options(env = Rails.env, credentials: Rails.application.credentials)
      {
        host: fetch(:host, env, credentials: credentials),
        port: fetch(:port, env, credentials: credentials),
        username: fetch(:username, env, credentials: credentials),
        password: fetch(:password, env, credentials: credentials)
      }
    end

    def normalize_section(cfg)
      (cfg.is_a?(Hash) ? cfg : cfg.to_h).stringify_keys
    end

    private :normalize_section
  end
end
