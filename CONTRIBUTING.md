# Contributing to Tsuzura

Keep changes focused, covered by relevant tests, and explicit about API or media-storage
effects.

## Before you start

Read [AGENTS.md](AGENTS.md) for application boundaries and local conventions. Use an issue
or discussion before changing authentication, public API contracts, Active Storage behavior,
media ownership rules, or the shared KBMemo database contract.

For local development:

```bash
bundle install
npm install
bin/rails db:prepare
bin/dev
```

Tsuzura shares database credentials and session behavior with KBMemo. Keep credentials,
Bearer tokens, internal secrets, URL-signing secrets, and production media outside Git.

## Validation

Run the narrowest checks relevant to the change, then run the full suite before opening a
pull request when practical.

```bash
bin/rails test test/path/to/test.rb
npm run build
bin/rubocop
bin/ci
```

Changes to upload, metadata, signing URLs, owner isolation, or internal authentication need
both controller and service coverage. Verify image-editing changes in a browser as well as in
automated tests.

## Pull requests

Describe user-visible behavior, validation run, API or migration effects, and follow-up work.
Update documentation when changing public endpoints, configuration, deployment, or the CLI.
Do not include generated media, credentials, private environment details, or unrelated
formatting changes.

## Security reports

Do not open public issues for suspected vulnerabilities. Follow [SECURITY.md](SECURITY.md)
instead.
