# frozen_string_literal: true

class MediaItem < ApplicationRecord
  include UlidRecord

  self.table_name = "tsuzura_media_items"

  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/heic image/heif].freeze

  belongs_to :owner, class_name: "Account", foreign_key: :owner_account_id

  has_one_attached :file
  has_one_attached :web

  validates :kind, inclusion: { in: %w[image video] }

  def attach_upload!(uploaded_file)
    assign_ulid if id.blank?
    file.attach(uploaded_file)
    self.original_filename = uploaded_file.original_filename
    self.checksum = file.blob&.checksum
    save!
  end

  def generate_web_variant!
    return unless file.attached? && file.content_type.in?(IMAGE_CONTENT_TYPES)

    web.attach(
      io: StringIO.new(file.download),
      filename: "web-#{id}.jpg",
      content_type: "image/jpeg"
    )
  rescue StandardError => e
    Rails.logger.warn("Tsuzura web variant failed for #{id}: #{e.message}")
  end

  def generate_web_variant_later
    GenerateWebVariantJob.perform_later(id)
  end
end
