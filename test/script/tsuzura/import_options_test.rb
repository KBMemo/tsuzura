# frozen_string_literal: true

require "minitest/autorun"

require_relative "../../../script/tsuzura/import_options"

class ImportOptionsMergeTest < Minitest::Test
  def test_merge_keeps_stored_when_cli_empty
    stored = { "album_title" => "Trip 2026", "auto_date_albums" => true }
    cli = { album: nil, album_id: nil, inbox_album: nil, auto_date_albums: nil }

    merged = TsuzuraCLI::ImportOptions.merge(stored: stored, cli: cli)

    assert_equal "Trip 2026", merged["album_title"]
    assert merged["auto_date_albums"]
  end

  def test_merge_cli_overrides_stored_album_title
    stored = { "album_title" => "Old" }
    cli = { album: "New", album_id: nil, inbox_album: nil, auto_date_albums: nil }

    merged = TsuzuraCLI::ImportOptions.merge(stored: stored, cli: cli)

    assert_equal "New", merged["album_title"]
  end

  def test_append_multipart_fields_builds_binary_strings
    parts = []
    TsuzuraCLI::ImportOptions.append_multipart_fields(
      parts,
      "boundary",
      { "album_title" => "Album", "auto_date_albums" => true }
    )
    parts << "--boundary--\r\n".b

    body = parts.inject(+"", :<<)
    assert_kind_of String, body
    assert parts.all? { |part| part.is_a?(String) }
  end

  def test_valid_detects_target_album_configuration
    refute TsuzuraCLI::ImportOptions.valid?({})
    assert TsuzuraCLI::ImportOptions.valid?({ "auto_date_albums" => true })
    assert TsuzuraCLI::ImportOptions.valid?({ "album_title" => "X" })
  end
end
