# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Multi-tenant appointment booking app, built in stages. Done so far:

- `Business` model (booking configuration, locale, time zone, active/suspended), tenant context (`Current.business`, `BusinessScoped`) and public business page at `/:business_slug`.
- Spanish/English i18n, with a language switcher on pages outside a business.
- A shared UI layer (Tailwind theme, component classes, partials and three layouts) used by every page; see "UI conventions".
- Users and authentication (Rails 8 generator), password reset, memberships with roles (`owner`/`admin`/`professional`), the business panel at `/:business_slug/admin`, and email invitations to join a business.

No per-business tables yet (the first ones arrive with services and professionals). There is no public sign up: owners are created from seeds or the console for now, everyone else joins by invitation.

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

Seeds (`bin/rails db:seed`) create two businesses with members; every seeded user's password is `password`. In development, sent emails are browsable at `/letter_opener`.

`bin/ci` (config/ci.rb) mirrors the GitHub workflow (.github/workflows/ci.yml): RuboCop, bundler-audit, importmap audit, Brakeman, and RSpec. The GitHub `test` job runs against a Postgres service via `DATABASE_URL`.

## Stack / architecture

- **Database:** PostgreSQL (`bookly_development` / `bookly_test`, local socket, OS user). In production, Solid Cache/Queue/Cable each use a separate database (`bookly_production_cache`, `_queue`, `_cable`) with their own schemas in `db/*_schema.rb` and migration paths `db/{cache,queue,cable}_migrate`.
- **Background jobs, cache, websockets:** Solid Queue, Solid Cache, Solid Cable (DB-backed; no Redis).
- **Frontend:** Hotwire (Turbo + Stimulus) via importmap — no Node/bundler. Stimulus controllers in `app/javascript/controllers` are auto-pinned. Add JS packages with `bin/importmap pin <pkg>`.
- **CSS:** Tailwind 4 via `tailwindcss-rails`; source is `app/assets/tailwind/application.css`, compiled to `app/assets/builds/` (gitignored). Only classes found in views/helpers end up in the build, so keep `bin/dev` running (or `bin/rails tailwindcss:build`) after adding classes. Assets served by Propshaft.
- **Testing:** RSpec (`spec/`) with FactoryBot; Minitest railtie is disabled and system test generation is turned off. Transactional fixtures are on. `FactoryBot::Syntax::Methods` is included (call `create`/`build` directly). Specs run in random order; `spec/examples.txt` persists status for `--only-failures`. Spec type is declared explicitly (`type: :request`, `type: :controller`); it is not inferred from the folder. `ActiveSupport::Testing::TimeHelpers` (`freeze_time`, `travel_to`) is included, and `spec/support/**` is auto-loaded. Request specs sign in with `sign_in_as(user)` (password `"password"`, the factory default).
- **i18n:** `es` (default) and `en`. Translations live in `config/locales/{es,en}/` — `app.yml`, `models/<model>.yml`, `views/<controller>.yml` (namespaced controllers in `views/admin/`), `mailers/<mailer>.yml` — and every user-facing string (views, mailers, validation messages, flash) goes through `t()`. Missing translations raise in development and test, and `spec/config/i18n_spec.rb` fails if `es` and `en` don't define the same keys. Enum values are translated as attributes (`membership/role`) and read with `Model.human_attribute_name("role.#{value}")`.
- **Locale selection:** pages tied to a business (public page, panel, invitation) use the business's locale. Everywhere else `SetLocale` picks the language switcher's choice (`locale` cookie, set by `PATCH /locale`), then the browser's `Accept-Language`, then `es`. The switcher shows where `locale_switchable?` is true. Emails about a business are rendered in its locale (`I18n.with_locale(business.locale)` in the mailer).
- **Deployment:** Kamal (`config/deploy.yml`, `.kamal/secrets`) building the `Dockerfile`, served through Thruster. `RAILS_MASTER_KEY` is read from `config/master.key` (gitignored); production DB password comes from `BOOKLY_DATABASE_PASSWORD`.

## UI conventions

Every page is built from the shared pieces below; don't hand-roll styles that already exist, and don't ship bare pages (use cards, page headers and empty states).

- **Theme** (`@theme` in `app/assets/tailwind/application.css`): `brand-50…900` (indigo) for anything branded, Inter as `font-sans`, `shadow-card`. Use `brand-*`, not raw `indigo-*`, so the theme changes in one place. Light gray page background, white cards.
- **Component classes** (declared with `@utility`, so they compose and take variants like `sm:`):
  - Buttons: `btn-primary`, `btn-secondary`, `btn-danger`, `btn-ghost`; modifiers `btn-sm`, `btn-block`. Destructive inline actions: `btn-ghost btn-sm text-red-600 hover:bg-red-50`.
  - Forms: wrap each field in `.field`, with `.label`, `.input` (also for `select`) and `.hint`. Forms sit in a `card card-body space-y-5`; actions go right-aligned at the bottom.
  - Containers: `card`, `card-body`, `list-divided` (rows inside a card use `px-6 py-4`).
  - Status and roles: `badge-gray`, `badge-brand`, `badge-green`, `badge-yellow`, `badge-red`.
  - `link` for inline links, `avatar` for initials circles (`initials(name)`).
- **Partials** (`app/views/shared/`): `page_header` (title, subtitle, `actions:`), `form_errors` (`record:`), `empty_state` (`icon:`, `title:`, `message:`, `action:`), `flash` and `locale_switcher` (rendered by the layouts). Build `actions:`/`action:` with `capture { ... }` in the calling view: a block yielded inside a partial would resolve lazy `t(".key")` lookups against the partial.
- **Icons:** `icon("users", class: "size-4")` renders inline Heroicons (outline) from `IconsHelper::ICONS`; add new icons there.
- **Layouts:** `application` (public header + footer: landing, business pages, business list), `auth` (centered card: sign in, password reset, invitation; set with `layout "auth"`), `admin` (sidebar panel, collapsible on mobile via the `sidebar` Stimulus controller). Add panel sections with `admin_nav_link(label, path, icon:, active:)` in `layouts/admin.html.erb`; translations for layouts live in `views/layouts.yml`.
- **Prices and durations:** `format_price(cents)` (business currency, locale format, decimals only when there are cents) and `format_duration(minutes)` from `FormattingHelper`. Forms take prices in the main unit through a virtual attribute (`Service#price=`) and store cents.
- **Rich text:** `form.rich_textarea :field, class: "input min-h-32"`. File uploads are disabled in the editor (`trix-file-accept` in `application.js`); Trix overrides that must beat `actiontext.css` go unlayered.
- **Emails:** the `mailer` layout and `email_button(label, url)` (`MailerHelper`) use inline styles only.
- Check new screens at phone width too.

## Authentication and roles

- Users, sessions and password reset come from the Rails 8 authentication generator (`Authentication` concern, `Current.session`/`Current.user`). Sign in at `/session/new`.
- Authentication is required **by default** for every controller; public ones opt out with `allow_unauthenticated_access`.
- `users`, `sessions`, `memberships` and `invitations` are global tables (not `BusinessScoped`). Always reach invitations and memberships through `Current.business` (`Current.business.invitations.find(...)`) so a request can't touch another business's records.
- `Membership` links a user to a business with a role: `owner` (exactly one per business, enforced by a partial unique index), `admin` or `professional`. One role per user and business. `manager?` is true for owners and admins.
- After signing in, users land on `/dashboard`: straight into their business panel if they belong to a single one, otherwise a list to pick.

### Business panel

- Lives under `/:business_slug/admin` (`namespace :admin` inside the business scope). Controllers inherit from `Admin::BaseController`, which includes `SetCurrentBusiness`, uses the `admin` layout and sets `Current.membership`. Non-members get a 404; suspended businesses get the 503 page.
- Restrict actions with `before_action :require_owner` or `:require_manager`; users without the role are redirected to the panel home with an alert.
- Route helpers inside the panel fill `business_slug` automatically (`default_url_options`).

### Invitations

- Only the owner invites, resends and revokes (`Admin::InvitationsController`); owners and admins see the team page. Invitations are for `admin` or `professional` and expire after `Invitation::VALID_FOR` (7 days). One pending invitation per email and business.
- The acceptance token is not stored: `generates_token_for :acceptance` embeds `accepted_at` and `expires_at`, so the link is single use, resending (`renew!`) voids the previous link, and revoking deletes the record.
- `/invitations/:token` (`InvitationsController`, in the business's locale): without an account the person signs up there (user and membership in one transaction); with an account they must be signed in as the invited email. `Invitation#accept!` locks the row and raises `Invitation::NotAcceptable` if it was used, expired or the email doesn't match.

## Multi-tenancy

Single database, shared tables: every per-business table has a `business_id`, and the current tenant lives in `Current.business`.

- Per-business models `include BusinessScoped`. It adds `belongs_to :business` (read-only after create), filters every query by `Current.business` and assigns it to new records.
- It **fails closed**: with no current business, any query or `new` raises `Current::MissingBusiness`. This also applies through associations (`business.services` still needs `Current.business`).
- Anything outside a request — console, seeds, jobs, rake tasks, specs — must set the tenant explicitly: `Current.set(business: business) { ... }`. In specs use the `with_business(business) { ... }` helper (`spec/support/current_business_helpers.rb`).
- Code that legitimately spans tenants (platform admin, maintenance) opts out with `BusinessScoped.across_businesses { ... }`. Never use `unscoped` to bypass tenancy; keep cross-tenant access greppable.
- `Business` itself, and global tables (users, sessions, memberships, invitations), do not include `BusinessScoped`. `Current.membership` holds the signed in user's membership inside the business panel.

## Routing

- `/` is the landing page (`HomeController`). Global app routes (`/session`, `/passwords`, `/locale`, `/dashboard`, `/invitations`, `/letter_opener` in development) come before the business scope. Public business pages live under `scope ":business_slug"` at the end of `config/routes.rb`, constrained by `Business::SLUG_FORMAT`.
- Controllers under that scope `include SetCurrentBusiness`: it resolves the business from the slug (404 if unknown), sets `Current.business`, wraps the request in the business's locale and time zone, and renders `businesses/unavailable` (503, always with the public layout) for suspended businesses.
- Any new top-level path must be added to `Business::RESERVED_SLUGS` so no business can take it as a slug.
- Times are stored in UTC and displayed in the business time zone (`Time.zone` is the business's inside a request; the app default is UTC).
