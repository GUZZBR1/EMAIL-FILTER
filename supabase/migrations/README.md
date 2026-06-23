# Migrations
- **Objective**: Version-controlled schema changes.
- **Responsibility**: SQL scripts for creating and altering tables, views, and RLS policies.
- **Planned Tech**: SQL.
- **Status**: The initial profile and RLS migration is versioned locally and
  has been applied and validated in a disposable development/staging Supabase
  project. It must not be reapplied in the same database.

## Current migrations

- `20260623135819_create_profiles.sql`: creates `public.profiles`, its
  relationship to `auth.users`, automatic profile creation, automatic
  backfill for existing Auth users, automatic `updated_at`, initial RLS
  policies, and least-privilege grants.

Migrations in this directory are production schema changes. Manual validation
scripts belong in `supabase/tests/` and must not be moved into this directory.

## Validation

When a disposable local or staging Supabase database is available:

1. Start the local Supabase stack or open the Supabase SQL Editor for the
   disposable staging project.
2. Before applying the profile migration, create disposable user B as
   described in `supabase/tests/profiles_rls_validation.sql`.
3. Apply the local database migrations, then create disposable user A.
4. Using an administrative database session, execute the whole
   `supabase/tests/profiles_rls_validation.sql` file in one operation after
   replacing the placeholder Auth user UUIDs in the local execution copy:
   - `psql`: run an untracked edited copy with `psql -v ON_ERROR_STOP=1 -f`.
   - SQL Editor: paste the complete file, replace the placeholders in the
     editor, and run it once.
5. Confirm every assertion succeeds and the validation transaction rolls back.
6. Remove both disposable Auth users manually. Their profiles must be removed
   by cascade.

If validation stops on an assertion, reset the disposable database or remove
the two test users manually before retrying.

Do not use the validation script against production users or treat it as a
migration.

The main validation has passed in staging. The valid-metadata branch remains a
separate complementary check because Dashboard-created users did not persist
the metadata values; use an official Supabase Auth signup or Admin API flow
that writes API-side `user_metadata`/`options.data`, stored in PostgreSQL as
`auth.users.raw_user_meta_data`, without storing keys or credentials in the
repository.
