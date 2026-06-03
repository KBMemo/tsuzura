# frozen_string_literal: true

module Tsuzura
  class BatchImport
    def initialize(account:, album_title: nil, album_id: nil, album_ids: nil)
      @account = account
      @album_title = album_title.to_s.strip.presence
      @album_id = Album.normalize_ulid(album_id)
      @album_ids = normalize_album_ids(album_ids)
    end

    def call(uploads:)
      albums = resolve_target_albums!
      items = []
      created_items = []
      linked_items = []

      uploads.each do |upload|
        item, created = find_or_create_item!(upload)
        link_result = AlbumLinker.new(albums: albums).link!(item)

        items << item
        if created
          created_items << item
        elsif link_result[:linked_album_ids].any?
          linked_items << item
        end
      end

      {
        albums: albums,
        album: albums.first,
        items: items,
        created_items: created_items,
        linked_items: linked_items.uniq
      }
    end

    private

    def normalize_album_ids(raw)
      list = Array(raw).flat_map { |entry| entry.to_s.split(",") }
      ids = list.map { |id| Album.normalize_ulid(id) }.compact
      ids << @album_id if @album_id.present?
      ids.uniq
    end

    def resolve_target_albums!
      if @album_ids.any?
        return @album_ids.map { |id| find_owned_album!(id) }
      end

      title = @album_title.presence || "Import #{Time.current.strftime('%Y-%m-%d %H:%M')}"
      [ Album.create!(owner_account_id: @account.id, title: title) ]
    end

    def find_owned_album!(ulid)
      album = Album.find_by_ulid(ulid)
      raise ActiveRecord::RecordNotFound, "album not found" unless album
      raise ActiveRecord::RecordNotFound, "album forbidden" unless album.owner_account_id == @account.id

      album
    end

    def find_or_create_item!(upload)
      checksum = UploadChecksum.from_upload(upload)
      existing = MediaItem.find_owned_by_checksum(owner_account_id: @account.id, checksum: checksum)
      return [ existing, false ] if existing

      item = MediaItem.new(owner_account_id: @account.id, kind: "image")
      item.assign_ulid
      item.attach_upload!(upload)
      [ item, true ]
    end

  end
end
