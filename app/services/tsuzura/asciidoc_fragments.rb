# frozen_string_literal: true

module Tsuzura
  class AsciidocFragments
    def self.for_batch(album:, items:)
      lines = [ "album::#{album.id}[]", "" ]
      items.each do |item|
        lines << "image::media:#{item.id}[]"
      end
      lines.join("\n")
    end
  end
end
