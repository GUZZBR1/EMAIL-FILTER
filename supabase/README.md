# Supabase / Database
- **Objective**: Persistence layer for user profiles, connections, filters, and jobs.
- **Responsibility**: Schema management and Row Level Security (RLS).
- **Planned Tech**: PostgreSQL via Supabase.
- **Out of Scope**: Application business logic.
- **Status**: Initial identity foundation and Gmail connection schema
  implemented and validated in a disposable development/staging Supabase
  project. Do not reapply a migration in a database where it has already
  succeeded.

## Identity foundation

Supabase Auth owns login identity in `auth.users`. The application domain uses
`public.profiles`, with one profile per authenticated user. `profiles.id` is an
independent domain UUID and `profiles.auth_user_id` is the unique foreign key to
`auth.users.id`.

Keeping the identifiers separate reduces coupling to the authentication
provider, distinguishes authentication identity from domain identity, permits
future identity-provider changes, and gives future domain entities a stable
profile identifier to reference. E-mail addresses are not copied into
`public.profiles` and are not authorization keys.

An `AFTER INSERT` trigger on `auth.users` creates the profile automatically. It
copies only a display name (`full_name`, then `name`) and avatar URL
(`avatar_url`, then `picture`), treating missing or blank values as `null`.
The migration also performs an idempotent backfill for Auth users that already
exist when it is applied.
Deleting the Auth user deletes the associated profile through `ON DELETE
CASCADE`.

RLS permits authenticated users to select and update only their own row.
Table privileges restrict updates to `display_name` and `avatar_url`; `id`,
`auth_user_id`, and `created_at` are immutable to clients, while `updated_at`
is maintained by a database trigger. The `anon` role receives no table access.
RLS is intentionally enabled without `FORCE ROW LEVEL SECURITY`: client roles
are neither table owners nor `BYPASSRLS` roles, while privileged database
maintenance remains an explicit administrative boundary.
Backend code must still validate authenticated identity and resource ownership
when API integration is implemented.

## Gmail connection foundation

Login identity and Gmail authorization remain separate. `auth.users` and
`public.profiles` identify the Email Filter user, while
`public.gmail_connections` represents one authorized Gmail or Google Workspace
mailbox connected to a profile.

Each connection has its own internal UUID and belongs to
`public.profiles(id)` with `ON DELETE CASCADE`, so deleting a profile removes
its Gmail connections. The stable Google identity is stored in
`google_subject`, based on Google's `sub` claim. E-mail is stored separately as
display data and as a generated lowercase normalized value; it is not the
primary identity because Gmail/Workspace addresses can change.

The table enforces uniqueness on `(profile_id, google_subject)`. This prevents
the same profile from connecting the same Google account twice. There is no
global unique constraint on `google_subject`: a future backend OAuth flow must
decide whether a Google account can be linked to another profile based on the
completed consent flow and product rules. Reconnection should update/reactivate
the existing row for the profile instead of inserting a duplicate row.

Connection states are represented by `connection_status text` with a check
constraint for:

- `connected`
- `revoked`
- `blocked_by_workspace_admin`
- `expired`
- `refreshing`
- `disconnected`

Text plus a check constraint keeps the allowed values explicit while avoiding
the heavier migration path of PostgreSQL enums during early schema evolution.
The safe default is `disconnected`; future backend OAuth code may insert or
transition a row to `connected` only after OAuth completion.

The initial technical limit of five active connections per profile is enforced
by a database trigger for rows in `connected` or `refreshing`. The trigger uses
a per-profile advisory transaction lock to avoid obvious concurrent inserts or
reactivations crossing the limit. It reads the optional transaction/session
setting `app.gmail_connections_active_limit` and falls back to `5`, so future
backend code can set the value from environment configuration without storing
plan data in the database. This is a technical MVP guard, not a commercial plan
system.

OAuth token columns are intentionally not present in this migration. The
specification requires encrypted token storage, but the encryption design,
key management, refresh flow, and backend-only token handling are separate
tasks. No plaintext access token, refresh token, provider payload, or OAuth
metadata blob should be added to this table.

RLS allows authenticated users to read only connections that belong to their
own profile through the ownership chain
`auth.uid() -> profiles.auth_user_id -> gmail_connections.profile_id`.
Client roles receive no `INSERT`, `UPDATE`, or `DELETE` privileges. All Gmail
connection mutations are reserved for future backend server-side code after
OAuth and ownership validation.

## Validation status

The manual validation script is
[`tests/profiles_rls_validation.sql`](tests/profiles_rls_validation.sql). Run it
only against a disposable local or staging Supabase database after creating the
two test users described in the file. The script is plain SQL and can be run as
one complete operation in `psql` or as a manual Supabase SQL Editor paste after
replacing the placeholder Auth user UUIDs in the local execution copy. It
requires an administrative database session, ends with `ROLLBACK`, and does not
reapply the migration.

The profile runtime validation passed in a non-production staging project for
schema, constraints, backfill, profile creation, missing metadata, `updated_at`,
RLS, policies, grants, immutable fields, `anon` blocking, function execution
blocking, idempotent backfill, cascade deletion, and valid metadata fallback
through an official Supabase Auth Admin API flow.
Supabase client APIs call this input `user_metadata` or `options.data`; the
database stores it as `auth.users.raw_user_meta_data`.

Remove the two disposable Auth users manually after validation; their profiles
are removed by cascade. If an assertion stops execution, reset the disposable
database or remove the fixtures manually before retrying.

For profile metadata validation, prefer an official Supabase Auth flow that
creates a disposable user after the migration with `user_metadata`:

```json
{
  "full_name": "Profile Validation Metadata",
  "avatar_url": "https://example.invalid/profile-validation.png"
}
```

Do not store service role keys, anon keys, URLs, e-mails, UUIDs, passwords, or
connection strings in this repository or in shell history. If using an Admin API
helper, run it as a temporary local script outside the repository and enter any
key through a hidden prompt.

The Gmail connection validation script is
[`tests/gmail_connections_rls_validation.sql`](tests/gmail_connections_rls_validation.sql).
It has passed in a disposable staging project for schema, RLS, grants and
revokes, triggers, active connection limits, cascade behavior, and isolation
between users.
