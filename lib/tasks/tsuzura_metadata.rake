# frozen_string_literal: true

namespace :tsuzura do
  namespace :metadata do
    desc "Refresh media metadata from original attachments. Options: IDS=01...,02... MISSING_ONLY=1 DRY_RUN=1"
    task backfill: :environment do
      run_metadata_refresh(label: "metadata backfill")
    end

    desc "Refresh date/location/dimensions from original Active Storage blobs. Options: IDS=01...,02... MISSING_ONLY=1 DRY_RUN=1"
    task refresh_from_blobs: :environment do
      run_metadata_refresh(label: "metadata refresh_from_blobs")
    end
  end

  def run_metadata_refresh(label:)
    scope = MediaItem.all
    if ENV["IDS"].present?
      ids = ENV.fetch("IDS").split(/[\s,]+/).map(&:strip).reject(&:blank?)
      scope = scope.where(id: ids)
    end

    missing_only = ActiveModel::Type::Boolean.new.cast(ENV["MISSING_ONLY"])
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])
    result = Tsuzura::MediaMetadataBackfill.new(
      scope: scope,
      missing_only: missing_only,
      dry_run: dry_run,
      logger: Rails.logger
    ).call

    puts "#{label}: total=#{result.total} updated=#{result.updated} skipped=#{result.skipped} failed=#{result.failed}"
    result.errors.each do |id, klass, message|
      warn "#{id}: #{klass}: #{message}"
    end
    abort "#{label} failed" if result.failed.positive?
  end
end
