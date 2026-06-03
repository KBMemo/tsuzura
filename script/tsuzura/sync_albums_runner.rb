# frozen_string_literal: true

require_relative "import_options"
require_relative "watch_manifest"

module TsuzuraCLI
  class SyncAlbumsRunner
    def initialize(cli:, paths:, options:)
      @cli = cli
      @paths = Array(paths)
      @options = options
    end

    def run
      import_options = resolve_import_options
      validate_target_album!(import_options)

      stats = @cli.post_sync_albums(import_options: import_options)
      $stderr.puts "Tsuzura sync: #{stats.fetch('total')} item(s), " \
        "#{stats.fetch('linked').size} linked, " \
        "#{stats.fetch('pruned_album_ids').size} date album(s) pruned, " \
        "#{stats.fetch('refreshed').size} metadata refreshed"
      stats
    end

    private

    def resolve_import_options
      stored = {}
      if !@options[:no_manifest] && manifest_root
        manifest = WatchManifest.new(
          root: manifest_root,
          path: blank_option(:manifest_file)
        )
        manifest.load
        stored = manifest.import_config
      end
      ImportOptions.merge(stored: stored, cli: @options)
    end

    def manifest_root
      return File.expand_path(@options[:manifest_root]) if blank_option(:manifest_root)

      return if @paths.empty?

      path = File.expand_path(@paths.first)
      File.directory?(path) ? path : File.dirname(path)
    end

    def validate_target_album!(import_options)
      return if ImportOptions.valid?(import_options)

      abort "Specify --album, --album-id, --auto-date-albums, or run import once to store options in the manifest"
    end

    def blank_option(key)
      value = @options[key].to_s.strip
      value.empty? ? nil : value
    end
  end
end
