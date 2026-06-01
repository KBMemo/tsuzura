# frozen_string_literal: true

class Album < ApplicationRecord
  include UlidRecord

  self.table_name = "tsuzura_albums"

  belongs_to :owner, class_name: "Account", foreign_key: :owner_account_id
  belongs_to :cover_media, class_name: "MediaItem", optional: true

  has_many :album_items, dependent: :destroy
  has_many :media_items, through: :album_items

  validates :title, presence: true, length: { maximum: 200 }
end
