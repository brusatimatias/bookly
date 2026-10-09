# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Bookly is a freshly generated Rails 8.1 app (no domain models, routes, or migrations yet beyond the Rails defaults). Expect to be creating the first models/controllers rather than modifying existing ones.

## Commands

```bash
bin/setup                      # install gems, prepare DB, start server (--skip-server to skip)
bin/dev                        # run web (port 3000) + Tailwind watcher via foreman (Procfile.dev)
bin/rails db:prepare           # create/migrate the PostgreSQL DB

bundle exec rspec                              # full test suite
bundle exec rspec spec/models/foo_spec.rb      # single file
bundle exec rspec spec/models/foo_spec.rb:42   # single example by line

bin/rubocop                    # lint (rubocop-rails-omakase); -a to autocorrect
bin/brakeman                   # security static analysis
bin/bundler-audit              # gem vulnerability audit
bin/importmap audit            # JS dependency audit
bin/ci                         # local CI pipeline defined in config/ci.rb
```

`bin/ci` (config/ci.rb) mirrors the GitHub workflow (.github/workflows/ci.yml): RuboCop, bundler-audit, importmap audit, Brakeman, and RSpec. The GitHub `test` job runs against a Postgres service via `DATABASE_URL`.

## Stack / architecture

- **Database:** PostgreSQL (`bookly_development` / `bookly_test`, local socket, OS user). In production, Solid Cache/Queue/Cable each use a separate database (`bookly_production_cache`, `_queue`, `_cable`) with their own schemas in `db/*_schema.rb` and migration paths `db/{cache,queue,cable}_migrate`.
- **Background jobs, cache, websockets:** Solid Queue, Solid Cache, Solid Cable (DB-backed; no Redis).
- **Frontend:** Hotwire (Turbo + Stimulus) via importmap — no Node/bundler. Stimulus controllers in `app/javascript/controllers` are auto-pinned. Add JS packages with `bin/importmap pin <pkg>`.
- **CSS:** Tailwind via `tailwindcss-rails`; source is `app/assets/tailwind/application.css`, compiled to `app/assets/builds/` (gitignored). Assets served by Propshaft.
- **Testing:** RSpec (`spec/`) with FactoryBot; Minitest railtie is disabled and system test generation is turned off. Transactional fixtures are on. `FactoryBot::Syntax::Methods` is included (call `create`/`build` directly). Specs run in random order; `spec/examples.txt` persists status for `--only-failures`.
- **Deployment:** Kamal (`config/deploy.yml`, `.kamal/secrets`) building the `Dockerfile`, served through Thruster. `RAILS_MASTER_KEY` is read from `config/master.key` (gitignored); production DB password comes from `BOOKLY_DATABASE_PASSWORD`.
