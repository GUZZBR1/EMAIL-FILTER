# Supabase / Database
- **Objective**: Persistence layer for user profiles, connections, filters, and jobs.
- **Responsibility**: Schema management and Row Level Security (RLS).
- **Planned Tech**: PostgreSQL via Supabase.
- **Out of Scope**: Application business logic.
- **Status**: Initial identity foundation implemented locally; the migration has not
  been applied to a remote Supabase project.

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
only against a disposable local Supabase database after creating the two test
users described in the file. The script requires an administrative database
session and removes both disposable users after a successful validation.
If an assertion stops execution, reset the disposable database or remove the
two fixtures manually before retrying.
Database execution is pending because this environment does not provide
Docker, Supabase CLI, or a local PostgreSQL instance. No remote migration was
applied.
