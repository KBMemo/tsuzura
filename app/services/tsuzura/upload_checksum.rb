# frozen_string_literal: true

require "digest"

module Tsuzura
  # Active Storage blob.checksum と同じ MD5 base64（取り込み前の重複判定用）。
  class UploadChecksum
    class << self
      def from_upload(upload)
        io = upload_io(upload)
        return nil unless io

        from_io(io)
      ensure
        rewind_io(upload)
      end

      def from_io(io)
        digest = Digest::MD5.new
        while (chunk = io.read(64.kilobytes))
          digest.update(chunk)
        end
        digest.base64digest
      end

      private

      def upload_io(upload)
        return upload.tempfile if upload.respond_to?(:tempfile) && upload.tempfile
        return upload if upload.respond_to?(:read)

        nil
      end

      def rewind_io(upload)
        io = upload_io(upload)
        io.rewind if io.respond_to?(:rewind)
      rescue Errno::ESPIPE
        nil
      end
    end
  end
end
