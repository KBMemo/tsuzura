# frozen_string_literal: true

module Api
  module V1
    class AlbumsController < BaseController
      def create
        album = Album.create!(
          owner_account_id: current_account.id,
          title: params.require(:title),
          description: params[:description]
        )
        render json: album_json(album), status: :created
      end

      def show
        album = Album.find_by_ulid(params[:id])
        return render json: { error: "not found" }, status: :not_found unless album
        return render json: { error: "forbidden" }, status: :forbidden unless album.owner_account_id == current_account.id

        render json: album_json(album).merge(
          media_items: album.album_items.order(:position).includes(:media_item).map do |ai|
            { id: ai.media_item.id, position: ai.position, original_filename: ai.media_item.original_filename }
          end
        )
      end

      def index
        albums = Album.where(owner_account_id: current_account.id).order(created_at: :desc)
        render json: { albums: albums.map { |a| album_json(a) } }
      end

      private

      def album_json(album)
        { id: album.id, title: album.title, cover_media_id: album.cover_media_id }
      end
    end
  end
end
