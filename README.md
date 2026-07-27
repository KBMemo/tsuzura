# Tsuzura（葛籠）— KBMemo メディア API

`https://media.kbmemo.net` で動作する Rails 8 アプリ（REST API + 最小 Web UI）。

License: [MIT](LICENSE)

* **Phase 1（完了）:** CLI バッチ登録 + KBMemo 連携（`album::` / `image::media:`）
* **Phase 2（完了）:** Web UI + メモ編集ピッカー連携 — [KBMemoのTsuzura Phase 2設計](https://github.com/KBMemo/kbmemo/blob/main/docs/architecture/tsuzura-phase2.adoc)

設計: [media-platform.adoc](https://github.com/KBMemo/kbmemo/blob/main/docs/architecture/media-platform.adoc)

## Web UI（Phase 2）

ログイン済み（KBMemo と同一 `_kbmemo_session`、本番は `domain: .kbmemo.net`）で:

* `/` — アルバム一覧
* `/media/dates` — 登録済み写真の全件日付別表示
* `/albums/:id` — 詳細・複数ファイル upload（`POST /v1/media/batch` と同処理）
* `/albums/new` — アルバム作成

未ログイン時は `KBMEMO_LOGIN_URL`（既定 `http://localhost:3000/login`）へリダイレクト。

## 開発

KBMemo と同じcredentials内容とDBを使用します。開発環境ごとに共通の
`RAILS_MASTER_KEY`を安全に設定するか、追跡対象外の`config/master.key`を配置してください。

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

### 環境変数（開発）

`bin/dev` と `bin/rails server` は **`.env` を読み込みません**。シェルに既にある環境変数をそのまま引き継ぎ、`PORT` だけ未設定時は `3008` を使います（本番の `start.sh` → `scripts/production_env.sh` が `.env.production` を読むのとは別）。

任意の開発用オーバーライドは、起動前に export するか一時的に source してください。

```bash
# 例: ローカル用 .env を手動で読み込んでから起動
set -a && source .env.development && set +a && bin/dev

# 例: 個別指定
KBMEMO_LOGIN_URL=http://localhost:3000/login PORT=3008 bin/dev
```

| 変数 | 開発時の既定（未設定時） | 備考 |
|------|-------------------------|------|
| `PORT` | `3008` | `bin/dev` が設定 |
| `KBMEMO_LOGIN_URL` | `http://localhost:3000/login` | Web UI 未ログイン時のリダイレクト先 |
| `KBMEMO_HOME_URL` | `http://localhost:3000` | ナビの KBMemo リンク |
| `TSUZURA_PUBLIC_URL` | `http://localhost:3008` | 署名付き URL のベース |
| `TSUZURA_CORS_ORIGINS` | kbmemo.net + `localhost:3000` | `/v1/*` の CORS |
| `KBMEMO_TSUZURA_INTERNAL_SECRET` | credentials `tsuzura.internal_secret` | KBMemo ↔ `/internal/*`。ENV がなくても credentials があれば可 |
| `TSUZURA_URL_SIGNING_SECRET` | credentials → `secret_key_base` | 署名付き画像 URL 用 |

DB 接続・`RAILS_MASTER_KEY` は KBMemo と共有の **credentials**（`config/master.key`）です。`.env` ファイルの雛形は `.env.example`（本番は `.env.production` にコピー）を参照。

### 認証トークン（開発）

用途ごとに次のとおりです。

| 用途 | 開発時の設定 |
|------|-------------|
| **Web UI**（`bin/dev`） | 不要。KBMemo ログイン後の `_kbmemo_session` Cookie |
| **KBMemo 連携**（`/internal/*`） | 不要（上表どおり credentials の internal secret） |
| **CLI / REST API**（`bin/tsuzura`、`curl` 等） | `TSUZURA_API_TOKEN` をシェルに export。KBMemo プロフィールで「Tsuzura CLI トークンを発行」 |

Bearer トークン（`tsuzura_…`）は **アカウントごとに DB にダイジェスト保存**され、平文は発行時に一度だけ表示されます。`.env` や `bin/dev` では自動設定されないため、CLI を使うときは保存済みの値を export するか、プロフィールで再発行してください（再発行すると旧トークンは無効）。

## 本番（systemd）

`start.sh` が rbenv / `.env.production` を読み込んでから Puma を起動します（既定 `PORT=3008`）。

```bash
cp .env.example .env.production   # RAILS_MASTER_KEY 等を編集
chmod 750 start.sh
```

`~/.config/systemd/user/kbmemo-media.service` の例:

```ini
[Unit]
Description=Tsuzura (media.kbmemo.net)
After=network.target

[Service]
Type=simple
WorkingDirectory=/srv/kbmemo/tsuzura
ExecStart=/srv/kbmemo/tsuzura/start.sh
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now kbmemo-media
systemctl --user status kbmemo-media
curl -fsS http://127.0.0.1:3008/up
```

## 更新デプロイ（本番）

`bin/deploy` で pull・`bundle install`・`npm ci`・`npm run build`・**`db:migrate`**（`tsuzura_*` テーブル等）・`kbmemo-media` user service 再起動・ヘルスチェックを一括実行します。再起動後は既定で3秒待機し、`TSUZURA_HEALTH_CHECK_DELAY` で変更できます。

```bash
cd /srv/kbmemo/tsuzura
bin/deploy
bin/deploy --branch main
```

詳細: [KBMemo production guide](https://github.com/KBMemo/kbmemo/blob/main/docs/deployment/production.adoc) のTsuzura節。

## テスト

KBMemo と **同一 PostgreSQL test DB**（credentials 共有）を使います。

```bash
bin/rails db:test:prepare
bin/rails test
# または
bin/ci
```

## メディアメタデータ再取得

既存画像の撮影日時・位置情報・寸法などを、Active Storage の元画像 BLOB から再抽出して `tsuzura_media_items` を更新します。

```bash
# 全画像を元画像 BLOB から再読み込み
bin/rails tsuzura:metadata:refresh_from_blobs

# 欠落している項目がある画像だけ更新
bin/rails tsuzura:metadata:refresh_from_blobs MISSING_ONLY=1

# 特定 ID のみ
bin/rails tsuzura:metadata:refresh_from_blobs IDS=01J...,01K...

# 対象件数の確認
bin/rails tsuzura:metadata:refresh_from_blobs MISSING_ONLY=1 DRY_RUN=1

# 既存名も同じ処理
bin/rails tsuzura:metadata:backfill
```

`refresh_from_blobs` は EXIF 撮影日時・GPS・寸法を元画像 BLOB から読み直します。BLOB を一時ファイルとして開く都合上、一時ファイルの mtime は採用しません。EXIF 撮影日時がない画像の日付 fallback は BLOB 登録日時です。

GPS が元画像に含まれない場合、位置情報は空のままです。そのため `MISSING_ONLY=1` では GPS のない画像が再度対象に残ることがあります。

## CLI

CLI は Rodauth セッションではなく **Bearer トークン**のみ受け付けます。トークンは KBMemo のプロフィール画面で発行し、シェルに export します（`bin/dev` は読み込みません）。

```bash
export TSUZURA_BASE_URL=http://localhost:3008   # 未設定時もこの URL が既定
export TSUZURA_API_TOKEN=tsuzura_…              # プロフィールで発行した平文（再表示不可）

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
| GET | `/v1/media/:id/file` | Bearer 認証で画像バイナリ配信（`?source=original` で原画） |
| GET | `/v1/media/:id/web` | 署名付き画像配信 |
| GET/POST | `/v1/albums` | アルバム一覧・作成 |
| GET | `/internal/albums` | KBMemo サーバー向け一覧（`owner_account_id` + internal secret） |
| GET | `/internal/albums/:id` | KBMemo サーバー向け詳細（`X-Kbmemo-Internal-Secret`） |

認証:

* `/v1/*`（Web 除く）: Rodauth セッション Cookie（`_kbmemo_session`）または `Authorization: Bearer tsuzura_…`（CLI トークンはプロフィール発行 → `TSUZURA_API_TOKEN`）
* `/internal/*`: `X-Kbmemo-Internal-Secret`（ENV または credentials `tsuzura.internal_secret`）

CORS: `/v1/*` に `TSUZURA_CORS_ORIGINS`（既定: kbmemo.net + `localhost:3000`）。メモピッカーは KBMemo の `/internal/tsuzura/*` 経由が主。
