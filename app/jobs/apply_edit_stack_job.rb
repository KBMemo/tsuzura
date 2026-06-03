# frozen_string_literal: true

class ApplyEditStackJob < ApplicationJob
  queue_as :default

  def perform(media_item_id)
    item = MediaItem.find_by(id: media_item_id)
    return unless item

    Tsuzura::EditStackRenderer.new(item).call
  end
end
