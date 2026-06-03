# frozen_string_literal: true

class AddCaptureMetadataToTsuzuraMediaItems < ActiveRecord::Migration[8.1]
  def change
    change_table :tsuzura_media_items, bulk: true do |t|
      t.datetime :file_mtime
      t.datetime :exif_captured_at
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
    end
  end
end
