# Bookly

Online appointment booking for businesses that work by schedule (barbershops, clinics, studios, sports courts). Each business gets its own public page with its services, professionals and hours; customers request appointments without creating an account, and the business confirms them. A single app serves many businesses (multi-tenant) without mixing their data.

Built with Rails 8.1, Ruby 3.4, PostgreSQL, Hotwire and Tailwind.

## Status

Early development. What works today:

- **Businesses** with their own booking configuration (start interval, breaks, cancellation window, request expiration, minimum notice, booking horizon), language and time zone.
- **Public business page** at `/:business_slug`, rendered in the business's language and time zone. Suspended businesses show an "unavailable" page.
- **Tenant isolation:** per-business data is filtered by the current business and fails closed when there is none.
- **Spanish and English** throughout, Spanish by default.

## Roadmap

- [x] Businesses and tenant context
- [ ] Users, authentication, roles and professional invitations
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
bin/rails db:seed         # sample businesses
bin/dev                   # web server on http://localhost:3000 + Tailwind watcher
```

Sample businesses:

- http://localhost:3000/barberia-centro — Spanish, Buenos Aires
- http://localhost:3000/downtown-studio — English, New York

## Tests and checks

```bash
bundle exec rspec   # test suite
bin/ci              # RuboCop, bundler-audit, importmap audit, Brakeman and RSpec
```
