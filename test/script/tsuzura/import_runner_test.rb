# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "ostruct"

require_relative "../../../script/tsuzura/import_runner"
require_relative "../../../script/tsuzura/watch_manifest"

class ImportRunnerCliStub
  IMAGE_SUFFIXES = %w[.jpg .jpeg .png .gif .webp .heic .heif].freeze

  attr_reader :batch_calls

  def initialize(root)
    @root = root
    @batch_calls = []
  end

  def expand_paths(paths)
    paths.flat_map do |path|
      p = Pathname(File.expand_path(path))
      if p.directory?
        p.glob("**/*").select(&:file?).select { |f| image_file?(f) }
      elsif p.file? && image_file?(p)
        [ p ]
      else
        []
      end
    end
  end

  def post_batch(files, import_options:)
    @batch_calls << { files: files.map(&:to_s), import_options: import_options }
    items = files.map do |file|
      {
        "id" => "01KT40HPN43ADGG3KQ6ABJ4CJB",
        "checksum" => TsuzuraCLI::FileChecksum.from_path(file)
      }
    end
    { "items" => items, "asciidoc" => "image::media:01KT…[]", "stats" => {} }
  end

  private

  def image_file?(path)
    IMAGE_SUFFIXES.include?(path.extname.downcase)
  end
end

class TsuzuraCLI::ImportRunnerTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("tsuzura-import")
    @root = File.join(@tmpdir, "watch")
    FileUtils.mkdir_p(@root)
    ENV["TSUZURA_MANIFEST_DIR"] = File.join(@tmpdir, "manifests")
    @cli = ImportRunnerCliStub.new(@root)
    @options = {
      auto_date_albums: true,
      album: nil,
      album_id: nil,
      inbox_album: nil,
      no_manifest: false,
      manifest_root: nil,
      manifest_file: nil
    }
    @options_minimal = @options.merge(auto_date_albums: nil)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    ENV.delete("TSUZURA_MANIFEST_DIR")
  end

  def test_second_run_skips_unchanged_files
    write_file("a.jpg", "one")
    runner = TsuzuraCLI::ImportRunner.new(cli: @cli, paths: [ @root ], options: @options)
    runner.run
    assert_equal 1, @cli.batch_calls.size
    assert @cli.batch_calls.last[:import_options]["auto_date_albums"]

    TsuzuraCLI::ImportRunner.new(cli: @cli, paths: [ @root ], options: @options_minimal).run
    assert_equal 1, @cli.batch_calls.size, "unchanged files should not be sent again"

    manifest = TsuzuraCLI::WatchManifest.new(root: @root).load
    assert manifest.import_config["auto_date_albums"]
  end

  def test_second_run_uses_manifest_import_options_without_cli_flags
    write_file("a.jpg", "one")
    TsuzuraCLI::ImportRunner.new(cli: @cli, paths: [ @root ], options: @options.merge(album: "Trip 2026")).run

    path = write_file("b.jpg", "two")
    TsuzuraCLI::ImportRunner.new(cli: @cli, paths: [ @root ], options: @options_minimal).run

    assert_equal 2, @cli.batch_calls.size
    assert_equal "Trip 2026", @cli.batch_calls.last[:import_options]["album_title"]
    assert @cli.batch_calls.last[:import_options]["auto_date_albums"]
  end

  def test_mtime_change_triggers_second_import
    path = write_file("a.jpg", "one")
    runner = TsuzuraCLI::ImportRunner.new(cli: @cli, paths: [ @root ], options: @options)
    runner.run

    mtime = Time.utc(2026, 2, 1, 9, 0, 0)
    File.utime(mtime, mtime, path)
    runner.run

    assert_equal 2, @cli.batch_calls.size
  end

  private

  def write_file(name, contents)
    path = File.join(@root, name)
    File.binwrite(path, contents)
    path
  end
end
