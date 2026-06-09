# frozen_string_literal: true

module Web
  class MediaDatesController < BaseController
    def index
      items = MediaItem
        .where(owner_account_id: current_account.id, kind: "image")
        .includes({ file_attachment: :blob }, { web_attachment: :blob })
        .order(Arel.sql("COALESCE(exif_captured_at, captured_at, file_mtime, created_at) DESC"), created_at: :desc)

      @date_groups = items.group_by { |item| timeline_date(item) }
        .map { |date, grouped_items| { date: date, items: grouped_items } }
    end

    private

    def timeline_date(item)
      (item.exif_captured_at || item.captured_at || item.file_mtime || item.created_at).in_time_zone.to_date
    end
  end
end
