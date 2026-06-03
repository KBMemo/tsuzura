# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "pathname"

require_relative "../../../script/tsuzura/file_checksum"
require_relative "../../../script/tsuzura/watch_manifest"

class TsuzuraCLI::WatchManifestTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("tsuzura-manifest")
    @root = File.join(@tmpdir, "Camera Upload")
    FileUtils.mkdir_p(@root)
    @manifest_path = File.join(@tmpdir, "test-manifest.json")
    @manifest = TsuzuraCLI::WatchManifest.new(root: @root, path: @manifest_path)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_save_and_load_roundtrip
    file = write_file("photo.jpg", "jpeg-bytes-one")
    checksum = TsuzuraCLI::FileChecksum.from_path(file)

    @manifest.record!(file, checksum: checksum, media_id: "01KT40HPN43ADGG3KQ6ABJ4CJB")
    @manifest.save!

    reloaded = TsuzuraCLI::WatchManifest.new(root: @root, path: @manifest_path)
    reloaded.load
    entry = reloaded.entry_for(file)

    assert_equal checksum, entry.checksum
    assert_equal "01KT40HPN43ADGG3KQ6ABJ4CJB", entry.media_id
    assert reloaded.fresh?(file)
  end

  def test_fresh_returns_false_when_mtime_changes
    file = write_file("photo.jpg", "bytes")
    checksum = TsuzuraCLI::FileChecksum.from_path(file)
    @manifest.record!(file, checksum: checksum, media_id: "01KT40HPN43ADGG3KQ6ABJ4CJB")
    @manifest.save!

    mtime = Time.utc(2026, 1, 15, 12, 0, 0)
    File.utime(mtime, mtime, file)

    refute @manifest.fresh?(file)
  end

  def test_partition_files_splits_unchanged_and_stale
    unchanged = write_file("same.jpg", "same")
    stale = write_file("new.jpg", "new")
    checksum = TsuzuraCLI::FileChecksum.from_path(unchanged)
    @manifest.record!(unchanged, checksum: checksum, media_id: "01KT40HPN43ADGG3KQ6ABJ4CJB")
    @manifest.save!

    fresh, needs_import = @manifest.partition_files([ unchanged, stale ])

    assert_equal [ unchanged ], fresh
    assert_equal [ stale ], needs_import
  end

  def test_save_and_load_import_config
    @manifest.record_import_config!(
      "album_title" => "Trip 2026",
      "auto_date_albums" => true,
      "inbox_album_title" => "Camera Upload"
    )
    @manifest.save!

    reloaded = TsuzuraCLI::WatchManifest.new(root: @root, path: @manifest_path)
    reloaded.load

    assert_equal "Trip 2026", reloaded.import_config["album_title"]
    assert reloaded.import_config["auto_date_albums"]
    assert_equal "Camera Upload", reloaded.import_config["inbox_album_title"]
  end

  def test_path_for_root_is_stable
    path_a = TsuzuraCLI::WatchManifest.path_for_root(@root)
    path_b = TsuzuraCLI::WatchManifest.path_for_root(@root)

    assert_equal path_a, path_b
    assert_match(/\.json\z/, path_a.to_s)
  end

  private

  def write_file(name, contents)
    path = File.join(@root, name)
    File.binwrite(path, contents)
    path
  end
end
