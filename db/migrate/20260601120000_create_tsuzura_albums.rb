# frozen_string_literal: true

class CreateTsuzuraAlbums < ActiveRecord::Migration[8.1]
  def change
    create_table :tsuzura_albums, id: false do |t|
      t.string :id, limit: 26, null: false, primary_key: true
      t.bigint :owner_account_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :cover_media_id, limit: 26
      t.timestamps
    end

    add_index :tsuzura_albums, :owner_account_id
    add_index :tsuzura_albums, :cover_media_id
  end
end
