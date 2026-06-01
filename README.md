# Tsuzura（葛籠）— KBMemo メディア API

`https://media.kbmemo.net` で動作する Rails 8 API-only アプリ。Phase 1: CLI バッチ登録 + KBMemo 連携。

設計: [kbmemo_site/docs/architecture/media-platform.adoc](../site/docs/architecture/media-platform.adoc)

## 開発

```bash
# KBMemo と credentials / DB を共有（config/master.key → ../../site/config/master.key）
cd kbmemo-media
bundle install
bin/rails db:migrate
PORT=3008 bin/rails server
```

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
bin/tsuzura albums list
bin/tsuzura media show 01JH…
```

## API（Phase 1）

| Method | Path | 用途 |
|--------|------|------|
| POST | `/v1/media/batch` | 一括アップロード |
| GET | `/v1/media/:id` | メタデータ |
| GET | `/v1/media/:id/web` | 署名付き画像配信 |
| GET/POST | `/v1/albums` | アルバム一覧・作成 |
| GET | `/internal/albums/:id` | KBMemo サーバー向け（`X-Kbmemo-Internal-Secret`） |

認証: Rodauth セッション Cookie（`_kbmemo_session`）または `Authorization: Bearer tsuzura_…`
