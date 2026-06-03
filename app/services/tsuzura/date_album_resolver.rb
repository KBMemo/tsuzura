# frozen_string_literal: true

module Tsuzura
  # 撮影日（EXIF のみ）からインボックス + 日付アルバムを find_or_create する。
  class DateAlbumResolver
    DEFAULT_INBOX_TITLE = "Camera Upload"
    DEFAULT_DATE_FORMAT = "%Y-%m-%d"

    def initialize(account:, inbox_album_title: nil, date_album_format: nil)
      @account = account
      @inbox_title = inbox_album_title.to_s.strip.presence || DEFAULT_INBOX_TITLE
      @date_format = date_album_format.to_s.strip.presence || DEFAULT_DATE_FORMAT
    end

    # EXIF 撮影日があるときだけ日付アルバムを追加する。
    def albums_for_item(item)
      albums = [ find_or_create_album!(@inbox_title) ]
      if item.exif_captured_at.present?
        date_title = item.exif_captured_at.in_time_zone.strftime(@date_format)
        albums << find_or_create_album!(date_title)
      end
      albums.uniq
    end

    private

    def find_or_create_album!(title)
      Album.find_or_create_by!(owner_account_id: @account.id, title: title)
    end
  end
end
