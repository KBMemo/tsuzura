# frozen_string_literal: true

module Tsuzura
  # 登録済み MediaItem のメタデータ再抽出とアルバム振り分け（取り込みと同じルール）。
  class MediaAlbumSync
    DATE_ALBUM_TITLE_PATTERN = /\A\d{4}-\d{2}-\d{2}\z/

    def initialize(account:, targeting:, refresh_metadata: true, prune_date_albums: true)
      @account = account
      @targeting = targeting
      @refresh_metadata = refresh_metadata
      @prune_date_albums = prune_date_albums && targeting.auto_date_albums
    end

    def call(media_ids: nil)
      items = scoped_items(media_ids)
      linked = []
      pruned = []
      refreshed = []

      items.find_each do |item|
        next unless item.file.attached?

        if @refresh_metadata
          MediaMetadata.apply_from_attachment!(item)
          refreshed << item.id
        end

        if @prune_date_albums
          pruned.concat(prune_misplaced_date_albums!(item))
        end

        albums = @targeting.albums_for_item(item)
        result = AlbumLinker.new(albums: albums).link!(item)
        linked << item.id if result[:linked_album_ids].any?
      end

      {
        total: items.count,
        refreshed: refreshed.uniq,
        linked: linked.uniq,
        pruned_album_ids: pruned.uniq
      }
    end

    private

    def scoped_items(media_ids)
      scope = MediaItem.where(owner_account_id: @account.id).includes(:albums)
      ids = Array(media_ids).map { |id| MediaItem.normalize_ulid(id) }.compact
      scope = scope.where(id: ids) if ids.any?
      scope
    end

    def prune_misplaced_date_albums!(item)
      expected_title = item.exif_captured_at&.in_time_zone&.strftime(@targeting.date_album_format)
      removed = []

      item.albums.each do |album|
        next unless album.title.match?(DATE_ALBUM_TITLE_PATTERN)
        next if expected_title.present? && album.title == expected_title

        album_item = album.album_items.find_by(media_item_id: item.id)
        next unless album_item

        album_item.destroy!
        removed << album.id
      end

      removed
    end
  end
end
