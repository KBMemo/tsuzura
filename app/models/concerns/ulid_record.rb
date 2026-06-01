# frozen_string_literal: true

module UlidRecord
  extend ActiveSupport::Concern

  ULID_FORMAT = /\A[0-9A-HJKMNP-TV-Z]{26}\z/

  included do
    before_validation :assign_ulid, on: :create
    validates :id, presence: true, format: { with: ULID_FORMAT }
  end

  class_methods do
    def normalize_ulid(value)
      value.to_s.strip.upcase
    end

    def find_by_ulid(value)
      normalized = normalize_ulid(value)
      return nil if normalized.blank?

      find_by(id: normalized)
    end
  end

  def assign_ulid
    self.id = self.class.normalize_ulid(id).presence || ULID.generate.to_s
  end
end
