# Operations

This runbook covers a conventional single-region deployment. Tinyslug does not provision DNS or TLS and does not require a specific hosting provider.

## Production configuration

Set `APP_HOST`, `APP_PROTOCOL=https`, `DATABASE_URL`, `SECRET_KEY_BASE` (or `RAILS_MASTER_KEY`), and independent random values for `VISITOR_DIGEST_SECRET`, `API_TOKEN_DIGEST_SECRET`, and `RATE_LIMIT_DIGEST_SECRET`. Generate each digest secret with `openssl rand -hex 32`. Keep all values in the deployment platform's secret store, never in tracked files.

Set `TRUSTED_PROXY_CIDRS` only to networks controlled by the operator. The application trusts country data only from `TRUSTED_COUNTRY_HEADER`, so the reverse proxy must remove any client-supplied header with that name and set its own value. Leave the setting blank otherwise.

Run `mise exec -- env RAILS_ENV=production bin/rails db:prepare` before serving traffic. The production database configuration uses separate PostgreSQL databases for primary records, Solid Cache, Solid Queue, and Solid Cable.

## Email

Confirmation and password reset require SMTP in production. Set `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_DOMAIN`, `SMTP_AUTHENTICATION`, and `SMTP_ENABLE_STARTTLS_AUTO`. Delivery is disabled when `SMTP_ADDRESS` is blank so the application can boot without a mail provider; do not invite users until delivery has been tested.

Use a dedicated sender/domain with SPF, DKIM, and DMARC. Verify a registration and password reset from the deployed host after changing SMTP configuration.

## Web and workers

Run the web process with `bin/rails server` (the container's default command) and at least one independent `bin/jobs` process. Solid Queue reads `config/recurring.yml` in production and schedules visit retention daily and custom-domain verification every 30 minutes.

Health checks should request `/up` on the primary host. Monitor web and worker exits, queue depth, job failures, mail failures, database connections, storage capacity, and HTTP 5xx/429 rates. Rails emits privacy-safe structured events named `tinyslug.link.*`, `tinyslug.visit.recorded`, and `tinyslug.custom_domain.checked`; attach an event reporter subscriber appropriate to the deployment.

## Docker and Kamal

The generated `Dockerfile` builds the production image. Before using `config/deploy.yml`, replace the example IP, registry, image name, and `APP_HOST`; put all listed secrets in `.kamal/secrets`. The sample defines separate web and job roles. Deploy with `mise exec -- bin/kamal setup` initially and `mise exec -- bin/kamal deploy` thereafter.

After a deploy, verify `/up`, sign-in, one non-tracking redirect, an enqueued tracking redirect, and worker consumption. Roll back with Kamal's documented rollback command for the installed version; never roll back the database blindly after a destructive migration.

## Custom domains, DNS, and TLS

Set `CUSTOM_DOMAIN_DNS_TARGET` to the hostname or IP routed to the service. A domain owner must publish both records displayed in the UI:

1. TXT at `<CUSTOM_DOMAIN_TXT_PREFIX>.<hostname>` containing the unique ownership token.
2. CNAME, A, or AAAA for the hostname pointing to `CUSTOM_DOMAIN_DNS_TARGET`.

The app accepts a custom `Host` only after both records verify. DNS may take time to propagate; use the manual Check again action or wait for the recurring sweep. The reverse proxy or hosting platform must issue/renew TLS certificates and route the host to Rails. Configure it to preserve `Host` and overwrite forwarded client-IP headers. Never use a catch-all host rule without Rails host authorization.

Removing a custom domain returns its links to the primary host. Colliding slugs receive deterministic numeric suffixes in one transaction.

## Backups and restore

Back up the primary PostgreSQL database with the provider's snapshot feature or `pg_dump --format=custom --no-owner --file=tinyslug.dump "$DATABASE_URL"`. Cache and Cable data are disposable; queue data should be included when pending jobs must survive a disaster.

Test restores regularly in an isolated environment:

1. Provision empty databases with no production network access.
2. Restore with `pg_restore --clean --if-exists --no-owner --dbname="$RESTORE_DATABASE_URL" tinyslug.dump`.
3. Run `RAILS_ENV=production bin/rails db:prepare` against the restored database.
4. Reconcile user, link, domain, and visit counts and sample short URLs.
5. Rotate secrets if the backup or credentials may have been exposed.

Do not point a restore exercise at production. Record recovery-point and recovery-time objectives appropriate to the deployment.

## Incident basics

For elevated 429s, inspect rate-limit traffic and proxy trust before increasing limits. For redirect failures, check host authorization, domain verification, and the indexed link lookup; redirects never perform destination HTTP requests. For missing analytics, confirm tracking is enabled, privacy headers/bot filtering do not exclude the request, and `bin/jobs` is consuming the default queue. For a suspected privacy incident, preserve relevant privacy-safe logs, rotate digest/token secrets as appropriate, and follow `SECURITY.md`.
