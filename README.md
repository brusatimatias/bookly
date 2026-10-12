# Bookly

Online appointment booking for businesses that work by schedule (barbershops, clinics, studios, sports courts). Each business gets its own public page with its services, professionals and hours; customers request appointments without creating an account, and the business confirms them. A single app serves many businesses (multi-tenant) without mixing their data.

Built with Rails 8.1, Ruby 3.4, PostgreSQL, Hotwire and Tailwind.

## Status

Early development. What works today:

- **Businesses** with their own booking configuration (start interval, breaks, cancellation window, request expiration, minimum notice, booking horizon), language and time zone.
- **Public business page** at `/:business_slug`, rendered in the business's language and time zone. Suspended businesses show an "unavailable" page.
- **Tenant isolation:** per-business data is filtered by the current business and fails closed when there is none.
- **Accounts:** sign in, sign out and password reset by email.
- **Business panel** at `/:business_slug/admin` for the business's members, with roles: owner, admin and professional.
- **Team invitations:** the owner invites admins and professionals by email; the link (valid for 7 days, single use) lets them create their account or join with an existing one. Invitations can be resent or revoked.
- **Spanish and English** throughout, Spanish by default. Pages outside a business follow the browser's language and offer a language switcher; business pages and emails use the business's language.

## Roadmap

- [x] Businesses and tenant context
- [x] Users, authentication, roles and professional invitations
- [ ] Services and professionals
- [ ] Working hours and schedule blocks
- [ ] Availability calculation
- [ ] Public appointment request
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

There is no public sign up yet: new team members join through invitations. Emails sent in development (invitations, password resets) can be read at http://localhost:3000/letter_opener.

## Tests and checks

```bash
bundle exec rspec   # test suite
bin/ci              # RuboCop, bundler-audit, importmap audit, Brakeman and RSpec
```
