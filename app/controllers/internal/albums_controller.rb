# frozen_string_literal: true

module Internal
  class AlbumsController < ApplicationController
    include InternalAuthenticated

    before_action :verify_internal_secret!

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
  end
end
