# frozen_string_literal: true

# MediaItem の ULID 主キーに合わせ、Active Storage の record_id を string にする。
class ChangeActiveStorageAttachmentsRecordIdToString < ActiveRecord::Migration[8.1]
  def up
    change_column :active_storage_attachments, :record_id, :string
  end

  def down
    change_column :active_storage_attachments, :record_id, :bigint, using: "record_id::bigint"
  end
end
