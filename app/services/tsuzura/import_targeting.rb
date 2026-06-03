# frozen_string_literal: true

module Tsuzura
  # バッチ取り込み・既存メディア同期で共有するアルバムリンク先の解決。
  class ImportTargeting
    attr_reader :account, :auto_date_albums

    def initialize(
      account:,
      album_title: nil,
      album_id: nil,
      album_ids: nil,
      auto_date_albums: false,
      inbox_album_title: nil,
      date_album_format: nil
    )
      @account = account
      @album_title = album_title.to_s.strip.presence
      @album_id = Album.normalize_ulid(album_id)
      @album_ids = normalize_album_ids(album_ids)
      @auto_date_albums = ActiveModel::Type::Boolean.new.cast(auto_date_albums)
      @date_album_format = date_album_format.to_s.strip.presence || DateAlbumResolver::DEFAULT_DATE_FORMAT
      @date_resolver = if @auto_date_albums
        DateAlbumResolver.new(
          account: account,
          inbox_album_title: inbox_album_title,
          date_album_format: date_album_format
        )
      end
    end

    def albums_for_item(item)
      albums = []
      albums.concat(resolve_explicit_albums!) if explicit_album_ids?
      albums << find_or_create_titled_album! if @album_title.present?

      if @auto_date_albums
        albums.concat(@date_resolver.albums_for_item(item))
      elsif albums.empty?
        albums << default_import_album!
      end

      albums.uniq
    end

    def date_album_format
      @date_album_format
    end

    private

    def normalize_album_ids(raw)
      list = Array(raw).flat_map { |entry| entry.to_s.split(",") }
      ids = list.map { |id| Album.normalize_ulid(id) }.compact
      ids << @album_id if @album_id.present?
      ids.uniq
    end

    def explicit_album_ids?
      @album_ids.any?
    end

    def resolve_explicit_albums!
      @album_ids.map { |id| find_owned_album!(id) }
    end

    def find_or_create_titled_album!
      @titled_album ||= Album.find_or_create_by!(owner_account_id: @account.id, title: @album_title)
    end

    def default_import_album!
      @default_import_album ||= Album.create!(
        owner_account_id: @account.id,
        title: "Import #{Time.current.strftime('%Y-%m-%d %H:%M')}"
      )
    end

    def find_owned_album!(ulid)
      album = Album.find_by_ulid(ulid)
      raise ActiveRecord::RecordNotFound, "album not found" unless album
      raise ActiveRecord::RecordNotFound, "album forbidden" unless album.owner_account_id == @account.id

      album
    end
  end
end
