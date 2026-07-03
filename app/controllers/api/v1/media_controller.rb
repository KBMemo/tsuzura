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
          **import_targeting_options
        ).call(uploads: uploads)

        album = result[:album]
        items = result[:items]
        render json: {
          album: album_json(album),
          albums: result[:albums].map { |a| album_json(a) },
          items: items.map { |item| item_json(item) },
          stats: batch_stats(result),
          asciidoc: Tsuzura::AsciidocFragments.for_batch(album: album, items: items)
        }, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { error: "album not found" }, status: :not_found
      end

      def sync_albums
        targeting = import_targeting
        unless import_targeting_valid?(targeting)
          return render json: { error: "album_title, album_id, album_ids, or auto_date_albums required" },
            status: :unprocessable_entity
        end

        result = Tsuzura::MediaAlbumSync.new(
          account: current_account,
          targeting: targeting,
          refresh_metadata: !ActiveModel::Type::Boolean.new.cast(params[:skip_metadata_refresh]),
          prune_date_albums: !ActiveModel::Type::Boolean.new.cast(params[:skip_prune])
        ).call(media_ids: sync_media_ids_param)

        render json: { stats: result }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "album not found" }, status: :not_found
      end

      def lookup
        checksum = params[:checksum].to_s.strip
        if checksum.blank?
          return render json: { error: "checksum required" }, status: :unprocessable_entity
        end

        item = MediaItem.find_owned_by_checksum(
          owner_account_id: current_account.id,
          checksum: checksum
        )
        render json: { item: item ? item_json(item) : nil }
      end

      def show
        item = find_owned_item
        return unless item

        render json: item_json(item)
      end

      def update_edits
        item = find_owned_item
        return unless item

        stack = Tsuzura::EditStack.normalize(edit_stack_param)
        item.update!(edit_stack: stack)
        ApplyEditStackJob.perform_later(item.id)
        render json: item_json(item)
      rescue Tsuzura::EditStack::ValidationError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def web
        item = MediaItem.find_by_ulid(params[:id])
        return head :not_found unless item

        unless signed_access_allowed?(item)
          return head :forbidden
        end

        deliver_media_blob(item)
      end

      def file
        item = find_owned_item
        return unless item

        deliver_media_blob(item)
      end

      private

      def deliver_media_blob(item)
        blob = media_delivery_blob(item)
        return head :not_found unless blob

        send_data blob.download,
          type: blob.content_type,
          disposition: "inline",
          filename: item.original_filename.presence || blob.filename.to_s
      end

      def media_delivery_blob(item)
        if params[:source].to_s == "original"
          return item.file.blob if item.file.attached?
        elsif item.web.attached?
          return item.web.blob
        end

        item.file.blob if item.file.attached?
      end

      def find_owned_item
        item = MediaItem.find_by_ulid(params[:id])
        unless item
          render json: { error: "not found" }, status: :not_found
          return nil
        end
        unless item.owner_account_id == current_account.id
          render json: { error: "forbidden" }, status: :forbidden
          return nil
        end

        item
      end

      def edit_stack_param
        params.fetch(:edit_stack, ActionController::Parameters.new)
          .permit(:rotate, crop: %i[x y w h], blur_regions: %i[x y w h strength])
          .to_h
      end

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

      def import_targeting
        Tsuzura::ImportTargeting.new(account: current_account, **import_targeting_options)
      end

      def import_targeting_options
        {
          album_title: params[:album_title],
          album_id: params[:album_id],
          album_ids: batch_album_ids_param,
          auto_date_albums: params[:auto_date_albums],
          inbox_album_title: params[:inbox_album_title],
          date_album_format: params[:date_album_format]
        }
      end

      def import_targeting_valid?(targeting)
        targeting.auto_date_albums ||
          params[:album_title].present? ||
          params[:album_id].present? ||
          batch_album_ids_param.any?
      end

      def sync_media_ids_param
        Array(params[:media_ids]).concat(Array(params[:"media_ids[]"]))
      end

      def batch_album_ids_param
        ids = Array(params[:album_ids])
        ids.concat(Array(params[:"album_ids[]"])) if params[:"album_ids[]"].present?
        ids
      end

      def batch_stats(result)
        {
          total: result[:items].size,
          created: result[:created_items].size,
          linked: result[:linked_items].size
        }
      end

      def item_json(item)
        payload = {
          id: item.id,
          kind: item.kind,
          original_filename: item.original_filename,
          checksum: item.checksum,
          width: item.width,
          height: item.height,
          captured_at: item.captured_at&.iso8601,
          file_mtime: item.file_mtime&.iso8601,
          exif_captured_at: item.exif_captured_at&.iso8601,
          exif: item.exif,
          edit_stack: item.edit_stack
        }
        location = location_json(item)
        payload[:location] = location if location
        payload
      end

      def location_json(item)
        return nil if item.latitude.blank? || item.longitude.blank?

        { latitude: item.latitude.to_f, longitude: item.longitude.to_f }
      end
    end
  end
end
