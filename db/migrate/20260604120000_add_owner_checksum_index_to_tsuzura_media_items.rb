# frozen_string_literal: true

class AddOwnerChecksumIndexToTsuzuraMediaItems < ActiveRecord::Migration[8.1]
  def change
    add_index :tsuzura_media_items,
      %i[owner_account_id checksum],
      name: "index_tsuzura_media_items_on_owner_account_id_and_checksum"
  end
end
