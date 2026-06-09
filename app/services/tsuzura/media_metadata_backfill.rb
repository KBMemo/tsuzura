# frozen_string_literal: true

module Tsuzura
  class MediaMetadataBackfill
    Result = Struct.new(:total, :updated, :skipped, :failed, :errors, keyword_init: true)

    def initialize(scope: MediaItem.all, missing_only: false, dry_run: false, verbose: false, logger: Rails.logger)
      @scope = scope
      @missing_only = missing_only
      @dry_run = dry_run
      @verbose = verbose
      @logger = logger
    end

    def call
      result = Result.new(total: 0, updated: 0, skipped: 0, failed: 0, errors: [])

      relation.find_each do |item|
        result.total += 1
        before = metadata_snapshot(item)

        if @dry_run
          result.updated += 1
          log("would refresh metadata for #{item.id}")
          verbose_item(item, before, before, "dry_run")
          next
        end

        Tsuzura::MediaMetadata.apply_from_attachment!(item)
        item.reload
        after = metadata_snapshot(item)
        if after == before
          result.skipped += 1
          verbose_item(item, before, after, "skipped")
        else
          result.updated += 1
          verbose_item(item, before, after, "updated")
        end
      rescue StandardError => e
        result.failed += 1
        result.errors << [ item&.id, e.class.name, e.message ]
        log("metadata backfill failed for #{item&.id}: #{e.class}: #{e.message}")
      end

      result
    end

    private

    def relation
      rel = @scope.where(kind: "image").includes(file_attachment: :blob)
      rel = rel.where("captured_at IS NULL OR width IS NULL OR height IS NULL OR latitude IS NULL OR longitude IS NULL OR exif = '{}'::jsonb") if @missing_only
      rel
    end

    def metadata_snapshot(item)
      item.attributes.slice(
        "exif_captured_at",
        "file_mtime",
        "captured_at",
        "latitude",
        "longitude",
        "exif",
        "width",
        "height"
      )
    end

    def verbose_item(item, before, after, status)
      return unless @verbose

      puts [
        status,
        item.id,
        item.original_filename,
        "captured_at=#{format_change(before, after, 'captured_at')}",
        "exif_captured_at=#{format_change(before, after, 'exif_captured_at')}",
        "lat=#{format_change(before, after, 'latitude')}",
        "lon=#{format_change(before, after, 'longitude')}",
        "size=#{format_change(before, after, 'width')}x#{format_change(before, after, 'height')}",
        "exif_keys=#{Array(after['exif']&.keys).sort.join(',')}"
      ].join(" | ")
    end

    def format_change(before, after, key)
      old_value = before[key].presence || "-"
      new_value = after[key].presence || "-"
      old_value == new_value ? new_value : "#{old_value}->#{new_value}"
    end

    def log(message)
      @logger&.info(message)
      puts message if @verbose
    end
  end
end
