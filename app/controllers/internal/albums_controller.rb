# frozen_string_literal: true

module Internal
  class AlbumsController < ApplicationController
    include InternalAuthenticated

    before_action :verify_internal_secret!

    def index
      owner_id = params.require(:owner_account_id).to_i
      albums = Album.where(owner_account_id: owner_id).order(created_at: :desc)
      render json: {
        albums: albums.map { |album| album_json(album) }
      }
    end

    def show
      album = Album.find_by_ulid(params[:id])
      return render json: { error: "not found" }, status: :not_found unless album

      render json: {
        id: album.id,
        title: album.title,
        owner_account_id: album.owner_account_id,
        media_item_ids: album.album_items.order(:position).pluck(:media_item_id)
      }
    end

    private

    def album_json(album)
      {
        id: album.id,
        title: album.title,
        cover_media_id: album.cover_media_id,
        media_item_count: album.album_items.count
      }
    end
  end
end
