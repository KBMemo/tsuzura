# frozen_string_literal: true

class CreateTsuzuraAlbumItems < ActiveRecord::Migration[8.1]
  def change
    create_table :tsuzura_album_items, id: :bigint do |t|
      t.string :album_id, limit: 26, null: false
      t.string :media_item_id, limit: 26, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :tsuzura_album_items, [ :album_id, :position ]
    add_index :tsuzura_album_items, [ :album_id, :media_item_id ], unique: true
    add_foreign_key :tsuzura_album_items, :tsuzura_albums, column: :album_id, primary_key: :id
    add_foreign_key :tsuzura_album_items, :tsuzura_media_items, column: :media_item_id, primary_key: :id
  end
end
