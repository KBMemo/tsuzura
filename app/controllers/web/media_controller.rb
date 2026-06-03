# frozen_string_literal: true

module Web
  class MediaController < BaseController
    def edit
      @item = find_owned_item!
    end

    def preview
      @item = find_owned_item!
      attachment = @item.web.attached? ? @item.web : @item.file
      return head :not_found unless attachment.attached?

      send_data attachment.download,
        type: attachment.content_type,
        disposition: "inline",
        filename: @item.original_filename.presence || "preview.jpg"
    end

    def update
      @item = find_owned_item!
      stack = Tsuzura::EditStack.normalize(edit_stack_params)
      @item.update!(edit_stack: stack)
      ApplyEditStackJob.perform_later(@item.id)
      redirect_to edit_web_medium_path(@item), notice: "編集を保存しました。表示用画像を生成しています。"
    rescue Tsuzura::EditStack::ValidationError => e
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    private

    def find_owned_item!
      item = MediaItem.find_by_ulid(params[:id])
      raise ActiveRecord::RecordNotFound unless item
      raise ActiveRecord::RecordNotFound unless item.owner_account_id == current_account.id

      item
    end

    def edit_stack_params
      permitted = params.fetch(:edit_stack, {}).permit(
        :rotate,
        crop: %i[x y w h],
        blur_regions: %i[x y w h strength]
      ).to_h
      merge_default_crop!(permitted)
      permitted
    end

    def merge_default_crop!(payload)
      crop = payload["crop"]
      return if crop.blank?

      defaults = { "x" => "0", "y" => "0", "w" => "1", "h" => "1" }
      payload["crop"] = defaults.merge(crop.stringify_keys) do |_key, default, value|
        value.presence || default
      end
    end
  end
end
