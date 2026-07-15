# Route access decisions

Every application route belongs to one of these intentional access classes.

| Route area | Access decision |
| --- | --- |
| `/`, `/terms`, `/privacy`, `/api/docs`, `/up` | Public, read-only |
| `/login`, `/logout`, `/register`, `/password/*`, `/confirmation/*` | Public Devise session/account workflow; mutations retain CSRF protection and rate limits where applicable |
| `/dashboard`, `/profile`, `/profile_links`, `/social_links` | Confirmed session; records are scoped through the current user/profile/account |
| `/links`, `/analytics`, `/custom_domains`, `/api_tokens` | Confirmed session; account-owned records are loaded through `current_user.account` |
| `/api/v1/links` | Public at the router, authenticated solely with a bearer API token; cookie sessions are not accepted |
| `/shorten` | Public only when `PUBLIC_SHORTENER_ENABLED=true`; privacy-safe IP-derived rate limiting; disabled by default |
| `/u/:username` | Public, read-only, and returns 404 unless the profile opted in |
| `/:slug` | Public host-aware redirect; last route by design; tracking remains opt-in |
| `/rails/active_storage/*` | Rails-managed signed/blob routes; attachment mutation occurs only through authenticated profile update |

Verified custom hosts are admitted by production Host Authorization. Unknown and unverified hosts are rejected before routing.
