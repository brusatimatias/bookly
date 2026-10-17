# Bookly

Online appointment booking for businesses that work by schedule (barbershops, clinics, studios, sports courts). Each business gets its own public page with its services, professionals and hours; customers request appointments without creating an account, and the business confirms them. A single app serves many businesses (multi-tenant) without mixing their data.

Built with Rails 8.1, Ruby 3.4, PostgreSQL, Hotwire and Tailwind 4 (no Node required).

## Status

Early development. What works today:

- **Businesses** with their own booking configuration (start interval, breaks, cancellation window, request expiration, minimum notice, booking horizon), language and time zone.
- **Public business page** at `/:business_slug`, rendered in the business's language and time zone, listing the services and professionals customers can book. Suspended businesses show an "unavailable" page.
- **Tenant isolation:** per-business data is filtered by the current business and fails closed when there is none.
- **Accounts:** sign in, sign out and password reset by email.
- **Business panel** at `/:business_slug/admin` for the business's members, with roles: owner, admin and professional.
- **Team:** the owner invites admins and professionals by email; the link (valid for 7 days, single use) lets them create their account or join with an existing one. Invitations can be resent or revoked. The owner can also switch members between admin and professional, and remove them from the team (their professional profile is kept, inactive).
- **Services and professionals:** owners and admins manage services (duration, price, optional break, rich text description) and professional profiles (photo, offered services, optional linked account). Both are deactivated rather than deleted. A profile can be created before its person has an account and then taken over through an invitation; invited professionals get a profile automatically, and owners and admins can have one too.
- **Working hours and blocks:** owners and admins set each professional's weekly hours (several ranges per day, copied across weekdays in one click). Blocks mark periods a professional can't be booked, with exact times or whole days; professionals manage their own. Only professionals with services and hours are shown to customers.
- **Availability:** free start times are computed from working hours, blocks and appointments, following the business's booking rules (start interval, breaks, minimum notice, booking horizon), with no double booking enforced by the database. The owner edits those rules from the panel, and every member can preview the week's free times as customers will see them.
- **Online requests:** customers book from the business's page without an account: service, professional (or any), a free time and their contact details. The request holds the time until the business answers, and the customer gets a personal link to see it. With "any professional" the least busy free one is assigned.
- **Request management:** the business confirms or rejects requests (a rejection needs a reason, which the customer sees), reassigns appointments to another free professional, cancels confirmed ones with a reason and marks attendance once they start. Professionals answer their own; owners and admins any. Requests nobody answers expire on their own, and every change is kept in the appointment's history.
- **Managing by personal link:** customers withdraw a request, or cancel or reschedule a confirmed appointment until the business's cancellation window closes, from their personal link. Rescheduling frees the old time at once and the appointment waits for the business's confirmation again; the panel marks it as a change of time.
- **Emails and reminders:** customers get an email for every change to their appointment (request received, confirmed, rejected or cancelled with the business's reason, expired, moved to another professional, change of time received) and a reminder before it, as many hours ahead as the business sets (24 by default, or none). Confirmed appointments come with a calendar file (`.ics`), also downloadable from the customer's page, and a cancellation file when they leave the calendar. The professional, the owner and the admins hear about new requests, changes of time and cancellations from customers. Emails go out in the business's name and language, and replies reach the business (or, for the team, the customer).
- **Live agenda:** a weekly agenda per professional (or of everyone), a requests list and a dashboard with pending requests and today's appointments. They update by themselves when a request comes in or an appointment changes, and so do the public page's week of free times and the customer's appointment page.
- **Consistent, responsive UI:** a landing page, public business pages, sign in screens and a business panel with sidebar navigation that collapses into a menu on phones.
- **Spanish and English** throughout, Spanish by default. Pages outside a business follow the browser's language and offer a language switcher; business pages and emails use the business's language.

## Roadmap

- [x] Businesses and tenant context
- [x] Users, authentication, roles and professional invitations
- [x] UI foundation: theme, components and layouts
- [x] Services and professionals
- [x] Working hours and schedule blocks
- [x] Availability calculation
- [x] Public appointment request
- [x] Request management and live schedule (confirm, reject, reassign, expiration)
- [x] Appointment management by personal link (cancel, reschedule)
- [x] Emails and reminders
- [ ] Business onboarding and platform panel (completes the MVP)
- [ ] Project documentation: architecture, diagrams and design decisions

After the MVP, step by step:

- [ ] Subdomains and branding
- [ ] Schema-per-business migration (comparative exercise)
- [ ] Deployment

## Requirements

- Ruby 3.4.1
- PostgreSQL (local socket, authenticated as your OS user)

## Getting started

```bash
bin/setup --skip-server   # install gems, create and migrate the database
bin/rails db:seed         # sample businesses and users
bin/dev                   # web server on http://localhost:3000, background jobs and Tailwind watcher
```

Background jobs (Solid Queue, `bin/jobs`) and live updates (Solid Cable) use their own databases in development too (`bookly_development_queue` and `bookly_development_cable`, created by `bin/setup`). `bin/dev` runs the jobs; without them requests don't expire, reminders aren't sent and no email goes out.

Sample businesses:

- http://localhost:3000/barberia-centro — Spanish, Buenos Aires
- http://localhost:3000/downtown-studio — English, New York

Sample users, all with the password `password` (sign in at http://localhost:3000/session/new):

| Email | Role |
|---|---|
| lucia@barberiacentro.example | Owner of Barbería Centro |
| diego@barberiacentro.example | Admin of Barbería Centro |
| martin@barberiacentro.example | Professional in both businesses |
| sam@downtownstudio.example | Owner of Downtown Studio |

Both businesses come with services, professionals, weekly hours, a few upcoming blocks and some appointments in the coming days, with their history. Barbería Centro also gets, whenever it has none, a request expiring in two hours, an appointment that started an hour ago and a change of time waiting for an answer (Lucas Vera), to try answering requests and marking attendance in the panel (Pedidos / Agenda). To try a request, use the booking button on a business page ("Pedir un turno" / "Book an appointment"). Barbería Centro also has an inactive service and a professional profile without an account (Sofía Torres), to try inviting someone from their profile, plus a rejected request, an appointment the business cancelled and an expired request.

There is no public sign up yet: new team members join through invitations.

Emails sent in development (invitations, password resets, appointment emails and reminders) can be read at http://localhost:3000/letter_opener. Seeding sends none; every appointment email can be previewed with the seeded data at http://localhost:3000/rails/mailers. Emails are sent from `no-reply@bookly.test` unless `BOOKLY_MAIL_FROM` says otherwise.

## Tests and checks

```bash
bundle exec rspec   # test suite
bin/ci              # RuboCop, bundler-audit, importmap audit, Brakeman and RSpec
```
