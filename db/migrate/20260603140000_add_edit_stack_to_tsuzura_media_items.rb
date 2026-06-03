# frozen_string_literal: true

class AddEditStackToTsuzuraMediaItems < ActiveRecord::Migration[8.1]
  def change
    add_column :tsuzura_media_items, :edit_stack, :jsonb, null: false, default: {}
  end
end
