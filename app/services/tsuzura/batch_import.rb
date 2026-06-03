# frozen_string_literal: true

module Tsuzura
  class BatchImport
    def initialize(
      account:,
      album_title: nil,
      album_id: nil,
      album_ids: nil,
      auto_date_albums: false,
      inbox_album_title: nil,
      date_album_format: nil
    )
      @account = account
      @targeting = ImportTargeting.new(
        account: account,
        album_title: album_title,
        album_id: album_id,
        album_ids: album_ids,
        auto_date_albums: auto_date_albums,
        inbox_album_title: inbox_album_title,
        date_album_format: date_album_format
      )
    end

    def call(uploads:)
      items = []
      created_items = []
      linked_items = []
      albums_seen = []

      uploads.each do |upload|
        item, created = find_or_create_item!(upload)
        albums = @targeting.albums_for_item(item)
        albums_seen.concat(albums)
        link_result = AlbumLinker.new(albums: albums).link!(item)

        items << item
        if created
          created_items << item
        elsif link_result[:linked_album_ids].any?
          linked_items << item
        end
      end

      albums = albums_seen.uniq
      {
        albums: albums,
        album: albums.first,
        items: items,
        created_items: created_items,
        linked_items: linked_items.uniq
      }
    end

    private

    def find_or_create_item!(upload)
      checksum = UploadChecksum.from_upload(upload)
      existing = MediaItem.find_owned_by_checksum(owner_account_id: @account.id, checksum: checksum)
      if existing
        backfill_metadata!(existing, upload)
        return [ existing, false ]
      end

      item = MediaItem.new(owner_account_id: @account.id, kind: "image")
      item.assign_ulid
      item.attach_upload!(upload)
      [ item, true ]
    end

    def backfill_metadata!(item, upload)
      MediaMetadata.apply_from_upload!(item, upload)
    end
  end
end
