# Agent guide (kbmemo-media / Tsuzura)

このリポジトリでエージェント／コントリビュータが参照する実装方針です。Tsuzura（葛籠）は KBMemo の写真・画像を所有し、REST API、CLI、最小 Web UI を提供する Rails アプリです。

## 現在の構成

- Rails 8.1 / PostgreSQL / Active Storage / Rodauth
- asset build は Vite。画像編集 UI は Cropper.js
- View は ERB
- CSS は `app/frontend/styles/application.css` の通常 CSS。**Tailwind CSS は使用していない**
- ID は ULID、metadata 抽出は `image_processing` / EXIFR
- background job は Solid Queue
- KBMemo と DB credentials、session cookie、account ID の契約を共有する
- 本番は Puma + systemd user service `kbmemo-media`。デプロイ入口は `bin/deploy`

## 主なディレクトリ

- `app/controllers/web`: album / media の Web UI
- `app/controllers/api/v1`: CLI / REST API
- `app/controllers/internal`: KBMemo server 間 API
- `app/models/media_item.rb`: media metadata と Active Storage blob の所有
- `app/models/album.rb`, `album_item.rb`: album と所属関係
- `app/services/tsuzura`: import、checksum、metadata、album 割当、編集 stack、署名 URL
- `app/jobs`: web variant と非同期画像編集
- `app/frontend`: Vite entrypoint、画像編集 JavaScript、CSS
- `script/tsuzura_cli.rb`: CLI と watch / manifest 処理
- `lib/tasks/tsuzura_metadata.rake`: metadata 再抽出 task
- 詳細設計は隣接する `../site/docs/architecture/media-platform.adoc` と Tsuzura phase 文書を参照する

## Media と Storage

- 原画像の正は Active Storage blob。派生画像や編集結果から原画像 metadata を推測しない。
- checksum 重複、owner account、album membership の既存 service 境界を通して登録する。controller に import 手順を複製しない。
- metadata は `Tsuzura::MediaMetadata`、既存 blob の再抽出は `MediaMetadataBackfill` と rake task を使う。
- EXIF 撮影日時がない場合の fallback は blob 登録日時。一時ファイルの mtime を採用しない。
- GPS が存在しない画像を欠損として無理に補完しない。
- URL は `Tsuzura::MediaUrlSigner` の署名契約を通す。storage path や内部 blob URL を API response に直接露出しない。
- 編集操作は edit stack と renderer に集約し、元 blob を破壊的に上書きしない。

## 認証と API 境界

- Web UI は KBMemo と共有する Rodauth session cookie（本番 `_kbmemo_session`, domain `.kbmemo.net`）。
- `/v1/*` は用途に応じて session または `Authorization: Bearer tsuzura_...` を使う。
- `/internal/*` は `X-Kbmemo-Internal-Secret`。一般 client 用 token と混用しない。
- すべての media / album query は認証済み account の所有範囲に限定する。外部から渡された account ID だけを信頼しない。
- CORS は `TSUZURA_CORS_ORIGINS` の allowlist に限定する。
- CLI token、internal secret、URL signing secret、Rails master key を log、fixture、commit に残さない。

## CSS と JavaScript

- Tailwind の runtime、compiler、設定ファイルはない。既存 CSS class と変数を確認して通常 CSS として追加する。
- 画像 crop / rotate などは `app/frontend/media_edit.js` と server-side edit stack の契約を保つ。
- client preview と保存後の生成画像は同じ操作順になることを確認する。
- upload、編集、job 実行中の状態を画面だけで完了扱いにせず、server response / persisted state を正とする。

## KBMemo・CLI 連携

- KBMemo から保存する本文は `album::` / `image::media:` 参照であり、画像本体を KBMemo repository に複製しない。
- internal API の response 変更は kbmemo_site の picker / proxy と同時に確認する。
- CLI は `bin/tsuzura`、実装は `script/tsuzura_cli.rb`。import、watch、manifest、album sync の共通処理を command ごとに再実装しない。
- development の既定 URL は `http://localhost:3008`。`bin/dev` は Rails と Vite を起動するが `.env` を自動読込しない。

## テストと検証

- DB 準備: `bin/rails db:test:prepare`
- Rails test: `bin/rails test`
- 対象 test: `bin/rails test test/path/to/test.rb`
- frontend build: `npm run build`
- Ruby style: `bin/rubocop`
- 全体確認: `bin/ci`

upload、metadata、署名 URL、owner 分離、internal 認証を変更した場合は controller test と service test の両方を確認する。画像編集の見た目や操作を変更した場合は実ブラウザでも確認する。

## Migration とデプロイ

- KBMemo と同じ PostgreSQL database を使うため、table 名と migration の影響範囲を確認する。Tsuzura 所有 table を KBMemo 側から直接更新しない。
- data migration は既存 media 数と blob I/O を考慮し、大量処理を migration transaction に不用意に含めない。
- `bin/deploy` は npm build、DB migration、systemd user service `kbmemo-media` restart、startup delay、health check を行う。
- service 操作は `systemctl --user` を正とする。README に残る system service の例より、現行 `bin/deploy` と `scripts/production_env.sh` の契約を優先する。
- deploy script 変更時は `bin/deploy --dry-run` と shell syntax を確認する。
