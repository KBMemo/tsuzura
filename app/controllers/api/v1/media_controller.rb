# frozen_string_literal: true

module Api
  module V1
    class MediaController < BaseController
      skip_before_action :authenticate_account!, only: :web

      def batch
        uploads = Array(params[:files]).compact
        if uploads.empty?
          return render json: { error: "files required" }, status: :unprocessable_entity
        end

        result = Tsuzura::BatchImport.new(
          account: current_account,
          album_title: params[:album_title],
          album_id: params[:album_id]
        ).call(uploads: uploads)

        album = result[:album]
        items = result[:items]
        render json: {
          album: album_json(album),
          items: items.map { |item| item_json(item) },
          asciidoc: Tsuzura::AsciidocFragments.for_batch(album: album, items: items)
        }, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { error: "album not found" }, status: :not_found
      end

      def show
        item = MediaItem.find_by_ulid(params[:id])
        return render json: { error: "not found" }, status: :not_found unless item
        return render json: { error: "forbidden" }, status: :forbidden unless item.owner_account_id == current_account.id

        render json: item_json(item)
      end

      def web
        item = MediaItem.find_by_ulid(params[:id])
        return head :not_found unless item

        unless signed_access_allowed?(item)
          return head :forbidden
        end

        blob = item.web.attached? ? item.web.blob : item.file.blob
        return head :not_found unless blob

        send_data blob.download,
          type: blob.content_type,
          disposition: "inline",
          filename: item.original_filename.presence || blob.filename.to_s
      end

      private

      def signed_access_allowed?(item)
        exp = params[:exp]
        sig = params[:sig]
        memo_id = params[:memo_id]
        return false if exp.blank? || sig.blank? || memo_id.blank?

        Tsuzura::MediaUrlSigner.valid?(
          media_id: item.id,
          memo_id: memo_id,
          exp: exp,
          sig: sig
        )
      end

      def album_json(album)
        { id: album.id, title: album.title }
      end

      def item_json(item)
        {
          id: item.id,
          kind: item.kind,
          original_filename: item.original_filename,
          width: item.width,
          height: item.height,
          captured_at: item.captured_at
        }
      end
    end
  end
end
