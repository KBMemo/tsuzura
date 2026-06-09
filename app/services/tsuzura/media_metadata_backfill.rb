# frozen_string_literal: true

module Tsuzura
  class MediaMetadataBackfill
    Result = Struct.new(:total, :updated, :skipped, :failed, :errors, keyword_init: true)

    def initialize(scope: MediaItem.all, missing_only: false, dry_run: false, logger: Rails.logger)
      @scope = scope
      @missing_only = missing_only
      @dry_run = dry_run
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
          next
        end

        Tsuzura::MediaMetadata.apply_from_attachment!(item)
        item.reload
        if metadata_snapshot(item) == before
          result.skipped += 1
        else
          result.updated += 1
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

    def log(message)
      @logger&.info(message)
    end
  end
end
