# Security policy

Please report suspected vulnerabilities privately to the repository maintainers instead of opening a public issue. Include reproduction steps, affected versions, and likely impact without including real user data or credentials.

Maintainers will acknowledge a report within five business days, investigate it, and coordinate disclosure. Do not include production secrets, raw visitor data, or credentials in a report.

Supported releases receive dependency and application security fixes. Bundler, Importmap, Brakeman, and dependency audits run in CI. Automated dependency pull requests run weekly; security fixes should be reviewed and released promptly, while routine updates may be grouped into a scheduled maintenance release. Self-hosters should also keep Ruby, Rails, PostgreSQL, reverse proxies, and container images current.
