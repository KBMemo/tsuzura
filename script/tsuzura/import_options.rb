# frozen_string_literal: true

module TsuzuraCLI
  # manifest の import 節と CLI オプションのマージ・API 用変換。
  class ImportOptions
    STORED_KEYS = %w[album_title album_id auto_date_albums inbox_album_title date_album_format].freeze

    class << self
      def merge(stored:, cli:)
        out = normalize(stored)
        apply_cli!(out, cli)
        out
      end

      def normalize(config)
        return {} if config.nil? || config.empty?

        config.transform_keys(&:to_s).slice(*STORED_KEYS).tap do |out|
          out["auto_date_albums"] = !!out["auto_date_albums"] if out.key?("auto_date_albums")
        end
      end

      def valid?(config)
        config = normalize(config)
        config["album_title"] || config["album_id"] || config["auto_date_albums"]
      end

      def from_cli(cli)
        out = {}
        if (title = blank(cli[:album]))
          out["album_title"] = title
        end
        if (album_id = blank(cli[:album_id]))
          out["album_id"] = album_id
        end
        if (inbox = blank(cli[:inbox_album]))
          out["inbox_album_title"] = inbox
        end
        unless cli[:auto_date_albums].nil?
          out["auto_date_albums"] = !!cli[:auto_date_albums]
        end
        out
      end

      def to_api_params(config)
        config = normalize(config)
        params = {}
        params["album_title"] = config["album_title"] if config["album_title"]
        params["album_id"] = config["album_id"] if config["album_id"]
        params["auto_date_albums"] = "true" if config["auto_date_albums"]
        params["inbox_album_title"] = config["inbox_album_title"] if config["inbox_album_title"]
        params["date_album_format"] = config["date_album_format"] if config["date_album_format"]
        params
      end

      def append_multipart_fields(parts, boundary, config)
        config = normalize_stored(config)
        parts << field(parts, boundary, "album_title", config["album_title"]) if config["album_title"]
        parts << field(parts, boundary, "album_id", config["album_id"]) if config["album_id"]
        parts << field(parts, boundary, "auto_date_albums", "true") if config["auto_date_albums"]
        parts << field(parts, boundary, "inbox_album_title", config["inbox_album_title"]) if config["inbox_album_title"]
        parts << field(parts, boundary, "date_album_format", config["date_album_format"]) if config["date_album_format"]
        parts
      end

      private

      def apply_cli!(out, cli)
        cli_slice = from_cli(cli)
        cli_slice.each { |key, value| out[key] = value }
        out
      end

      def blank(value)
        text = value.to_s.strip
        text.empty? ? nil : text
      end

      def field(parts, boundary, name, value)
        parts << form_field(boundary, name, value)
      end

      def form_field(boundary, name, value)
        ("--#{boundary}\r\n" \
          "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n" \
          "#{value}\r\n").b
      end
    end
  end
end
