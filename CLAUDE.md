# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Multi-tenant appointment booking app, built in stages. Done so far:

- `Business` model (booking configuration, locale, time zone, active/suspended), tenant context (`Current.business`, `BusinessScoped`) and public business page at `/:business_slug`.
- Spanish/English i18n, with a language switcher on pages outside a business.
- A shared UI layer (Tailwind theme, component classes, partials and three layouts) used by every page; see "UI conventions".
- Users and authentication (Rails 8 generator), password reset, memberships with roles (`owner`/`admin`/`professional`), role changes and member removal, the business panel at `/:business_slug/admin`, and email invitations to join a business.
- Services and professionals (the first per-business tables), managed from the panel and listed on the public page; see "Services and professionals".
- Professionals' weekly working hours and time blocks (vacations, errands); see "Working hours and time blocks".
- Customers and appointments, availability calculation, booking settings and an availability preview in the panel; see "Appointments and availability".
- Public appointment requests: customers pick a service, professional and time and send a request, then see it through a personal link; see "Public booking".
- Request management and a live agenda in the panel: confirming, rejecting, reassigning, cancelling and attendance, expiration by a recurring job, and pages that refresh themselves when appointments change; see "Request management and live agenda".

There is no public sign up: owners are created from seeds or the console for now, everyone else joins by invitation.

## Commands

```bash
bin/setup                      # install gems, prepare DB, start server (--skip-server to skip)
bin/dev                        # run web (port 3000), jobs (bin/jobs) and the Tailwind watcher via foreman (Procfile.dev)
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

Seeds (`bin/rails db:seed`) create two businesses with members, services, hours and appointments (plus, in Barbería Centro, a request about to expire and an appointment to mark attendance whenever there are none); every seeded user's password is `password`. In development, sent emails are browsable at `/letter_opener`.

`bin/ci` (config/ci.rb) mirrors the GitHub workflow (.github/workflows/ci.yml): RuboCop, bundler-audit, importmap audit, Brakeman, and RSpec. The GitHub `test` job runs against a Postgres service via `DATABASE_URL`.

## Stack / architecture

- **Database:** PostgreSQL (`bookly_development` / `bookly_test`, local socket, OS user). In production, Solid Cache/Queue/Cable each use a separate database (`bookly_production_cache`, `_queue`, `_cable`) with their own schemas in `db/*_schema.rb` and migration paths `db/{cache,queue,cable}_migrate`. Development does the same for Solid Queue and Solid Cable (`bookly_development_queue`, `_cable`); the test environment uses a single database with the `:test` job and cable adapters.
- **Background jobs, cache, websockets:** Solid Queue, Solid Cache, Solid Cable (DB-backed; no Redis). Jobs run in `bin/jobs` (started by `bin/dev`); recurring ones are scheduled in `config/recurring.yml`. Solid Cable writes broadcasts from a background thread in batches, so a short-lived process (`bin/rails runner`) may exit before they're written; the web server and `bin/jobs` are fine.
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
- Only the owner changes roles and removes members (`Admin::MembershipsController`, from the team page). `Membership#change_role` switches between `admin` and `professional` (new professionals get a profile); nobody becomes or stops being the owner. `Membership#remove!` deletes the membership but keeps the user, and leaves their professional profile inactive and unlinked; the owner can't be removed (`Membership::NotRemovable`).
- After signing in, users land on `/dashboard`: straight into their business panel if they belong to a single one, otherwise a list to pick.

### Business panel

- Lives under `/:business_slug/admin` (`namespace :admin` inside the business scope). Controllers inherit from `Admin::BaseController`, which includes `SetCurrentBusiness`, uses the `admin` layout and sets `Current.membership`. Non-members get a 404; suspended businesses get the 503 page.
- Restrict actions with `before_action :require_owner` or `:require_manager`; users without the role are redirected to the panel home with an alert.
- Route helpers inside the panel fill `business_slug` automatically (`default_url_options`).

### Invitations

- Only the owner invites, resends and revokes (`Admin::InvitationsController`); owners and admins see the team page. Invitations are for `admin` or `professional` and expire after `Invitation::VALID_FOR` (7 days). One pending invitation per email and business.
- The acceptance token is not stored: `generates_token_for :acceptance` embeds `accepted_at` and `expires_at`, so the link is single use, resending (`renew!`) voids the previous link, and revoking deletes the record.
- An invitation can carry a `professional_id`: a profile without an account that the new member takes over on acceptance (invite button on the professionals page, owner only; one pending invitation per profile). Accepting a `professional` invitation without one creates a profile with the user's name. `accept!` sets `Current.business` itself, since `/invitations` is outside the business scope.
- `/invitations/:token` (`InvitationsController`, in the business's locale): without an account the person signs up there (user and membership in one transaction); with an account they must be signed in as the invited email. `Invitation#accept!` locks the row and raises `Invitation::NotAcceptable` if it was used, expired or the email doesn't match.

## Services and professionals

- `Service` (duration, price in cents, optional `buffer_minutes` that falls back to the business's, Action Text `description`), `Professional` (optional `user`, Active Storage `photo`) and the `ProfessionalService` join. All three are `BusinessScoped`.
- They are never deleted: `Deactivatable` adds `active`/`inactive` scopes and `deactivate!`/`reactivate!`. Inactive services keep their professionals.
- `bookable` (scope) and `bookable?`: active professionals offering an active service and with weekly hours, and active services offered by such a professional. The public page only lists bookable ones.
- A professional's `user` must be a member of the same business (validation plus a composite foreign key to `memberships`), and each member has at most one profile. While a profile is linked, the membership can't be deleted directly: `Membership#remove!` unlinks it first.
- Panel: `Admin::ServicesController` and `Admin::ProfessionalsController`. Every member sees the lists; owners and admins manage them (`require_manager`).
- Photos: JPG/PNG/WebP up to 5 MB, shown with `professional_avatar` (initials when there is none). No image variants yet (libvips isn't required), so images are cropped with CSS.

## Working hours and time blocks

- `WorkingHour`: weekly ranges per professional (`day_of_week` as `Date#wday`, 0 = Sunday; `start_time`/`end_time` as local `time`). A day can have several ranges; they don't cross midnight. `start_time`/`end_time` skip time zone conversion (`skip_time_zone_conversion_for_attributes`): they are wall clock times in the business's zone, not instants.
- `TimeBlock`: a period (`starts_at`/`ends_at`, UTC like every instant) in which a professional can't be booked, with an optional `reason`. Blocks are deleted, not deactivated, and can't be created or moved to a period that already ended. Whole days blocks (`all_day`, `start_date`, `end_date` virtual attributes) go from the first day's midnight to the midnight after the last one in `Time.zone` (a single day when `end_date` is empty); `whole_days?` recognizes them.
- Overlaps are rejected by validations and by exclusion constraints (`btree_gist`): ranges of the same professional and day, and blocks of the same professional. Touching ranges (09:00-13:00 and 13:00-17:00) are fine. When two requests save at once and both pass the validation, the `OverlapConstraint` concern turns the database's `ExclusionViolation` into the same `:overlap` error (each save runs in a savepoint, so an outer transaction stays usable). Reuse it for any model backed by an exclusion constraint. `time` has no range type, so the working hours constraint puts the times on a fixed date inside a `tsrange`.
- Weekly hours are edited as a whole week (`Admin::SchedulesController`, owners and admins) through the `WeeklySchedule` form object, which replaces every range in one transaction and keeps the errors on each range. The `schedule` Stimulus controller adds and removes ranges in the browser.
- Blocks (`Admin::TimeBlocksController`): owners and admins manage every professional's; professionals only their own profile's, and need one (`Membership#professional_profile`). The list shows ongoing and upcoming blocks (`TimeBlock.upcoming`). A block can't cover the service of an active appointment (its break is fine); the form lists the conflicting ones (`TimeBlock#conflicting_appointments`).
- Display helpers: `time_zone_label` and `format_period` (`FormattingHelper`, "Buenos Aires", "jue 15 oct, 16:00 – 19:00") and `time_block_period` (`TimeBlocksHelper`), with the `date.formats.weekday` and `time.formats.hour` formats defined in `app.yml`.

## Appointments and availability

- `Customer`: no account; identified by email, unique per business. `Appointment`: one service with one professional for one customer, with a `status` (`pending`, `confirmed`, `rejected`, `expired`, `cancelled`, `attended`, `no_show`). `active` (pending and confirmed) appointments hold their time: pending requests too. Customers create pending ones from the public booking flow; the business moves them through the transition methods (see "Request management and live agenda").
- On create an appointment copies the service's price and break (`Service#effective_buffer_minutes`, the service's or the business's), so later changes don't alter it, and sets `request_expires_at` for pending ones (the business's expiration, never after the appointment). `ends_at` and `buffer_ends_at` follow `starts_at`. They are derived before validation and again before save, so they're never missing.
- No double booking: an exclusion constraint on `tsrange(starts_at, buffer_ends_at)` per professional for active appointments, mirrored by a validation, with `OverlapConstraint`.
- `Availability.new(service, professional: nil, now:)` computes free start times in the current business: `days(dates)` returns `{ date => [Slot(starts_at, professionals)] }` for the days within the booking window. Start times are counted from the start of each working range every `slot_interval_minutes`; the service must fit in the range (its break may run past it), can't overlap a block, and service plus break can't overlap an active appointment's time plus break. From now plus `min_booking_notice_hours` up to `booking_horizon_days` from today. Without a professional it means "any": each slot lists who is free. Three queries per call, whatever the range.
- Business settings are read from `Current.business` (`Current.business!`), not from a record's cached `business` association, so they're always current and it fails closed.
- Booking settings (`Admin::SettingsController`, owner only) edit the six booking rules, capped by `Business::BOOKING_LIMITS`.
- Availability preview (`Admin::AvailabilitiesController`): owners and admins pick a service and a professional (or any); professionals see their own. Days without free times say why. The week is the `availabilities/_week` partial (`slot_url:` makes each time a link, `show_professionals: false` hides who is free); `availabilities/_week_navigation` (the booking window's limits and the empty week notice, around the generic `shared/_week_navigation`) and the `AvailabilityWeek` concern (`load_availability_week`) handle moving between weeks, for the panel and the public flow.
- `AppointmentEvent`: an appointment's history, one row per status change (none as `from_status` on creation), with the actor (`customer`, `user` with `actor_user`, or `system`), an optional `note` and `metadata`. Read only once saved; `appointment.events` is chronological. Record one for every transition.
- `appointments_helper#appointment_status_badge` shows a status with its badge color; `appointment_event_title` and `appointment_event_actor` describe a history entry.

## Public booking

- `BookingsController` (`/:business_slug/book`, public): one step at a time, service → professional ("any" or one; skipped when a single one offers the service) → time → contact details. The choices travel in the URL (`service_id`, `professional_id`, `starts_at` in ISO 8601, `week`); anything invalid, not bookable, from another business or no longer free sends the customer back to the step that needs it. The public page links into it per service and per professional.
- `AppointmentRequest` (form object) sends the request in its own transaction (`requires_new`): checks the slot again against `Availability`, finds the customer by email (updating name and phone; a blank phone keeps the old one), rejects a customer's overlapping active appointment, creates the pending appointment and its creation event. With "any professional" it assigns the free one with the fewest active appointments that day (then by name), sets `any_professional`, and tries the next one if the database rejects the first (`slot_taken?` when none is left).
- `POST /:business_slug/book` is rate limited per IP (10 every 10 minutes). The test cache is a memory store cleared before each example, so rate limits can be tested.
- `Appointment` has `generates_token_for :management` with no embedded data: the customer's personal link stays valid for the appointment's whole life. `AppointmentsController#show` (`/:business_slug/appointments/:token`, public, `noindex`) finds it within the current business (404 otherwise) and shows its status, details, the business's reason when it rejected or cancelled it, a note when it was reassigned, and the business's contact. Cancelling and rescheduling from it come with appointment management by link.
- The time step refreshes itself when an appointment changes, so a time someone else takes disappears (see "Live updates").

## Request management and live agenda

- Transitions live in `Appointment`: `confirm!(by:)` and `reject!(by:, reason:)` for requests, `cancel!(by:, reason:)` for confirmed appointments that haven't started, `mark_attended!(by:)` and `mark_no_show!(by:)` once they started, `reassign!(professional, by:)` for active ones that haven't started, and `expire!` (the system, for overdue requests). `by` is the acting `User` (or `:customer` / `:system`). Each one locks the row, checks the current status, saves and records its `AppointmentEvent` in one transaction; anything that no longer applies raises `Appointment::InvalidTransition`, and acting on a request past its deadline expires it instead (and raises). Add new transitions through the private `transition!`.
- The team's rejections and cancellations need a reason (the event's `note`, up to 500 characters, shown to the customer): validated on `AppointmentEvent` and by a check constraint. A missing one raises `RecordInvalid` on the event, before anything changes.
- Reassigning keeps the status and records the previous and new professional in the event's `metadata`. The new professional must be active, offer the service, work the whole service (in the business's time zone) and have no block or appointment then (`professional` / `service` / `base` errors); the customer's booking window doesn't apply.
- Permissions: `Membership#visible_appointments` (owners and admins every one, professionals their own profile's) scopes every panel query; another professional's appointment is a 404. Professionals confirm, reject, cancel and mark attendance on their own; reassigning needs `manager?`. `Membership#manages_appointment?` answers the same for one appointment.
- `ExpireRequestsJob` runs every minute (`config/recurring.yml`): it finds overdue requests across businesses (`BusinessScoped.across_businesses`) and expires each one within its own business. `Appointment.awaiting_answer` leaves out overdue requests that haven't expired yet.
- Panel: `Admin::RequestsController` (pending requests, the ones expiring first on top, with the sidebar count), `Admin::AppointmentsController` (details, history, confirm and attendance), `Admin::RejectionsController`, `Admin::CancellationsController` (reason forms, `admin/appointments/_reason_form`) and `Admin::ReassignmentsController` (managers only), sharing `Admin::AppointmentActions` (finds the appointment among the visible ones and turns `InvalidTransition` into an alert on its page). `Admin::AgendasController` shows a week (`?week=`, any date in it) of `Appointment.on_agenda` (pending, confirmed, attended, no show), by professional or everyone's. The dashboard lists pending requests and today's appointments.

### Live updates

- After every commit an appointment broadcasts a Turbo 8 refresh to `Appointment.panel_stream(business)` and `Appointment.availability_stream(business)`. Pages subscribe with `refresh_on_appointment_changes(stream)`, which also sets morphing with preserved scroll: the panel's dashboard, requests, agenda and appointment page, and the public time step. Pages with forms don't subscribe, so a refresh never wipes what someone is typing.
- Broadcasts carry no data: each page reloads itself with its viewer's permissions, so nothing leaks between professionals, and there are no partials to keep in sync. Turbo ignores the refresh caused by the viewer's own request.
- Action Cable connections may be anonymous (customers have no account); the signed in user is identified when there is one. Streams stay private because Turbo only subscribes to signed stream names, which include the business. Specs use `turbo_stream_name` and `signed_turbo_stream_name` (`spec/support/turbo_stream_helpers.rb`).

## Multi-tenancy

Single database, shared tables: every per-business table has a `business_id`, and the current tenant lives in `Current.business`.

- Per-business tables have a unique `(business_id, id)` index, and child tables reference them with composite foreign keys (`add_foreign_key ..., column: %i[business_id x_id], primary_key: %i[business_id id]`), so the database rejects rows that mix businesses.

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
