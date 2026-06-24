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
- `GMAIL_OAUTH_SCOPES`

OAuth is available only when the explicit flag is enabled and client ID,
client secret, backend redirect URI, success URL, and error URL are all set.
Incomplete configuration fails closed only when OAuth is requested; unrelated
endpoints such as health continue to work without OAuth configuration.

The client secret uses Pydantic `SecretStr` and must not be logged, returned by
an API response, or included in public contracts.

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

This stage defines `GoogleOAuthStateContract` only. It intentionally does not
create an in-memory state store because that would fail in multi-instance
deployments. If the next implementation chooses server-side persistence, it
should add a dedicated migration for OAuth state.

## Internal contracts

The backend now has typed models for:

- an authenticated profile resolved before Gmail authorization;
- an OAuth start request;
- a durable state contract;
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
- add database migrations.

The next task should implement durable OAuth `state` persistence and then the
authorization URL/callback flow.
