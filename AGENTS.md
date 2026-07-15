## Project

tinyslug is an MIT-licensed, privacy-focused, self-hostable link shortener: short links, tags, QR codes, privacy-preserving analytics, custom domains, and a bearer-token API. Rails 8.1, Ruby 4.0.6, Hotwire (Turbo + Stimulus via importmap, no Node), Tailwind CSS 4, PostgreSQL 17, Solid Queue/Cache/Cable.

Ruby is pinned in `mise.toml`; no global Ruby is assumed. Prefix commands with `mise exec --` (README convention). Copy strategy: state features plainly (free, open source, custom domains); no vague taglines.

## Commands

```sh
docker compose up -d postgres            # PostgreSQL 17 (or native PG with socket auth)
mise exec -- bin/setup                   # install gems, prepare DBs, start server
mise exec -- bin/dev                     # foreman: web + tailwindcss:watch (Procfile.dev)
mise exec -- bin/jobs                    # Solid Queue worker (needed for visit recording, domain verification)

mise exec -- bin/ci                      # full CI: setup (bin/setup --skip-server), rubocop, bundler-audit, importmap audit, brakeman, tests, system tests, seeds, zeitwerk, asset precompile (config/ci.rb)
mise exec -- bin/rails test              # all non-system tests
mise exec -- bin/rails test:system       # system tests (Capybara/Selenium)
mise exec -- bin/rails test test/models/link_test.rb        # one file
mise exec -- bin/rails test test/models/link_test.rb:42     # one test by line
mise exec -- bin/rails test test/models/link_test.rb -n /slug/   # by name pattern

mise exec -- bin/rubocop                 # rubocop-rails-omakase style
mise exec -- bin/brakeman --no-pager     # security static analysis
mise exec -- bin/rails db:seed           # idempotent demo data (demo@tinyslug.local)
```

### Testing

Tests use Minitest with fixtures (`test/fixtures`), run in parallel, and include Devise integration helpers (`test/test_helper.rb`). System tests run headless Chrome via Selenium with a `sign_in_as` helper (`test/application_system_test_case.rb`); the fixture password is "password123". There is no WebMock/VCR: `CustomDomains::Verify.call` accepts an injectable `resolver:` kwarg and tests pass a fake resolver struct with `Resolv::DNS::Resource` doubles (`test/operations/custom_domains/verify_test.rb`); DNS-touching code must keep this pattern. Devise mail is deferred via `ActiveRecord.after_all_transactions_commit { ... deliver_later }`, so confirmation email is not synchronous in tests. Rubocop is pure rubocop-rails-omakase with no overrides; note the omakase spaced-bracket array style `[ a, b ]`. GitHub Actions CI (`.github/workflows/ci.yml`) is a single job running `bin/ci` against postgres:17-alpine with `TEST_DATABASE_URL`. Development email is written to `tmp/mails`. `.env.example` documents every environment variable.

## Architecture

### Layered app/ structure

Beyond MVC, business logic lives in plain Ruby classes autoloaded from:

- `app/operations/` - single-purpose service objects (`Links::Create`, `Links::Update`, `Links::Resolve`, `Links::CsvExport`, `Links::TagAssignment`, `CustomDomains::Verify`, `CustomDomains::Destroy`), class-method `call` returning a `Data.define` result object (`Outcome`/`Result`) instead of raising. Link updates and CSV export go through operations, not controllers. Exception: `Visits::PayloadBuilder.call` returns a plain payload Hash or nil.
- `app/queries/` - read-side query objects for links and visits (analytics aggregation). Pagination is `pagy` used manually: query objects build `Pagy::Offset.new` and return `[pagy, records]` (`app/queries/links/search.rb`); no `Pagy::Backend` mixin in controllers; views hand-roll prev/next links.
- `app/representations/api/v1/` - API response shaping (`Api::V1::LinkRepresentation`).
- `app/validators/` - e.g. `SafeHttpUrlValidator` guarding destination URLs.

### Domain model

`Account` is the tenant root: it owns `links`, `custom_domains`, `tags`, `api_tokens` and has one `User` (Devise, confirmable). On signup, `User#before_validation :build_personal_records` auto-builds the personal Account and Profile with `validates_associated` + autosave (`app/models/user.rb`). `Link` belongs to an account and optionally a `custom_domain`; slug uniqueness is scoped per custom domain, with a partial unique index for primary-host links. DB check constraints enforce slug format and lengths (`db/schema.rb`). Normalizations: tag names are squished and downcased, account keys downcased.

### Link creation and resolution

- Create: `Links::Create` dedupes by destination URL when no name/slug requested, generates slugs via `Link.generate_slug` with retry on collision (max 5 attempts), assigns tags transactionally, and emits `Rails.event.notify("tinyslug.link.*")` structured events.
- Resolve: `GET /:slug` is the last route in `config/routes.rb`, handled by `RedirectsController` -> `Links::Resolve.call(host:, slug:, primary_host:)`. Host-aware: primary host looks up `custom_domain_id: nil` links; other hosts must match a verified `CustomDomain` (with optional `fallback_url` redirect). 302 redirect with `allow_other_host: true`.
- Reserved slugs: `Link::RESERVED_SLUGS` (`app/models/link.rb`) denylists top-level path segments (admin, api, dashboard, etc.) via an exclusion validation; any new top-level route must also be added to `RESERVED_SLUGS` or it collides with the `GET /:slug` catch-all. `SLUG_ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz"` deliberately excludes ambiguous characters (0/1/i/l/o).
- QR codes: `rqrcode` gem, generated on the fly in `LinksController#qr` (member route `get :qr`) as SVG or PNG via `send_data`; nothing is stored.

### Privacy-preserving analytics

Tracking is opt-in per link (`tracking_enabled`). `Visits::PayloadBuilder` runs in the redirect request: it bails on DNT/GPC headers and bots, then builds a payload with a daily-rotating HMAC `visitor_digest` (link id + UTC date + /24 or /48 masked IP + browser/device classification, keyed by `VISITOR_DIGEST_SECRET`). Raw IPs, full referrers, query strings, and raw user agents are never persisted. `RecordVisitJob` (async, idempotent via `event_key` UUID) writes the `Visit`. `VisitRetentionJob` deletes expired visits daily (`REDIRECT_VISIT_RETENTION_DAYS`, default 90). Analytics periods are clamped to 7 or 30 days only (`app/queries/visits/analytics.rb`), timezone comes from `current_user.profile.timezone`, and grouping is raw SQL (no groupdate). Charts render client-side with Chartkick + Chart.js pinned in `config/importmap.rb`, driven by `app/javascript/controllers/analytics_controller.js`.

### Custom domains

Verification requires both a TXT record (`_tinyslug-verification.<hostname>` with token) and CNAME/A/AAAA pointing at `CUSTOM_DOMAIN_DNS_TARGET`. `CustomDomainVerificationSweepJob` re-checks every 30 minutes (`config/recurring.yml`); verified hosts are admitted by production Host Authorization. Removing a domain moves its links back to the primary host, suffixing colliding slugs. Hostnames are normalized (downcased, trailing dot stripped); `CustomDomain` rejects reserved hostnames (primary host, www, api, assets) and raw IP addresses.

### Auth surfaces

Two distinct auth models (`docs/routes.md` records the decision per route area):

- Web: Devise with custom paths (`/login`, `/register`, etc.), confirmed session required; records always scoped through `current_user.account`. `ApplicationController` sets `allow_browser versions: :modern` (old browsers get `public/406-unsupported-browser.html`) and redirects sign-in to `dashboard_path`.
- API (`/api/v1/*`): `Api::BaseController < ActionController::API`, bearer token only (`ApiToken.authenticate` against an HMAC-SHA256 digest keyed by `API_TOKEN_DIGEST_SECRET`); no cookie sessions. The API surface is create-only: `POST /api/v1/links` is the sole endpoint (`resources :links, only: :create` in `config/routes.rb`). Error shapes differ: auth failures return `{ "error": "Unauthorized" }`, validation failures return `{ "errors": {...} }`; success is 201 on create, 200 when deduped to an existing link, shaped by `Api::V1::LinkRepresentation`. Plaintext token secrets are prefixed `ts_` and shown once; `ApiToken.issue` returns a `Data.define` of (api_token, secret); `last_used_at` updates are throttled to once per hour.
### Rate limiting

Rails 8 native `rate_limit` declared per controller, not Rack::Attack. Each controller defines `RATE_LIMIT_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache` so limits do not bleed across parallel tests. Examples: `Api::V1::LinksController` (60/min by account), `CustomDomainsController` (5/10min, only `:verify`), `ApiTokensController`, `Users::SessionsController`, `Users::PasswordsController`. New endpoints should follow this pattern and key via `Privacy::RateLimitKey` where IP-derived. Rate-limited responses render `public/429.html`.

### Demo mode

`DEMO_MODE_ENABLED=true` (default false) turns an instance into a resettable demo: `DemoResetJob` runs at midnight daily in production (`config/recurring.yml`), destroys all `Account`s (cascading), sweeps orphans in FK-safe order, and reloads `db/seeds.rb`. The job no-ops when the flag is off. A demo banner renders only for signed-in users (`app/views/layouts/application.html.erb`, `demo_mode?` helper).

### Background jobs

Solid Queue on a separate `queue` database (`config/database.yml`; production also splits `cache` and `cable` databases). `bin/dev` does NOT start a worker; run `bin/jobs` separately or visit tracking and domain verification will not execute. Recurring schedule lives in `config/recurring.yml` (production block), which also clears finished Solid Queue jobs hourly.

### Frontend conventions

"Hyperlink blue" design system defined as Tailwind 4 `@theme` tokens in `app/assets/tailwind/application.css`: semantic colors (`--color-hyperlink: #2323E8`, paper/surface/ink/line, danger/caution/success tints) and self-hosted IBM Plex Sans/Mono. Use these tokens, not arbitrary hex values. JS is importmap + Stimulus controllers in `app/javascript/controllers/` (copy, search, analytics with Chartkick charts). Assets via Propshaft.

Dashboard link create/update/destroy respond to both HTML and Turbo Stream (`flash.now` + turbo_stream templates, `:unprocessable_content` on failure); keep the dual-format pattern for new link-management UI. Strict CSP with per-session nonces on script and style (`config/initializers/content_security_policy.rb`) plus a secure headers initializer; inline scripts/styles need a nonce. Custom self-contained error pages live in `public/` (400, 404, 406-unsupported-browser, 422, 429, 500); `test/controllers/error_pages_test.rb` asserts each contains the status code, "tinyslug", and a noindex robots meta tag, so edits must preserve those tokens.

### Configuration and deployment

Feature flags and settings are read once into `Rails.configuration.x.*` in `config/application.rb`; `config/initializers/runtime_configuration.rb` fails production boot if required secrets (`APP_HOST`, `DATABASE_URL`, `VISITOR_DIGEST_SECRET`, `API_TOKEN_DIGEST_SECRET`, `RATE_LIMIT_DIGEST_SECRET`) are missing. Each digest secret must be independent, but that is a documented convention (`docs/operations.md`, `.env.example`), not enforced at boot; the initializer only checks presence. Deployment is Kamal (`config/deploy.yml`) with separate `web` and `job` (`bin/jobs`) roles; `docs/operations.md` is the runbook.
