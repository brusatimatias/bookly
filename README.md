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
- [ ] Request management and live schedule (confirm, reject, reassign, expiration)
- [ ] Appointment management by personal link (cancel, reschedule)
- [ ] Emails and reminders
- [ ] Business onboarding and platform panel
- [ ] Subdomains and branding (optional)
- [ ] Schema-per-business migration (comparative exercise)
- [ ] Deployment

## Requirements

- Ruby 3.4.1
- PostgreSQL (local socket, authenticated as your OS user)

## Getting started

```bash
bin/setup --skip-server   # install gems, create and migrate the database
bin/rails db:seed         # sample businesses and users
bin/dev                   # web server on http://localhost:3000 + Tailwind watcher
```

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

Both businesses come with services, professionals, weekly hours, a few upcoming blocks and some appointments in the coming days, with their history. To try a request, use the booking button on a business page ("Pedir un turno" / "Book an appointment"). Barbería Centro also has an inactive service and a professional profile without an account (Sofía Torres), to try inviting someone from their profile.

There is no public sign up yet: new team members join through invitations. Emails sent in development (invitations, password resets) can be read at http://localhost:3000/letter_opener.

## Tests and checks

```bash
bundle exec rspec   # test suite
bin/ci              # RuboCop, bundler-audit, importmap audit, Brakeman and RSpec
```
