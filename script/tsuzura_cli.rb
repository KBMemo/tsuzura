# frozen_string_literal: true

# CLI 本体。Zeitwerk 対象外（script/）— bin/tsuzura から require する。
require "thor"
require "net/http"
require "json"
require "uri"
require "securerandom"

module TsuzuraCLI
  IMAGE_SUFFIXES = %w[.jpg .jpeg .png .gif .webp .heic .heif].freeze

  class Main < Thor
    package_name "tsuzura"

    desc "import PATH...", "Import files into a Tsuzura album"
    option :album, type: :string, required: true, aliases: "-a", desc: "Album title"
    option :album_id, type: :string, desc: "Existing album ULID"
    def import(*paths)
      files = expand_paths(paths)
      abort "No image files found" if files.empty?

      response = post_batch(files)
      puts response.fetch("asciidoc")
    end

    desc "albums list", "List albums"
    def albums(action = "list")
      abort "Unknown albums command: #{action}" unless action == "list"

      uri = URI.join(base_url, "/v1/albums")
      json = get_json(uri)
      json.fetch("albums", []).each do |album|
        puts "#{album['id']}\t#{album['title']}"
      end
    end

    desc "media show ULID", "Show media metadata"
    def media(action, ulid = nil)
      abort "Usage: tsuzura media show ULID" unless action == "show" && !ulid.to_s.strip.empty?

      uri = URI.join(base_url, "/v1/media/#{ulid}")
      puts JSON.pretty_generate(get_json(uri))
    end

    default_task :help

    private

    def expand_paths(paths)
      paths.flat_map { |path| expand_path(path) }.uniq.sort_by(&:to_s)
    end

    def expand_path(path)
      p = Pathname.new(File.expand_path(path))
      return [] unless p.exist?

      if p.directory?
        p.glob("**/*").select(&:file?).select { |file| image_file?(file) }
      elsif p.file? && image_file?(p)
        [ p ]
      else
        []
      end
    end

    def image_file?(path)
      IMAGE_SUFFIXES.include?(path.extname.downcase)
    end

    def post_batch(files)
      uri = URI.join(base_url, "/v1/media/batch")
      boundary = "----Tsuzura#{SecureRandom.hex(16)}"
      body = build_multipart(boundary, files)
      request = Net::HTTP::Post.new(uri)
      apply_auth!(request)
      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      request.body = body
      execute_json(request, uri)
    end

    def build_multipart(boundary, files)
      parts = []
      parts << form_field(boundary, "album_title", options[:album]) if !options[:album].to_s.strip.empty?
      parts << form_field(boundary, "album_id", options[:album_id]) if !options[:album_id].to_s.strip.empty?
      files.each do |file|
        parts << file_field(boundary, file)
      end
      parts << "--#{boundary}--\r\n".b
      parts.inject(+"", :<<)
    end

    def form_field(boundary, name, value)
      ("--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n" \
        "#{value}\r\n").b
    end

    def file_field(boundary, file)
      content = file.binread
      header = "--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"files[]\"; filename=\"#{file.basename}\"\r\n" \
        "Content-Type: application/octet-stream\r\n\r\n"
      header.b + content + "\r\n".b
    end

    def get_json(uri)
      request = Net::HTTP::Get.new(uri)
      apply_auth!(request)
      execute_json(request, uri)
    end

    def execute_json(request, uri)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      unless response.is_a?(Net::HTTPSuccess)
        abort "Tsuzura API error #{response.code}: #{response.body}"
      end

      JSON.parse(response.body)
    end

    def apply_auth!(request)
      token = ENV["TSUZURA_API_TOKEN"].to_s.strip
      abort "Set TSUZURA_API_TOKEN" if token.empty?

      request["Authorization"] = "Bearer #{token}"
    end

    def base_url
      ENV.fetch("TSUZURA_BASE_URL", "http://localhost:3008").chomp("/") + "/"
    end
  end
end
