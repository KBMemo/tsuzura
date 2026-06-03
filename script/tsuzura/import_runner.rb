# frozen_string_literal: true

require_relative "file_checksum"
require_relative "import_options"
require_relative "watch_manifest"

module TsuzuraCLI
  class ImportRunner
    def initialize(cli:, paths:, options:)
      @cli = cli
      @paths = paths
      @options = options
    end

    def run
      files = @cli.expand_paths(@paths)
      abort "No image files found" if files.empty?

      if manifest_disabled?
        import_options = ImportOptions.merge(stored: {}, cli: @options)
        validate_target_album!(import_options)
        return @cli.post_batch(files, import_options: import_options)
      end

      root = resolve_manifest_root(files)
      manifest = WatchManifest.new(
        root: root,
        path: blank_option(:manifest_file)
      )
      manifest.load
      import_options = ImportOptions.merge(stored: manifest.import_config, cli: @options)
      validate_target_album!(import_options)
      manifest.resolve_root!(files)

      fresh, stale = manifest.partition_files(files)
      if stale.empty?
        manifest.record_import_config!(import_options)
        manifest.save!
        $stderr.puts "Tsuzura: #{fresh.size} file(s) up to date (manifest #{manifest.path})"
        return { "items" => [], "asciidoc" => "", "stats" => { "total" => 0, "created" => 0, "linked" => 0 } }
      end

      $stderr.puts "Tsuzura: importing #{stale.size} file(s), skipping #{fresh.size} unchanged (manifest #{manifest.path})"
      response = @cli.post_batch(stale, import_options: import_options)
      record_manifest_entries!(manifest, stale, response)
      manifest.record_import_config!(import_options)
      manifest.save!
      response
    end

    private

    def manifest_disabled?
      @options[:no_manifest]
    end

    def validate_target_album!(import_options)
      return if ImportOptions.valid?(import_options)

      abort "Specify --album, --album-id, or --auto-date-albums (or run once with those flags to store them in the manifest)"
    end

    def blank_option(key)
      value = @options[key].to_s.strip
      value.empty? ? nil : value
    end

    def resolve_manifest_root(files)
      if (root = blank_option(:manifest_root))
        return File.expand_path(root)
      end

      expanded = @paths.map { |p| File.expand_path(p) }
      if expanded.size == 1 && File.directory?(expanded.first)
        return expanded.first
      end

      parents = files.map { |f| File.dirname(File.expand_path(f.to_s)) }.uniq
      common = parents.reduce { |a, b| common_path_prefix(a, b) }
      if !common.to_s.empty? && File.directory?(common)
        return common
      end

      abort "Cannot infer manifest root for multiple paths; use --manifest-root DIR or --no-manifest"
    end

    def common_path_prefix(a, b)
      a_parts = Pathname(a).each_filename.to_a
      b_parts = Pathname(b).each_filename.to_a
      parts = a_parts.zip(b_parts).take_while { |x, y| x == y }.map(&:first)
      return "" if parts.empty?

      File.join("/", *parts)
    end

    def record_manifest_entries!(manifest, files, response)
      items_by_checksum = {}
      Array(response["items"]).each do |item|
        items_by_checksum[item["checksum"]] = item
      end
      imported_at = Time.now.iso8601

      files.each do |file|
        checksum = FileChecksum.from_path(file)
        item = items_by_checksum[checksum]
        unless item
          warn "Tsuzura: no batch item for #{file} (checksum #{checksum})"
          next
        end

        manifest.record!(
          file,
          checksum: checksum,
          media_id: item.fetch("id"),
          imported_at: imported_at
        )
      end
    end
  end
end
