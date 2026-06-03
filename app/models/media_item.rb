# frozen_string_literal: true

class MediaItem < ApplicationRecord
  include UlidRecord

  self.table_name = "tsuzura_media_items"

  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/heic image/heif].freeze

  belongs_to :owner, class_name: "Account", foreign_key: :owner_account_id

  has_many :album_items, foreign_key: :media_item_id, dependent: :destroy
  has_many :albums, through: :album_items

  has_one_attached :file
  has_one_attached :web

  validates :kind, inclusion: { in: %w[image video] }

  scope :for_owner_checksum, ->(owner_account_id, checksum) {
    where(owner_account_id: owner_account_id, checksum: checksum)
  }

  def self.find_owned_by_checksum(owner_account_id:, checksum:)
    return nil if checksum.blank?

    for_owner_checksum(owner_account_id, checksum).first
  end

  def attach_upload!(uploaded_file)
    assign_ulid if id.blank?
    file.attach(uploaded_file)
    self.original_filename = uploaded_file.original_filename
    self.checksum = file.blob&.checksum
    self.edit_stack = {} if edit_stack.blank?
    save!
    generate_web_variant_later
  end

  def generate_web_variant!
    Tsuzura::EditStackRenderer.new(self).call
  rescue StandardError => e
    Rails.logger.warn("Tsuzura web variant failed for #{id}: #{e.message}")
  end

  def generate_web_variant_later
    GenerateWebVariantJob.perform_later(id)
  end
end
