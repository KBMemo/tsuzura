# frozen_string_literal: true

class CreateTsuzuraMediaItems < ActiveRecord::Migration[8.1]
  def change
    create_table :tsuzura_media_items, id: false do |t|
      t.string :id, limit: 26, null: false, primary_key: true
      t.bigint :owner_account_id, null: false
      t.string :kind, null: false, default: "image"
      t.string :checksum
      t.integer :width
      t.integer :height
      t.jsonb :exif, null: false, default: {}
      t.datetime :captured_at
      t.string :original_filename
      t.timestamps
    end

    add_index :tsuzura_media_items, :owner_account_id
    add_index :tsuzura_media_items, :checksum
  end
end
