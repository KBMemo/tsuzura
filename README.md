# Tsuzura（葛籠）— KBMemo メディア API

`https://media.kbmemo.net` で動作する Rails 8 アプリ（REST API + 最小 Web UI）。

* **Phase 1（完了）:** CLI バッチ登録 + KBMemo 連携（`album::` / `image::media:`）
* **Phase 2（完了）:** Web UI + メモ編集ピッカー連携 — [kbmemo_site/docs/architecture/tsuzura-phase2.adoc](../site/docs/architecture/tsuzura-phase2.adoc)

設計: [media-platform.adoc](../site/docs/architecture/media-platform.adoc)

## Web UI（Phase 2）

ログイン済み（KBMemo と同一 `_kbmemo_session`、本番は `domain: .kbmemo.net`）で:

* `/` — アルバム一覧
* `/albums/:id` — 詳細・複数ファイル upload（`POST /v1/media/batch` と同処理）
* `/albums/new` — アルバム作成

未ログイン時は `KBMEMO_LOGIN_URL`（既定 `http://localhost:3000/login`）へリダイレクト。

## 開発

KBMemo と credentials / DB を共有します（`config/master.key` → `../../site/config/master.key`）。

```bash
cd kbmemo-media
bundle install
npm install
bin/rails db:migrate
```

Vite 開発サーバー込みで起動する場合:

```bash
PORT=3008 bin/dev
```

`bin/dev` は Rails（既定 `http://localhost:3008`）と Vite（`config/vite.json` の development port、既定 `3046`）を同時に起動します。画像編集 UI などのフロントエンド変更を触るときはこちらを使います。

Rails だけを起動する場合:

```bash
PORT=3008 bin/rails server
```

production 相当のビルド確認:

```bash
npm run build
```

`.env` 例: `.env.example`（`KBMEMO_LOGIN_URL` / `KBMEMO_HOME_URL` / `TSUZURA_CORS_ORIGINS`）

## 本番（systemd）

`start.sh` が rbenv / `.env.production` を読み込んでから Puma を起動します（既定 `PORT=3008`）。

```bash
cp .env.example .env.production   # RAILS_MASTER_KEY 等を編集
chmod 750 start.sh
```

`/etc/systemd/system/tsuzura.service` の例:

```ini
[Unit]
Description=Tsuzura (media.kbmemo.net)
After=network.target

[Service]
Type=simple
User=kensei
Group=kensei
WorkingDirectory=/home/kensei/sites/kbmemo-media
ExecStart=/home/kensei/sites/kbmemo-media/start.sh
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tsuzura
curl -fsS http://127.0.0.1:3008/up
```

## 更新デプロイ（本番）

`bin/deploy` で pull・`bundle install`・`npm ci`・`npm run build`・**`db:migrate`**（`tsuzura_*` テーブル等）・`tsuzura` ユニット再起動・ヘルスチェックを一括実行します。

```bash
cd /home/kensei/sites/kbmemo-media
bin/deploy
bin/deploy --branch main
```

詳細: [kbmemo_site/docs/deployment/production.adoc](../site/docs/deployment/production.adoc) の Tsuzura 節。

## テスト

KBMemo と **同一 PostgreSQL test DB**（credentials 共有）を使います。

```bash
bin/rails db:test:prepare
bin/rails test
# または
bin/ci
```

## CLI

```bash
export TSUZURA_BASE_URL=http://localhost:3008
export TSUZURA_API_TOKEN=tsuzura_…   # KBMemo プロフィールで発行

bin/tsuzura import --album "2024 夏" ./photos/
bin/tsuzura import --auto-date-albums -a "Trip 2026" ~/Dropbox/Camera\ Upload/  # manifest にオプション保存
bin/tsuzura import ~/Dropbox/Camera\ Upload/   # 2 回目以降はディレクトリだけで同設定
bin/tsuzura sync-albums ~/Dropbox/Camera\ Upload/   # 登録済み写真の振り分け直し
bin/tsuzura watch run --auto-date-albums ~/Dropbox/Camera\ Upload/
bin/tsuzura manifest show ~/Dropbox/Camera\ Upload/
bin/tsuzura albums list
bin/tsuzura media show 01JH…
```

## API

| Method | Path | 用途 |
|--------|------|------|
| POST | `/v1/media/batch` | 一括アップロード（checksum 重複は再利用、`album_ids[]`、`auto_date_albums` でインボックス+日付アルバム） |
| GET | `/v1/media/lookup?checksum=` | オーナー内の既存メディア照会（watch 取り込み用） |
| GET | `/v1/media/:id` | メタデータ |
| GET | `/v1/media/:id/web` | 署名付き画像配信 |
| GET/POST | `/v1/albums` | アルバム一覧・作成 |
| GET | `/internal/albums` | KBMemo サーバー向け一覧（`owner_account_id` + internal secret） |
| GET | `/internal/albums/:id` | KBMemo サーバー向け詳細（`X-Kbmemo-Internal-Secret`） |

認証: Rodauth セッション Cookie（`_kbmemo_session`）または `Authorization: Bearer tsuzura_…`

CORS: `/v1/*` に `TSUZURA_CORS_ORIGINS`（既定: kbmemo.net + `localhost:3000`）。メモピッカーは KBMemo の `/internal/tsuzura/*` 経由が主。
