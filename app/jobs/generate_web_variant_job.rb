# frozen_string_literal: true

class GenerateWebVariantJob < ApplicationJob
  queue_as :default

  def perform(media_item_id)
    item = MediaItem.find_by(id: media_item_id)
    return unless item

    item.generate_web_variant!
  end
end
