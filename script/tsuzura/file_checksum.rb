# frozen_string_literal: true

require "digest"

module TsuzuraCLI
  # Active Storage blob.checksum と同じ MD5 base64。
  module FileChecksum
    module_function

    def from_path(path)
      File.open(path, "rb") { |io| from_io(io) }
    end

    def from_io(io)
      digest = Digest::MD5.new
      while (chunk = io.read(64 * 1024))
        digest.update(chunk)
      end
      digest.base64digest
    end
  end
end
