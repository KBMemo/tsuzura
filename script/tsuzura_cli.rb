# frozen_string_literal: true

# CLI 本体。Zeitwerk 対象外（script/）— bin/tsuzura から require する。
require "thor"
require "net/http"
require "json"
require "uri"
require "securerandom"

require_relative "tsuzura/import_runner"
require_relative "tsuzura/sync_albums_runner"
require_relative "tsuzura/import_options"
require_relative "tsuzura/watch_manifest"

module TsuzuraCLI
  IMAGE_SUFFIXES = %w[.jpg .jpeg .png .gif .webp .heic .heif].freeze

  def self.present?(value)
    !value.to_s.strip.empty?
  end

  class Main < Thor
    package_name "tsuzura"

    desc "import PATH...", "Import files into Tsuzura (updates local manifest by default)"
    option :album, type: :string, aliases: "-a", desc: "Album title (find_or_create; combinable with --auto-date-albums)"
    option :album_id, type: :string, desc: "Existing album ULID"
    option :auto_date_albums, type: :boolean, lazy_default: nil, desc: "Link to inbox + YYYY-MM-DD date albums (omit to use manifest)"
    option :inbox_album, type: :string, desc: "Inbox album title when --auto-date-albums (default: Camera Upload)"
    option :no_manifest, type: :boolean, default: false, desc: "Do not read or write the local import manifest"
    option :manifest_root, type: :string, desc: "Watch root directory for manifest storage"
    option :manifest_file, type: :string, desc: "Explicit manifest JSON path (overrides default under TSUZURA_MANIFEST_DIR)"
    def import(*paths)
      response = ImportRunner.new(cli: self, paths: paths, options: options).run
      print_asciidoc_response(response)
    end

    desc "sync-albums [PATH]", "Re-link existing media (refresh EXIF; same rules as import; uses manifest import options when PATH given)"
    option :album, type: :string, aliases: "-a", desc: "Album title (overrides manifest)"
    option :album_id, type: :string, desc: "Existing album ULID"
    option :auto_date_albums, type: :boolean, lazy_default: nil, desc: "Inbox + date albums from EXIF"
    option :inbox_album, type: :string, desc: "Inbox album title"
    option :no_manifest, type: :boolean, default: false, desc: "Do not read manifest import options"
    option :manifest_root, type: :string, desc: "Watch root for manifest"
    option :manifest_file, type: :string, desc: "Explicit manifest JSON path"
    def sync_albums(path = nil)
      paths = TsuzuraCLI.present?(path) ? [ path ] : []
      stats = SyncAlbumsRunner.new(cli: self, paths: paths, options: options).run
      puts JSON.pretty_generate(stats)
    end

    desc "watch CMD [PATH...]", "Watch imports (CMD: run — scan and import with manifest)"
    option :album, type: :string, aliases: "-a", desc: "Album title (find_or_create)"
    option :album_id, type: :string, desc: "Existing album ULID"
    option :auto_date_albums, type: :boolean, lazy_default: nil, desc: "Link to inbox + YYYY-MM-DD date albums (omit to use manifest)"
    option :inbox_album, type: :string, desc: "Inbox album title when --auto-date-albums"
    option :no_manifest, type: :boolean, default: false, desc: "Do not use manifest"
    option :manifest_root, type: :string, desc: "Watch root for manifest"
    option :manifest_file, type: :string, desc: "Explicit manifest JSON path"
    def watch(cmd, *paths)
      abort "Usage: tsuzura watch run PATH..." unless cmd == "run"

      response = ImportRunner.new(cli: self, paths: paths, options: options).run
      print_asciidoc_response(response)
    end

    desc "manifest show PATH", "Print manifest path and entry count for a watch root"
    option :manifest_file, type: :string, desc: "Explicit manifest JSON path"
    def manifest(action, path = nil)
      abort "Usage: tsuzura manifest show PATH" unless action == "show" && TsuzuraCLI.present?(path)

      root = File.expand_path(path)
      root = File.dirname(root) unless File.directory?(root)
      manifest = WatchManifest.new(root: root, path: options[:manifest_file])
      manifest.load
      puts manifest.path
      puts "root: #{manifest.root}"
      puts "entries: #{manifest.entry_count}"
      puts "import:"
      puts JSON.pretty_generate(manifest.import_config)
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

    no_commands do
      def print_asciidoc_response(response)
        text = response.fetch("asciidoc", "").to_s
        puts text if TsuzuraCLI.present?(text)
      end

      def expand_paths(paths)
        paths.flat_map { |path| expand_path(path) }.uniq.sort_by(&:to_s)
      end

      def post_sync_albums(import_options:)
        uri = URI.join(base_url, "/v1/media/sync_albums")
        request = Net::HTTP::Post.new(uri)
        apply_auth!(request)
        request.set_form_data(ImportOptions.to_api_params(import_options))
        body = execute_json(request, uri)
        body.fetch("stats")
      end

      def post_batch(files, import_options:)
        uri = URI.join(base_url, "/v1/media/batch")
        boundary = "----Tsuzura#{SecureRandom.hex(16)}"
        body = build_multipart(boundary, files, import_options)
        request = Net::HTTP::Post.new(uri)
        apply_auth!(request)
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        request.body = body
        execute_json(request, uri)
      end
    end

    private

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

    def build_multipart(boundary, files, import_options)
      parts = []
      ImportOptions.append_multipart_fields(parts, boundary, import_options)
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
