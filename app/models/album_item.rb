# frozen_string_literal: true

class AlbumItem < ApplicationRecord
  self.table_name = "tsuzura_album_items"

  belongs_to :album
  belongs_to :media_item

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
