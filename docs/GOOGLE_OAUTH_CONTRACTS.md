# Google/Gmail OAuth Configuration Contracts

This document defines the backend contract for the next Gmail authorization
work. It does not implement the real OAuth flow.

## Flow separation

Email Filter authentication and Gmail authorization are separate:

- Supabase Auth logs the user into Email Filter.
- The backend resolves the authenticated user to `public.profiles`.
- Google OAuth authorizes one Gmail or Google Workspace mailbox for that
  already-authenticated profile.
- The login account must not be automatically inserted into
  `public.gmail_connections`.

## Configuration

The backend accepts these optional settings:

- `GOOGLE_OAUTH_ENABLED`
- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`
- `GOOGLE_OAUTH_REDIRECT_URI`
- `GOOGLE_OAUTH_SUCCESS_REDIRECT_URL`
- `GOOGLE_OAUTH_ERROR_REDIRECT_URL`
- `GOOGLE_OAUTH_FRONTEND_REDIRECT_ALLOWLIST`
- `GOOGLE_OAUTH_STATE_TTL_SECONDS`
- `GMAIL_OAUTH_SCOPES`

OAuth is available only when the explicit flag is enabled and client ID,
client secret, backend redirect URI, success URL, and error URL are all set.
Incomplete configuration fails closed only when OAuth is requested; unrelated
endpoints such as health continue to work without OAuth configuration.

The client secret uses Pydantic `SecretStr` and must not be logged, returned by
an API response, or included in public contracts.

OAuth state lifetime defaults to 600 seconds. Configuration must remain between
300 and 900 seconds.

## Scopes

The canonical MVP scopes are centralized in
`apps/server/app/integrations/google/oauth_scopes.py`:

- `openid`
- `https://www.googleapis.com/auth/userinfo.email`
- `https://www.googleapis.com/auth/userinfo.profile`
- `https://www.googleapis.com/auth/gmail.readonly`

These scopes support account identification, account e-mail, optional display
profile data, search, message reads, metadata, and on-demand attachment access.
They do not allow sending, modifying, deleting, labeling, inserting, or
configuring Gmail messages.

## Redirect handling

The backend callback URI must be the configured
`GOOGLE_OAUTH_REDIRECT_URI`. Future endpoints must not accept a client-supplied
OAuth redirect URI.

Frontend success and error return URLs are configured values. If
`GOOGLE_OAUTH_FRONTEND_REDIRECT_ALLOWLIST` is set, the success and error URLs
must match it exactly as strings. This avoids open redirects and avoids unsafe
normalization that could make distinct URLs equivalent.

## State and CSRF strategy

The `state` parameter must be:

- high entropy;
- single-use;
- short-lived;
- bound to the authenticated `profile_id`;
- bound to the allowed return URL;
- protected against replay;
- stored server-side or represented by a signed format compatible with
  multiple backend instances.

The backend generates 32 random bytes with the standard library `secrets`
module and sends the raw state only through the OAuth redirect flow. The
database persists only a SHA-256 hex hash of that value in
`public.google_oauth_states`; the raw state is not stored and the result object
redacts it from `repr`.

`public.google_oauth_states` binds each state to `public.profiles(id)` and to
one already-allowed return URL. The FK uses `ON DELETE CASCADE` so deleting a
profile removes unused or consumed state rows for that profile. This matches
the existing profile-owned Gmail connection behavior.

The PostgreSQL adapter uses the database clock for persisted creation,
expiration, and consumption timestamps. The backend validates the configured
TTL range, but the final expiration decision during consumption is made with
`pg_catalog.now()` in PostgreSQL to reduce backend/database clock-skew risk.

State consumption is atomic:

```sql
update public.google_oauth_states
   set consumed_at = pg_catalog.now()
 where state_hash = :state_hash
   and profile_id = :profile_id
   and return_url = :return_url
   and consumed_at is null
   and expires_at > pg_catalog.now()
returning profile_id, return_url, consumed_at;
```

The second consume attempt returns no row and is treated as replay. Expired,
missing, already consumed, profile-mismatched, and return-mismatched states map
to internal errors; a future public callback should collapse those details into
a generic user-facing failure.
Unexpected persistence failures are wrapped in a sanitized internal
`OAuthStatePersistenceError` while preserving the original exception as the
Python cause for backend diagnostics. Public responses must not expose SQL,
parameters, state hashes, or raw state values.

RLS is enabled and no policies or table privileges are granted to `anon` or
`authenticated`. Server-side backend access must use a privileged database path,
not the browser Data API. Cleanup deletes expired rows and old consumed rows;
future worker or maintenance code should call it periodically. No cron or
remote scheduler is configured in this stage.

## Internal contracts

The backend now has typed models for:

- an authenticated profile resolved before Gmail authorization;
- an OAuth start request;
- a durable state contract;
- repository contracts for creating, consuming, and cleaning OAuth state;
- a Google callback that contains either `code` or `error`;
- a post-exchange connection result with Google subject, e-mail, optional name
  and avatar, granted scopes, and initial connection status.

No public or internal model in this stage contains access token, refresh token,
or token response fields.

## Out of scope in this stage

This stage does not:

- generate a real Google authorization URL;
- add callback endpoints;
- exchange authorization codes;
- call Google APIs;
- encrypt tokens;
- persist tokens;
- write to `public.gmail_connections`;
- implement PKCE verifier storage;
- persist OAuth nonce values.

PKCE verifier ciphertext and nonce storage are intentionally omitted because
this step does not yet create the real authorization URL, ID-token validation,
or callback exchange path. Add those fields only with the concrete flow that
uses them.

The next task should perform independent review/runtime validation of the state
migration, then implement the authorization URL and callback flow using the
durable repository.
