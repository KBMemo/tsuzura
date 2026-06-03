# frozen_string_literal: true

require "json"
require "pathname"
require "digest"
require "fileutils"

require_relative "import_options"

module TsuzuraCLI
  # 監視ディレクトリごとの取り込み状態（ローカル JSON）。
  class WatchManifest
    VERSION = 2

    Entry = Data.define(:size, :mtime, :checksum, :media_id, :imported_at) do
      def self.from_h(hash)
        return nil if hash.nil? || hash.empty?

        new(
          size: hash["size"].to_i,
          mtime: hash["mtime"].to_i,
          checksum: hash["checksum"].to_s,
          media_id: WatchManifest.blank_to_nil(hash["media_id"]),
          imported_at: WatchManifest.blank_to_nil(hash["imported_at"])
        )
      end

      def fresh_for?(stat)
        size == stat.size && mtime == stat.mtime.to_i
      end

      def to_h
        {
          "size" => size,
          "mtime" => mtime,
          "checksum" => checksum,
          "media_id" => media_id,
          "imported_at" => imported_at
        }.compact
      end
    end

    class << self
      def store_dir
        Pathname(ENV.fetch("TSUZURA_MANIFEST_DIR", File.expand_path("~/.local/share/tsuzura/manifests")))
      end

      def path_for_root(root)
        root = File.expand_path(root)
        slug = Digest::SHA256.hexdigest(root)[0, 16]
        store_dir.join("#{slug}.json")
      end
    end

    def initialize(root:, path: nil)
      @root = File.expand_path(root)
      @path = Pathname(path || self.class.path_for_root(@root))
      @entries = {}
      @import_config = {}
      @loaded = false
    end

    attr_reader :root, :path, :import_config

    def entry_count
      load
      @entries.size
    end

    def load
      return self if @loaded

      @loaded = true
      return self unless @path.file?

      data = JSON.parse(@path.read)
      unless data["root"].to_s == @root
        warn "Manifest root mismatch (#{data['root'].inspect} vs #{@root}), re-keying entries under current root"
      end

      data.fetch("entries", {}).each do |key, value|
        entry = Entry.from_h(value)
        @entries[normalize_key(key)] = entry if entry
      end
      @import_config = data.fetch("import", {})
      self
    end

    def record_import_config!(config)
      load
      @import_config = ImportOptions.normalize(config)
      self
    end

    def save!
      load
      @path.dirname.mkpath
      payload = {
        "version" => VERSION,
        "root" => @root,
        "import" => @import_config,
        "entries" => @entries.transform_values(&:to_h)
      }
      temp = Pathname("#{@path}.tmp")
      temp.write(JSON.pretty_generate(payload))
      temp.chmod(0o600)
      FileUtils.mv(temp, @path, force: true)
      self
    end

    def entry_for(file_path)
      load
      @entries[normalize_key(file_path)]
    end

    def fresh?(file_path)
      stat = stat_for(file_path)
      entry = entry_for(file_path)
      entry&.fresh_for?(stat)
    end

    def record!(file_path, checksum:, media_id:, imported_at: Time.now.iso8601)
      load
      stat = stat_for(file_path)
      @entries[normalize_key(file_path)] = Entry.new(
        size: stat.size,
        mtime: stat.mtime.to_i,
        checksum: checksum,
        media_id: media_id,
        imported_at: imported_at
      )
      self
    end

    def partition_files(file_paths)
      load
      file_paths.partition { |path| fresh?(path) }
    end

    def resolve_root!(file_paths)
      paths = file_paths.map { |p| File.expand_path(p.to_s) }
      under_root = paths.all? { |p| p.start_with?(@root + File::SEPARATOR) || p == @root }
      return if under_root

      raise ArgumentError, "All files must be under manifest root #{@root}"
    end

    def self.blank_to_nil(value)
      text = value.to_s.strip
      text.empty? ? nil : text
    end

    private

    def normalize_key(file_path)
      File.expand_path(file_path.to_s)
    end

    def stat_for(file_path)
      File.stat(file_path)
    end
  end
end
