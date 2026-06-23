# Supabase / Database
- **Objective**: Persistence layer for user profiles, connections, filters, and jobs.
- **Responsibility**: Schema management and Row Level Security (RLS).
- **Planned Tech**: PostgreSQL via Supabase.
- **Out of Scope**: Application business logic.
- **Status**: Initial identity foundation implemented and validated in a
  disposable development/staging Supabase project. Do not reapply the migration
  in a database where it has already succeeded.

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

## Validation status

The manual validation script is
[`tests/profiles_rls_validation.sql`](tests/profiles_rls_validation.sql). Run it
only against a disposable local or staging Supabase database after creating the
two test users described in the file. The script is plain SQL and can be run as
one complete operation in `psql` or as a manual Supabase SQL Editor paste after
replacing the placeholder Auth user UUIDs in the local execution copy. It
requires an administrative database session, ends with `ROLLBACK`, and does not
reapply the migration.

The main runtime validation passed in a non-production staging project for
schema, constraints, backfill, profile creation, missing metadata, `updated_at`,
RLS, policies, grants, immutable fields, `anon` blocking, function execution
blocking, idempotent backfill, and cascade deletion. The manual Dashboard user
creation flow did not persist user metadata, so valid metadata fallback still
requires a complementary Auth signup/Admin API validation that writes
`raw_user_meta_data`.
Supabase client APIs call this input `user_metadata` or `options.data`; the
database stores it as `auth.users.raw_user_meta_data`.

Remove the two disposable Auth users manually after validation; their profiles
are removed by cascade. If an assertion stops execution, reset the disposable
database or remove the fixtures manually before retrying.

For metadata validation, prefer an official Supabase Auth flow that creates a
disposable user after the migration with `user_metadata`:

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
