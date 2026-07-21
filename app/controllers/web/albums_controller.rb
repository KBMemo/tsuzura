# frozen_string_literal: true

module Web
  class AlbumsController < BaseController
    def index
      @albums = Album.where(owner_account_id: current_account.id).order(created_at: :desc)
    end

    def show
      @album = find_owned_album!
      @items = @album.album_items
        .order(:position)
        .includes(media_item: [ { file_attachment: :blob }, { web_attachment: :blob } ])
        .map(&:media_item)
    end

    def new
      @album = Album.new
    end

    def create
      album = Album.create!(
        owner_account_id: current_account.id,
        title: params.require(:title).strip,
        description: params[:description].presence
      )
      redirect_to web_album_path(album), notice: "アルバムを作成しました。"
    end

    def upload
      album = find_owned_album!
      uploads = Array(params[:files]).compact
      if uploads.empty?
        redirect_to web_album_path(album), alert: "ファイルを選択してください。"
        return
      end

      Tsuzura::BatchImport.new(
        account: current_account,
        album_id: album.id
      ).call(uploads: uploads)

      redirect_to web_album_path(album), notice: "#{uploads.size} 件を追加しました。"
    rescue ActiveRecord::RecordNotFound
      redirect_to web_albums_path, alert: "アルバムが見つかりません。"
    end

    private

    def find_owned_album!
      album = Album.find_by_ulid(params[:id])
      raise ActiveRecord::RecordNotFound unless album
      raise ActiveRecord::RecordNotFound unless album.owner_account_id == current_account.id

      album
    end
  end
end
