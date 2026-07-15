# tinyslug Rails 8.1 Implementation Plan

## Purpose

This document is the complete implementation contract for rebuilding tinyslug from an empty directory. The implementer should not need the legacy repository to understand the required product behavior.

Build a production-ready, open-source, privacy-focused link management application using modern Rails conventions. Work feature by feature in the order below. Every phase must leave the application bootable and its completed behavior covered by automated tests.

The finished application must provide:

- User registration, email confirmation, login, logout, password recovery, and profile management.
- Short-link creation and management on the primary application domain.
- Optional custom slugs, tags, filtering, search, QR codes, and CSV export.
- Fast redirects that can optionally record privacy-preserving analytics.
- Analytics for visits, unique visits, countries, referrers, browsers, devices, and top links.
- Custom-domain registration, DNS verification, routing, and fallback URLs.
- An authenticated JSON API that reuses the same application logic as the HTML interface.
- An optional anonymous public shortener that also reuses the same application logic.
- Public user profiles with selected links and social links.
- A straightforward self-hosting and contribution experience.

## Non-negotiable decisions

- Pin Ruby `4.0.6` and Rails `8.1.3`.
- Use `mise` to manage Ruby. Every documented Ruby/Rails command must work through the repository's mise configuration.
- Use PostgreSQL in development, test, and production.
- Use Rails 8.1 defaults where practical: Propshaft, Importmap, Turbo, Stimulus, Solid Queue, Solid Cache, and Solid Cable.
- Use Tailwind through `tailwindcss-rails`. Do not introduce Node, Yarn, npm, Webpacker, or a JavaScript bundler unless an accepted architecture decision later proves one is necessary.
- Use server-rendered HTML and Hotwire. Do not introduce React, Vue, Svelte, jQuery, or Turbolinks.
- Use Devise for authentication, including confirmable and recoverable behavior.
- Do not add an authorization gem or policy framework. Enforce tenant isolation by loading records through the current account association.
- Do not build payments, plans, subscriptions, trials, coupons, entitlements, or AppSumo support.
- Do not build administrator roles, an administrator interface, impersonation, or user-management controls.
- All application features are available to every registered user.
- Do not require Redis or Sidekiq for the initial implementation.
- The open-source application must boot without credentials for AWS, Postmark, Sentry, Slack, Heroku, Cloudflare, Paddle, or MaxMind.
- Do not perform outbound HTTP requests to validate a destination during redirect. Redirecting is the product; server-side destination fetching adds latency and SSRF risk.
- Never persist a visitor's raw IP address or place a raw IP address in a background-job argument.
- Keep controllers thin. HTML, authenticated API, and anonymous-shortener controllers must reuse the same application operations rather than calling or inheriting from one another.
- Do not commit, push, deploy, or publish unless the user explicitly asks.

## Explicitly out of scope

- Payments and commercial feature gates.
- Teams, shared workspaces, or invitations.
- Roles beyond the internal distinction between personal and public-shortener accounts.
- An admin dashboard.
- OAuth/social login.
- Native mobile applications.
- Bulk link creation. The legacy README mentioned it, but the legacy API only implemented singular creation.
- Live collaboration.
- A general-purpose webhook system.
- Provider-managed TLS issuance inside Rails. Custom-domain TLS is the responsibility of the reverse proxy or hosting platform.
- A production legacy-data migration without a supplied legacy database or export. An import contract is included near the end of this plan.

## Engineering principles

1. Prefer Rails and Ruby standard capabilities over additional gems.
2. Add a dependency only when it removes meaningful, well-understood complexity.
3. Put durable invariants in both model validations and database constraints where PostgreSQL can enforce them.
4. Pass the owning account explicitly to application operations. Do not hide ownership in global state.
5. Keep protocol concerns at the boundary:
   - HTML controllers handle Turbo, redirects, flash messages, and HTML status codes.
   - API controllers handle bearer-token authentication, JSON representations, and API status codes.
   - Application operations handle business workflows and persistence.
6. Test observable behavior rather than private implementation details.
7. Do not expose routes or navigation for incomplete features. Use a simple configuration flag when a partially implemented feature must exist in the codebase.
8. Preserve accessibility, responsive layout, empty states, errors, and loading states as product behavior.

## Initial scaffold

Start in the empty target directory. Preserve this plan in the project root.

Run:

```sh
mise use --pin ruby@4.0.6
mise exec -- gem install rails -v 8.1.3
mise exec -- rails _8.1.3_ new . \
  --database=postgresql \
  --javascript=importmap \
  --css=tailwind
```

If `rails new` reports a conflict for this plan, keep this file unchanged.

The resulting `mise.toml` must pin the exact Ruby patch version. The application must not rely on a globally installed Ruby, Bundler, Rails, or Node runtime.

After scaffolding, add a documented `compose.yaml` with a pinned, supported PostgreSQL major version, a health check, and a named data volume. Support either that container or a native PostgreSQL installation. Start PostgreSQL and then run `mise exec -- bin/setup`; if PostgreSQL is unavailable, `bin/setup` must fail with a concise remediation message rather than an opaque stack trace.

Use the default Rails-generated Dockerfile, Kamal configuration, RuboCop Rails Omakase configuration, Brakeman, and importmap audit support unless a concrete incompatibility requires adjustment.

## Dependency policy

Add only the following application dependencies initially, using current versions compatible with Ruby 4.0 and Rails 8.1 and pinning compatible major/minor ranges in the Gemfile:

- `devise` for authentication.
- `pagy` for pagination.
- `rqrcode` for QR generation.
- `device_detector` for browser and device classification.
- `active_storage_validations` for avatar content type and size validation.
- `chartkick` for server-driven charts, with Chart.js pinned through Importmap.

Retain Rails-generated dependencies such as `image_processing`, `solid_queue`, `solid_cache`, `solid_cable`, `kamal`, `thruster`, `brakeman`, and `rubocop-rails-omakase` where generated.

Do not add CanCanCan, Pundit, Ransack, acts-as-taggable-on, LightService, Sidekiq, Redis, Webpacker, ViewComponent, a serializer framework, or a state-machine gem initially.

Use Jbuilder or small plain Ruby representation objects for JSON. Do not add a serialization gem merely to format the first API endpoint.

## Application structure

Use conventional Rails folders plus these narrowly defined application-layer folders:

```text
app/
  controllers/
    api/
      v1/
  jobs/
  mailers/
  models/
  operations/
    custom_domains/
    links/
    visits/
  queries/
    links/
    visits/
  validators/
  views/
```

Do not create a generic service framework, base operation class, dependency container, repository layer, or result monad. An operation may return a model carrying validation errors or a small operation-specific `Data` result when it must distinguish outcomes such as "created" from "reused."

## Ownership model

Use an `Account` as the non-null owner of links, custom domains, tags, and API tokens.

- Every normal `User` has exactly one personal `Account`.
- The optional public shortener owns links through one internal `public_shortener` account that has no login-capable user.
- The account exists to provide consistent tenant scoping and a safe owner for anonymous links. It is not a team/workspace feature and must not be exposed as one.
- HTML controllers use `current_user.account`.
- API controllers use `current_api_token.account`.
- The public shortener uses `Account.public_shortener`.
- Never query a user-owned record by an unscoped user-supplied ID. For example, use `current_user.account.links.find(params[:id])`, not `Link.find(params[:id])`.

This direct ownership scoping is the only authorization mechanism in the initial application. Add cross-account request tests for every member-facing resource.

## Data model and validations

Migration names and internal implementation details may vary, but the following fields, relationships, validations, database constraints, and indexes are required.

### Account

Fields:

- `kind`: integer enum with `personal` and `public_shortener`.
- `key`: normalized opaque string identifier, required and globally unique. Generate a stable random key for personal accounts; do not derive it from the mutable username.
- Timestamps.

Relationships:

- Has at most one user. A personal account must have one user after registration completes; a public-shortener account must have none.
- Has many links, custom domains, tags, and API tokens.

Rules:

- `kind` and `key` are required.
- Normalize `key` to lowercase before validation.
- A public-shortener account cannot be attached to a login-capable user.
- Only one account may use the `public-shortener` key.
- `Account.public_shortener` must find or create the account idempotently only when public shortening is enabled. It must never create a user or a usable password.
- Back uniqueness with a unique database index.

### User

Use Devise modules:

- `database_authenticatable`
- `registerable`
- `recoverable`
- `rememberable`
- `validatable`
- `confirmable`

Additional fields:

- `account_id`, required and unique.
- `username`: required normalized lowercase string.
- Devise-generated fields and timestamps.

Relationships:

- Belongs to one personal account.
- Has one profile, created with the user.

Rules:

- Username length: 3 to 30 characters.
- Username format: lowercase ASCII letters, digits, and underscores only: `\A[a-z0-9_]+\z`.
- Username must be case-insensitively unique and backed by a unique expression index on `lower(username)`.
- Reserve usernames used by application routes, including `admin`, `api`, `assets`, `login`, `logout`, `register`, `settings`, `support`, `terms`, `privacy`, `up`, and `rails`.
- Account, user, and profile creation must be atomic. A failed associated record must not leave an orphaned user or account.
- Email confirmation jobs must enqueue only after the transaction commits.

### Profile

Fields:

- `user_id`, unique and non-null.
- `first_name`, `last_name`.
- `bio`, maximum 500 characters.
- `timezone`, default `UTC`.
- `public_enabled`, boolean, default false and non-null.
- Timestamps.

Relationships:

- Belongs to user.
- Has one attached avatar.
- Has many profile links and social links.

Rules:

- Timezone must be included in `ActiveSupport::TimeZone.all.map(&:name)`.
- First and last names are each limited to 100 characters.
- Avatar types: PNG, JPEG, or WebP.
- Avatar maximum size: 5 MiB.
- Public profile URL uses the user's normalized username.

### Link

Fields:

- `account_id`, non-null.
- Optional `custom_domain_id`.
- `destination_url`, text, non-null.
- `name`, string, non-null.
- `slug`, string, non-null.
- `tracking_enabled`, boolean, default false and non-null.
- `source`, integer enum with `dashboard`, `api`, and `public_shortener`.
- Timestamps.

Relationships:

- Belongs to account.
- Optionally belongs to custom domain.
- Has many visits and taggings, dependent on deletion.
- Has many tags through taggings.

Rules:

- Destination URL maximum length: 2,048 characters.
- Destination URL must be absolute, have a host, and use only `http` or `https`.
- Reject userinfo in destination URLs.
- Never mutate a caller-provided URL string while normalizing or validating it.
- Name length: 1 to 255 characters. Default to a safely truncated destination URL when blank.
- Normalize slug to lowercase.
- Slug length: 3 to 64 characters.
- Slug format: `\A[a-z0-9]+(?:-[a-z0-9]+)*\z`.
- Generated slugs use at least seven non-ambiguous random characters.
- Reserve all primary application route names and internal Rails paths.
- A selected custom domain must belong to the same account as the link.
- A `public_shortener` link must belong to the public-shortener account, cannot use a custom domain, must use an automatically generated slug, and must have tracking disabled.
- Primary-domain slug uniqueness must be backed by a partial unique index on `slug WHERE custom_domain_id IS NULL`.
- Custom-domain slug uniqueness must be backed by a unique index on `[custom_domain_id, slug]`.
- Add indexes supporting account listing, account/source filtering, and redirect resolution.

Destination URL validation belongs in a reusable Active Model validator shared by `Link` and custom-domain fallback URLs. Do not make a network request from the validator.

### CustomDomain

Fields:

- `account_id`, non-null.
- `hostname`, non-null.
- Optional `fallback_url`.
- `status`: integer enum with `pending`, `verified`, and `failed`.
- `verification_token`, non-null and unique.
- Optional `dns_target`.
- Optional `verified_at`.
- Optional `last_checked_at`.
- Timestamps.

Relationships:

- Belongs to account.
- Has many links; deletion nullifies their custom-domain reference rather than deleting links.

Rules:

- Accept ASCII hostnames and punycode in the initial release; Unicode input may be added later with deliberate IDNA handling.
- Normalize lowercase and remove one trailing dot before validation.
- Hostname maximum length: 253 characters.
- Reject schemes, ports, paths, query strings, fragments, whitespace, IP literals, `localhost`, and malformed labels.
- Reject the application's primary host and its reserved infrastructure hosts.
- Enforce case-insensitive global uniqueness with a unique expression index on `lower(hostname)`.
- Fallback URL is optional but, when present, uses the same safe HTTP/HTTPS URL validator as a link destination.
- Verification tokens use at least 32 random bytes and are never predictable.
- A domain becomes verified only after its configured TXT ownership record and routing record pass verification.
- Status transitions must be explicit in a domain operation, not hidden in a callback.

### Tag

Fields:

- `account_id`, non-null.
- `name`, non-null.
- Timestamps.

Rules:

- Normalize by stripping surrounding whitespace, collapsing internal whitespace, and lowercasing.
- Length: 1 to 40 characters.
- Unique per account, backed by a unique index on account and normalized name.

### Tagging

Fields:

- `link_id`, non-null.
- `tag_id`, non-null.
- Timestamps.

Rules:

- Link and tag must belong to the same account.
- A tag may be attached to a link only once, backed by a unique index on `[link_id, tag_id]`.

### Visit

Fields:

- `link_id`, non-null.
- `visitor_digest`, fixed-length string, non-null.
- Optional `browser`, `device_type`, `country_code`, and `referrer_host`.
- `occurred_at`, non-null.
- Timestamps only if useful; do not duplicate `occurred_at` without a reason.

Rules:

- Never store IP addresses, full referrer URLs, query strings, or raw user-agent strings.
- Visitor digest must be a lowercase 64-character SHA-256 hex digest.
- Build the digest from a server secret, link identifier, UTC date, a truncated/anonymized network prefix, and a normalized user-agent classification. Compute it in the request process, then discard the IP.
- Daily rotation prevents durable cross-day tracking.
- Referrer stores only a normalized host, limited to 253 characters.
- Country uses a two-character uppercase ISO code when available.
- Browser and device fields are each limited to 100 characters.
- Index `[link_id, occurred_at]` and `[link_id, visitor_digest, occurred_at]`.
- Visits are created only when tracking is enabled and the request does not express Do Not Track or Global Privacy Control.

If no local GeoIP database or trusted country header is configured, leave `country_code` blank. Country lookup must degrade gracefully and must never call a paid remote API.

### ApiToken

Fields:

- `account_id`, non-null.
- `name`, non-null.
- `token_digest`, non-null.
- `token_prefix`, non-null.
- Optional `last_used_at` and `revoked_at`.
- Timestamps.

Rules:

- Generate at least 32 random bytes for the bearer secret.
- Persist only a keyed SHA-256 digest and a non-sensitive display prefix.
- Show the full token exactly once at creation.
- Name length: 1 to 80 characters.
- Digest is globally unique with a unique index.
- Authentication uses constant-time comparison.
- Revoked tokens never authenticate.
- Updating `last_used_at` must not turn every API request into a blocking critical-path write; throttle updates to at most once per hour per token.

### ProfileLink

Fields:

- `profile_id`, non-null.
- `link_id`, non-null.
- `position`, integer, non-null.
- Timestamps.

Rules:

- Link and profile user must resolve to the same account.
- Position must be non-negative.
- A link appears once per profile, backed by a unique `[profile_id, link_id]` index.
- Ordering operations must be transactional and produce contiguous positions.

### SocialLink

Fields:

- `profile_id`, non-null.
- `label`, non-null.
- `url`, non-null.
- `position`, integer, non-null.
- Timestamps.

Rules:

- Label length: 1 to 40 characters.
- URL must pass the safe HTTP/HTTPS URL validator.
- Position must be non-negative.
- Limit a profile to 20 social links.

## Shared application operations

The following operations are the reuse boundary between HTML, API, and public entry points.

### `Links::Create`

Signature:

```ruby
Links::Create.call(account:, attributes:, source:)
```

Responsibilities:

- Accept already permitted, protocol-specific attributes.
- Resolve a custom domain only through `account.custom_domains`.
- Normalize name and slug through model behavior.
- Generate a collision-resistant slug when missing.
- If name and slug were both omitted, reuse an existing link for the same account, destination, and custom-domain scope; return an operation-specific result identifying `created?` versus `reused?`.
- If the caller requested a name or slug, create a distinct link.
- Retry a generated-slug unique-index collision a small, bounded number of times.
- Persist tags transactionally.
- Return validation errors on the link without rendering or choosing an HTTP status.

### `Links::Update`

Signature:

```ruby
Links::Update.call(link:, account:, attributes:)
```

Responsibilities:

- Verify through object identity that the supplied link belongs to the supplied account.
- Resolve any custom domain through the account.
- Update link attributes and taggings transactionally.
- Never render or redirect.

### `Links::Resolve`

Signature:

```ruby
Links::Resolve.call(host:, slug:, primary_host:)
```

Responsibilities:

- Normalize the request host safely.
- For the primary host, find a link with no custom domain.
- For another host, require a verified custom domain and find the scoped link.
- Return a link, a custom-domain fallback URL, or a not-found outcome.
- Perform a constant number of indexed database queries.
- Never fetch the destination URL.

### `Visits::Capture`

Split visit processing into two steps:

1. A synchronous payload builder derives the daily digest and privacy-safe metadata while the request exists.
2. A Solid Queue job receives only the derived payload and inserts the visit.

The redirect must not wait for geolocation services, analytics aggregation, or network requests.

### `CustomDomains::Verify`

Signature:

```ruby
CustomDomains::Verify.call(custom_domain:)
```

Responsibilities:

- Query DNS through Ruby's resolver with bounded timeouts.
- Verify the unique TXT ownership challenge and configured routing target.
- Record timestamps and explicit status transitions.
- Be idempotent and safe to retry.
- Return structured failure details suitable for the HTML UI without exposing secrets.

### `CustomDomains::Destroy`

Signature:

```ruby
CustomDomains::Destroy.call(custom_domain:, account:)
```

Responsibilities:

- Require the domain to belong to the supplied account.
- Move its links back to primary-domain scope without losing them.
- Detect primary-domain slug conflicts before changing any link.
- Resolve conflicts deterministically by allocating new generated slugs and report the affected links to the caller.
- Remove the domain and update all affected links in one transaction.

## Controller boundaries

Do not share controllers between formats.

### HTML

`LinksController#create` should:

1. Authenticate the Devise user.
2. Permit HTML form attributes.
3. Call `Links::Create` with `current_user.account` and source `dashboard`.
4. Redirect or render the form with validation errors.

### Authenticated API

`Api::V1::LinksController#create` should:

1. Authenticate a bearer token in `Api::BaseController`.
2. Permit the API contract's attributes.
3. Call `Links::Create` with `current_api_token.account` and source `api`.
4. Return a JSON representation and the correct status.

Use `201 Created` for a newly created link and `200 OK` when an existing link is reused. Use `422` for validation errors, `401` for absent or invalid tokens, and `404` for tenant-scoped records that do not exist.

### Anonymous public shortener

`Public::LinksController#create` should:

1. Return `404` when `PUBLIC_SHORTENER_ENABLED` is false.
2. Apply strict per-IP rate limiting through Rails' controller rate limiting, using a keyed digest of the IP as the cache discriminator rather than persisting the raw IP in a cache key.
3. Permit destination URL only.
4. Call `Links::Create` with `Account.public_shortener` and source `public_shortener`.
5. Return a Turbo Stream/HTML response for the landing page or a small JSON response when explicitly requested.

Input mapping and response formatting may be duplicated because those are intentionally different contracts. Slug generation, duplicate behavior, ownership validation, persistence, and tag behavior must not be duplicated.

Do not:

- Make an API controller inherit from an HTML controller.
- Call one controller from another.
- Put `render`, `redirect_to`, `head`, cookies, sessions, or request objects inside an operation.
- Put business workflows in a controller concern.
- Share a strong-parameters method merely to eliminate a short explicit attribute list.

## Routes and user-facing areas

Use resourceful routes where possible. Required route areas are:

- Marketing home page.
- Terms and privacy pages.
- Devise user routes with friendly `/login` and `/register` aliases.
- Dashboard.
- Links CRUD.
- Per-link QR download.
- Link CSV export.
- Custom domains CRUD plus DNS setup and manual recheck.
- Profile/settings editing.
- API token index, create, and revoke.
- Public profile by username.
- Authenticated API namespace `/api/v1`.
- Optional public shorten endpoint.
- Rails health endpoint `/up`.
- Host-aware `/:slug` redirect route placed last.

Make sure the slug route cannot swallow Active Storage, asset, health, authentication, API, or internal Rails routes. Test the route ordering.

## Hotwire user experience

Implement the UI without client-side business state.

- Use Turbo Frames for link and custom-domain forms where it improves validation feedback.
- Use Turbo Streams to add, update, and remove list rows without reloading the page.
- Use a Stimulus controller for copying short URLs and API tokens.
- Use a debounced Stimulus form submission for search/filter forms, while preserving a fully functional non-JavaScript form submission.
- Use a Stimulus controller plus Chartkick/Chart.js only for chart rendering; render accessible text/table summaries alongside charts.
- Reorder public profile links with accessible up/down controls first. Drag-and-drop may be added later without replacing the server operation.
- Every mutation needs disabled/submitting states and an error state.
- Use proper labels, focus handling, semantic headings, keyboard navigation, sufficient contrast, and responsive layouts.
- Use `data-turbo-method` or Rails button helpers rather than legacy `method:` link behavior.

## Search, filtering, and pagination

Implement explicit query objects rather than Ransack:

- `Links::Search` accepts an account, query text, optional tag, sort direction, and pagination input.
- Search case-insensitively across name, destination URL, and slug.
- Tag filtering must remain account-scoped.
- Whitelist sort columns and directions; never interpolate raw request parameters into SQL.
- Use Pagy according to its installed-version API.
- Preserve query and tag parameters in pagination links.
- Test empty, boundary, malformed-page, and cross-account cases.

## Redirect and analytics behavior

Redirect behavior is critical and must remain small and fast:

1. Normalize host and slug.
2. Resolve the link using indexed queries.
3. Build and enqueue a privacy-safe visit payload only when permitted.
4. Respond with a temporary `302 Found` redirect initially. Make the redirect status configurable only if a demonstrated use case requires permanent redirects.

Tracking is skipped when any of these apply:

- `tracking_enabled` is false.
- Link source is `public_shortener`.
- `DNT: 1` is present.
- `Sec-GPC: 1` is present.
- The user agent is classified as a bot.

Analytics dashboard periods:

- Last 7 days.
- Last 30 days, default.

Required metrics:

- Total visits.
- Unique daily visitors.
- Visits over time in the account's profile timezone.
- Top links.
- Countries.
- Referrer hosts, with blank values displayed as Direct/None.
- Browsers.
- Device types.

Run aggregation in SQL through query objects. Do not load all visits into Ruby to call `tally` or `group_by`.

Add a configurable retention job. Default retention is 90 days. Deleting a link must delete its visits. Deleting a personal account must delete all account-owned data and Active Storage attachments.

## Custom-domain architecture

The open-source core must not call the Heroku Platform API or assume a specific DNS provider.

For each pending domain, show:

- A unique TXT ownership record.
- The required CNAME or A/AAAA routing record configured by deployment settings.
- Current verification status and last checked time.
- A manual "Check again" action.

Also schedule recurring checks through Solid Queue.

The application accepts traffic for a custom host only when the matching domain is verified. Rails host authorization and reverse-proxy configuration must be documented so custom hosts work without accepting arbitrary unsafe host headers.

Document that the deployer must configure TLS and route custom hosts to the Rails service. Provide a manual adapter/configuration path that works with a conventional reverse proxy. Provider-specific automation may be added later behind an interface.

## API contract

Initial authenticated endpoint:

```http
POST /api/v1/links
Authorization: Bearer <token>
Content-Type: application/json
```

Request:

```json
{
  "link": {
    "destination_url": "https://example.com/article",
    "name": "Example article",
    "slug": "example-article",
    "custom_domain_id": 123,
    "tracking_enabled": true,
    "tags": ["docs", "example"]
  }
}
```

Successful representation:

```json
{
  "link": {
    "id": 1,
    "name": "Example article",
    "destination_url": "https://example.com/article",
    "slug": "example-article",
    "short_url": "https://tinyslug.example/example-article",
    "tracking_enabled": true,
    "tags": ["docs", "example"],
    "created_at": "2026-07-15T00:00:00Z"
  }
}
```

Validation failure:

```json
{
  "errors": {
    "destination_url": ["must be an absolute HTTP or HTTPS URL"]
  }
}
```

Do not expose account IDs, token digests, visitor digests, internal verification tokens, or storage keys.

Add an API documentation page with a `curl` example generated from the configured application host. Add request tests that lock the JSON contract.

## Security requirements

- Use default Rails CSRF protection for HTML endpoints.
- Use bearer authentication rather than cookie sessions for API endpoints.
- Use constant-time API-token comparison.
- Filter tokens, passwords, authorization headers, email confirmation tokens, and DNS verification secrets from logs.
- Apply rate limits to login, password reset, token creation, anonymous shortening, and authenticated API creation.
- Derive IP-based rate-limit keys with a dedicated keyed digest. Do not place raw IP addresses in Solid Cache keys, structured events, or application logs.
- Validate request hosts and proxy headers using an explicit trusted-proxy configuration.
- Permit only HTTP/HTTPS destination and fallback URLs.
- Add a Content Security Policy compatible with Importmap, Turbo, Chart.js, and application assets; avoid broad `unsafe-inline` exceptions.
- Never use `html_safe` on user-provided content.
- Render user-provided names, URLs, tags, bios, and labels through Rails escaping.
- Validate uploaded content type and size on both metadata and decoded content where supported.
- Use database foreign keys for every association.
- Handle unique-index races instead of relying only on `validates_uniqueness_of`.
- Do not leak whether a cross-account record exists; respond as not found.

## Configuration contract

Provide `.env.example` for documentation, but do not put secrets or production values in it. The app may load environment variables directly or use Rails credentials.

Document these settings:

- `APP_HOST`: primary host, default `localhost` in development.
- `APP_PROTOCOL`: `http` in development, `https` in production.
- `PUBLIC_SHORTENER_ENABLED`: default false.
- `REDIRECT_VISIT_RETENTION_DAYS`: default 90.
- `VISITOR_DIGEST_SECRET`: required in production and separate from public configuration.
- `API_TOKEN_DIGEST_SECRET`: required in production for keyed API-token digests.
- `RATE_LIMIT_DIGEST_SECRET`: required in production for privacy-safe rate-limit discriminators.
- `CUSTOM_DOMAIN_DNS_TARGET`: routing target displayed to domain owners.
- `CUSTOM_DOMAIN_TXT_PREFIX`: default `_tinyslug-verification`.
- `DATABASE_URL`: production database connection.
- Standard Rails secret and Active Storage configuration.
- Optional SMTP settings.
- Optional S3-compatible storage settings.
- Optional path to a local GeoIP database.

Fail fast at production boot when required production secrets or host settings are absent. Development and test must have safe deterministic defaults.

## Implementation phases and required validation

### Phase 0: Scaffold and contributor foundation

Implement:

- Rails/mise scaffold.
- PostgreSQL configuration.
- A `compose.yaml` development PostgreSQL service using a pinned major image, health check, and named volume, plus native-PostgreSQL instructions.
- Tailwind, Turbo, Stimulus, Propshaft, Importmap.
- Solid Queue, Cache, and Cable migrations/configuration.
- `/up` health endpoint.
- Marketing home, terms, and privacy pages.
- `README.md`, `.env.example`, `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, and code of conduct.
- Use the MIT license for widest reuse unless the repository owner selects another OSI-approved license before public release.
- GitHub Actions CI using PostgreSQL.
- `bin/ci` as the single local and CI validation entry point.

Tests:

- Health request returns 200.
- Marketing, terms, and privacy pages render.
- Production asset precompilation succeeds.

Validation gate:

```sh
mise install
mise exec -- bin/setup
mise exec -- bin/rails db:prepare
mise exec -- bin/rails test
mise exec -- bin/rails zeitwerk:check
mise exec -- bin/rubocop
mise exec -- bin/brakeman --no-pager
mise exec -- bin/importmap audit
mise exec -- env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

### Phase 1: Authentication, accounts, and profiles

Implement:

- Account, User, and Profile models and constraints.
- Atomic registration setup.
- Devise registration, confirmation, sessions, remember-me, password recovery, and account update flows.
- Profile editing, timezone, avatar upload/removal, and account deletion.
- Authenticated dashboard shell and navigation.
- Direct account scoping helpers without a policy framework.

Tests:

- Model validation and database-constraint tests.
- Registration success and rollback on associated-record failure.
- Duplicate email and case-insensitive username behavior.
- Reserved usernames.
- Confirmation, login, logout, password reset, and remember-me request/system flows.
- Avatar type and size failures.
- Account deletion removes owned data once later resources exist.

Validation gate: run all global validation commands plus a browser-backed system test of registration through dashboard access.

### Phase 2: Link management and redirects

Implement:

- Link, Tag, and Tagging models.
- Safe URL validator.
- `Links::Create`, `Links::Update`, and `Links::Resolve`.
- Link CRUD, Turbo forms/streams, search, tags, sorting, and pagination.
- Copy-to-clipboard Stimulus behavior.
- QR SVG/PNG download.
- CSV export.
- Primary-host redirect route.
- Optional public shortener behind configuration and rate limits.

Tests:

- Every Link, Tag, and Tagging validation listed above.
- Database uniqueness constraints for primary and custom-domain slug scopes.
- Generated-slug collision retry and bounded failure.
- Duplicate reuse behavior.
- Requested slug creates a distinct record.
- Unsafe schemes, malformed URLs, userinfo, oversized URLs, reserved slugs, and invalid tags.
- Cross-account show, edit, update, destroy, export, and QR requests return 404.
- Redirect success and not-found behavior.
- Redirect performs no outbound HTTP request.
- Public links are uneditable, untracked, custom-domain-free, and rate limited.
- CSV escaping for commas, quotes, newlines, and spreadsheet-formula prefixes.
- Turbo system flow for create, validation failure, update, filter, and delete.

Validation gate: all global checks plus a real development-server smoke test that creates a link and follows its redirect.

### Phase 3: Authenticated API

Implement:

- ApiToken model and one-time token display.
- Token index/create/revoke UI.
- API base controller authentication.
- `POST /api/v1/links` using `Links::Create`.
- Jbuilder/plain Ruby representation.
- API documentation page.

Tests:

- Token generation, digest-only persistence, prefix display, revocation, and throttled last-used update.
- Missing, malformed, unknown, and revoked token responses.
- API success, reuse, validation failure, and custom-domain ownership behavior.
- JSON contract does not expose sensitive/internal fields.
- A shared `Links::Create` test suite proves HTML, API, and public controllers do not independently implement creation rules.

Validation gate: all global checks plus executable `curl` smoke tests against a test/development server.

### Phase 4: Privacy-aware analytics

Implement:

- Visit model and privacy-safe payload builder.
- Solid Queue visit-recording job.
- Bot, DNT, and GPC exclusions.
- Optional trusted country header/local GeoIP adapter.
- Analytics query objects and dashboard.
- 7/30-day periods, accessible charts/tables, top links, countries, referrers, browsers, and devices.
- Retention job and recurring schedule.

Tests:

- No raw IP or user-agent is persisted or serialized into a job.
- Digest determinism within one UTC day and rotation across days.
- Tracking opt-out, public-link, bot, DNT, and GPC exclusions.
- Referrer strips path/query/fragment.
- Unknown country/device data degrades gracefully.
- Job retry does not corrupt data.
- Aggregations respect account, link, period, timezone, and unique-visit definitions.
- Cross-account analytics requests return 404.
- Retention deletes only expired visits.

Validation gate: all global checks plus a running Solid Queue worker smoke test proving a redirect enqueues and persists one derived visit.

### Phase 5: Custom domains

Implement:

- CustomDomain model and constraints.
- Domain CRUD and DNS instruction UI.
- `CustomDomains::Verify` and recurring verification job.
- Manual recheck action with rate limiting.
- Host-aware `Links::Resolve` integration.
- Custom-domain fallback behavior.
- Deployment documentation for DNS, TLS, Rails host authorization, and trusted proxies.

Tests:

- Every hostname and fallback URL validation listed above.
- Case-insensitive uniqueness and normalization.
- Cross-account access and link association failures.
- DNS success, failure, timeout, retry, and idempotency with deterministic resolver fakes.
- Unverified hosts never resolve links.
- Verified host plus slug resolves only that domain's links.
- Same slug may exist on different custom domains.
- Missing slug uses safe fallback or local 404.
- Deleting a domain keeps links and returns them to primary-domain scope only after resolving any slug collisions transactionally.

Validation gate: all global checks plus local host-header request tests exercising primary, verified custom, unverified, and unknown hosts.

### Phase 6: Public profiles

Implement:

- ProfileLink and SocialLink models.
- Public-profile editing and enable/disable control.
- Add/remove/reorder selected links.
- Add/remove/reorder social links.
- Public profile at the user's username.
- Open Graph and standard metadata without leaking private data.

Tests:

- Ownership, uniqueness, position, URL, count-limit, and ordering validations.
- Disabled and unknown profiles return 404.
- Cross-account links cannot be attached.
- Reordering remains contiguous and transactional.
- Public pages expose selected links only.
- Public profile system test works with and without JavaScript.

Validation gate: all global checks plus accessibility-focused system tests for keyboard navigation and form errors.

### Phase 7: Operational hardening and release readiness

Implement:

- Final CSP and secure headers.
- Log filtering and structured Rails events.
- SMTP and S3-compatible configuration documentation.
- Production Docker/Kamal documentation.
- Backup, restore, job worker, recurring job, and custom-domain runbooks.
- Seed data that is safe, idempotent, and works in development.
- Error pages for 404, 422, 429, and 500.
- Dependency update policy and security reporting process.

Tests and checks:

- Fresh clone setup from scratch.
- CI on a clean database.
- Production boot and assets.
- Seed replant in test.
- Full system suite.
- Redirect query count and performance smoke test.
- No secrets or real credentials in tracked files.
- All routes have an intentional authentication/public-access decision.
- All foreign keys and indexes exist.
- `bin/rails db:prepare` works idempotently.

Final validation gate:

```sh
mise install
mise exec -- bin/setup
mise exec -- bin/ci
mise exec -- env RAILS_ENV=test bin/rails db:seed:replant
mise exec -- env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
mise exec -- env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner 'puts Rails.application.class.module_parent_name'
```

Start the application and job worker through their documented commands, then verify:

- `/up` returns 200.
- Registration and confirmation work with the development mail-delivery method.
- A user can create and redirect a link.
- Tracking-disabled redirects produce no visit.
- Tracking-enabled redirects enqueue and persist a privacy-safe visit.
- API token creation exposes the secret once and API link creation works.
- Public shortening is unavailable by default and works when enabled.
- A verified custom host resolves the correct link in host-header integration tests.
- A public profile displays only selected links.

## Test organization

Use Rails' default Minitest organization:

```text
test/
  controllers/
  fixtures/
  jobs/
  mailers/
  models/
  operations/
  queries/
  system/
  validators/
```

Testing rules:

- Prefer fixtures and explicit records over factories unless repeated setup becomes materially clearer with a factory library.
- Test validation success and failure, but rely on request/system tests for user-visible workflows.
- Test database constraints directly where they protect concurrency or integrity.
- Use deterministic time helpers for analytics and token timestamps.
- Stub at provider/network boundaries, not internal application methods.
- Do not use recorded cassettes containing external credentials or unstable third-party data.
- Run narrow tests during implementation, followed by the complete suite at every phase gate.
- Do not weaken a validation, security check, or assertion merely to make a test pass.
- Track coverage if useful, but do not substitute a percentage target for meaningful behavioral tests.

## Optional legacy import contract

Do not implement or claim a production migration without a supplied legacy database or representative export. When legacy data becomes available, create idempotent namespaced import tasks with dry-run and batch options.

Expected mappings:

- Legacy users and account/profile fields -> User, personal Account, and Profile.
- Legacy links -> Link, preserving destination, name, slug, custom domain, and timestamps.
- Legacy `no_tracking` -> new `tracking_enabled` with the boolean inverted.
- Legacy custom domains -> CustomDomain; import known connected domains as pending unless ownership/routing can be reverified safely.
- Legacy tags/taggings -> account-scoped Tag and Tagging.
- Legacy link visits -> Visit, preserving only privacy-safe derived fields. Mark legacy visitor digests as legacy and do not use them for new cross-day identification.
- Legacy API keys -> ApiToken digest so existing client secrets can continue working without storing plaintext.
- Legacy account/public-profile/social fields -> Profile, ProfileLink, and SocialLink.
- Legacy Active Storage blobs/attachments -> new Profile avatar attachment while preserving service keys and checksums when the storage service remains available.
- Ignore all legacy plans, `pay_*` tables, billing fields, trials, subscriptions, coupons, AppSumo data, notifications, and admin users.

Each importer must:

- Be safe to rerun.
- Preserve source IDs in a dedicated mapping table or deterministic mapping record rather than forcing primary keys unless necessary for URL compatibility.
- Process batches with progress reporting.
- Avoid callbacks that send mail or create analytics.
- Produce counts for imported, skipped, failed, and reconciled records.
- Reconcile foreign keys, record counts, sampled URLs, and duplicate slug/domain conflicts.
- Include tests with representative legacy fixtures before touching production data.

## Definition of complete

The rebuild is complete only when all of the following are true:

- A new contributor can clone the project and run `mise install`, `bin/setup`, and `bin/dev` without undocumented dependencies.
- The app runs on Ruby 4.0.6 and Rails 8.1.3.
- The finished features above work through their closest user-facing workflows.
- HTML, API, and public link creation share the same operations and business tests.
- Cross-account resource access is impossible through normal requests and covered by tests.
- Redirects perform only indexed database work plus non-blocking enqueueing.
- No redirect path performs external network I/O.
- No raw visitor IP is stored or enqueued.
- Payments, roles, admin features, and authorization frameworks are absent.
- Public shortening is disabled by default and safe to enable.
- The full test, lint, security, eager-load, database, asset, and production-boot validations pass.
- Documentation accurately describes configuration, self-hosting, privacy behavior, custom-domain responsibilities, background jobs, backups, and contribution workflow.

## Handoff requirements

At the end of every implementation phase, report:

1. User-visible behavior completed.
2. Schema and architectural decisions made.
3. Tests added.
4. Exact validation commands run and their results.
5. Anything not verified and why.
6. Known risks or follow-up items, without silently expanding scope.

The implementer should stop and request direction only when a decision would materially change this product contract, require an external paid service, weaken a security/privacy requirement, or require destructive handling of existing user data.
