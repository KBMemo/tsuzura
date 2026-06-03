# frozen_string_literal: true

module Tsuzura
  # MediaItem を複数アルバムに idempotent に追加する。
  class AlbumLinker
    def initialize(albums:)
      @albums = Array(albums)
    end

    # @return [Hash{Symbol=>Object}] :linked_album_ids, :already_linked_album_ids
    def link!(media_item)
      linked = []
      already = []

      @albums.each do |album|
        item = album.album_items.find_by(media_item_id: media_item.id)
        if item
          already << album.id
          next
        end

        position = album.album_items.maximum(:position).to_i + 1
        album.album_items.create!(media_item: media_item, position: position)
        linked << album.id
        update_cover!(album, media_item)
      end

      { linked_album_ids: linked, already_linked_album_ids: already }
    end

    private

    def update_cover!(album, media_item)
      return if album.cover_media_id.present?

      album.update!(cover_media_id: media_item.id)
    end
  end
end
