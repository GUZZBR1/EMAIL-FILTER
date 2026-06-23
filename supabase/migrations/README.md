# Migrations
- **Objective**: Version-controlled schema changes.
- **Responsibility**: SQL scripts for creating and altering tables, views, and RLS policies.
- **Planned Tech**: SQL.
- **Status**: The initial profile and RLS migration is versioned locally and has
  not been applied to a remote Supabase project.

## Current migrations

- `20260623135819_create_profiles.sql`: creates `public.profiles`, its
  relationship to `auth.users`, automatic profile creation, automatic
  backfill for existing Auth users, automatic `updated_at`, initial RLS
  policies, and least-privilege grants.

Migrations in this directory are production schema changes. Manual validation
scripts belong in `supabase/tests/` and must not be moved into this directory.

## Validation

When a disposable local Supabase database is available:

1. Start the local Supabase stack.
2. Before applying the profile migration, create disposable user B as
   described in `supabase/tests/profiles_rls_validation.sql`.
3. Apply the local database migrations, then create disposable user A.
4. Execute `supabase/tests/profiles_rls_validation.sql` with `psql`.
5. Confirm every assertion succeeds and the final transaction rolls back.

Do not use the validation script against production users or treat it as a
migration.
