# frozen_string_literal: true

module Tsuzura
  class BatchImport
    def initialize(account:, album_title: nil, album_id: nil)
      @account = account
      @album_title = album_title.to_s.strip.presence
      @album_id = Album.normalize_ulid(album_id)
    end

    def call(uploads:)
      album = find_or_create_album!
      items = []
      position = album.album_items.maximum(:position).to_i + 1

      uploads.each do |upload|
        item = MediaItem.new(owner_account_id: @account.id, kind: "image")
        item.assign_ulid
        item.attach_upload!(upload)
        album.album_items.create!(media_item: item, position: position)
        position += 1
        items << item
      end

      album.update!(cover_media_id: items.first.id) if album.cover_media_id.blank? && items.any?

      { album: album, items: items }
    end

    private

    def find_or_create_album!
      if @album_id.present?
        album = Album.find_by_ulid(@album_id)
        raise ActiveRecord::RecordNotFound, "album not found" unless album
        raise ActiveRecord::RecordNotFound, "album forbidden" unless album.owner_account_id == @account.id

        return album
      end

      title = @album_title.presence || "Import #{Time.current.strftime('%Y-%m-%d %H:%M')}"
      Album.create!(owner_account_id: @account.id, title: title)
    end
  end
end
