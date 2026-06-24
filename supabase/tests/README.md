# Supabase validation scripts

This directory contains manual validation scripts. They are not production
migrations and must only run against disposable local or staging projects.

## `profiles_rls_validation.sql`

Validates the `public.profiles` migration after it has been applied once.
Do not run the migration again in the same database.

Required fixtures:

1. Before applying the migration, create disposable user B without metadata.
   The migration backfill must create this user's profile.
2. Apply `supabase/migrations/20260623135819_create_profiles.sql`.
3. After applying the migration, create disposable user A through Supabase Auth
   with metadata equivalent to:

   ```json
   {
     "full_name": "Profile Validation A",
     "avatar_url": "https://example.invalid/original-avatar-a.png"
   }
   ```

The script contains placeholder UUIDs for both users. Replace those placeholder
values only in your local execution copy or SQL Editor paste. Do not commit real
Auth user IDs.

### Mode 1: `psql`

Run the whole file in one administrative session after replacing the two
placeholder UUIDs in a local, untracked execution copy:

```sh
cp supabase/tests/profiles_rls_validation.sql /tmp/profiles_rls_validation.sql
# Edit only /tmp/profiles_rls_validation.sql to replace the two UUID placeholders.
psql -v ON_ERROR_STOP=1 -f /tmp/profiles_rls_validation.sql
```

Do not put connection strings or passwords in repository files. Prefer a secure
interactive prompt or your local password manager.

### Mode 2: Supabase SQL Editor

1. Confirm that the selected project is disposable and not production.
2. Confirm that the migration has already succeeded.
3. Open the SQL Editor.
4. Paste the complete `profiles_rls_validation.sql` file.
5. Replace the two placeholder UUIDs in the pasted SQL with the disposable
   Auth user IDs.
6. Execute the pasted SQL once as a single manual operation.

The script ends with `ROLLBACK`, so its profile updates and cascade check are
not persisted. Remove the two disposable Auth users manually after success or
failure; their profiles are removed by `ON DELETE CASCADE`.

## Complementary metadata validation

Dashboard-created users may not persist the metadata fields required by this
test. To validate the metadata branch, create the disposable user through an
official Supabase Auth flow that writes `raw_user_meta_data`, such as Auth
signup or the server-side Admin API `createUser` operation.
In Supabase client APIs this input is named `user_metadata` or
`options.data`; in PostgreSQL it is stored as `auth.users.raw_user_meta_data`,
which is what the migration reads.

Safety requirements:

- Use only a disposable staging project.
- Do not paste keys, e-mails, UUIDs, passwords, project URLs, or connection
  strings into chat, documentation, Git, or shell history.
- If an admin helper is needed, run a temporary script outside this repository
  and enter any key through a hidden prompt.
- Do not use direct SQL inserts into `auth.users` as a substitute for Auth
  fixture creation.

After creating the metadata fixture, validate with a read-only query that
returns only booleans or counts:

```sql
select
  count(*) = 1 as exactly_one_matching_profile,
  coalesce(
    bool_and(display_name = 'Profile Validation Metadata'),
    false
  ) as display_name_ok,
  coalesce(
    bool_and(
      avatar_url = 'https://example.invalid/profile-validation.png'
    ),
    false
  ) as avatar_url_ok,
  coalesce(bool_and(id <> auth_user_id), false) as internal_id_is_independent
from public.profiles
where display_name = 'Profile Validation Metadata'
  and avatar_url = 'https://example.invalid/profile-validation.png';
```

Remove the disposable metadata Auth user after the check. Its profile must be
removed by cascade.

## `gmail_connections_rls_validation.sql`

Validates the `public.gmail_connections` migration after both database
migrations have been applied once. Do not run either migration again in the
same database.

Required fixtures:

1. Apply `supabase/migrations/20260623135819_create_profiles.sql`.
2. Apply `supabase/migrations/20260623225810_create_gmail_connections.sql`.
3. Create two disposable Supabase Auth users through an official Auth flow.
   Their `public.profiles` rows must exist before executing the script.

The script contains placeholder UUIDs for both Auth users. Replace those
placeholder values only in your local execution copy or SQL Editor paste. Do
not commit real Auth user IDs.

The script validates:

- ownership resolution through
  `auth.uid() -> profiles.auth_user_id -> gmail_connections.profile_id`;
- authenticated users reading only their own Gmail connections;
- no `anon` access;
- no direct client `INSERT`, `UPDATE`, or `DELETE`;
- uniqueness of `(profile_id, google_subject)`;
- different Google accounts coexisting in one profile;
- invalid states being rejected;
- FK and cascade behavior;
- automatic `updated_at`;
- the initial five-active-connections technical limit;
- rollback of all Gmail connection fixtures.

### Mode 1: `psql`

Run the whole file in one administrative session after replacing the two
placeholder UUIDs in a local, untracked execution copy:

```sh
cp supabase/tests/gmail_connections_rls_validation.sql \
  /tmp/gmail_connections_rls_validation.sql
# Edit only /tmp/gmail_connections_rls_validation.sql to replace placeholders.
psql -v ON_ERROR_STOP=1 -f /tmp/gmail_connections_rls_validation.sql
```

Do not put connection strings, service keys, or passwords in repository files.

### Mode 2: Supabase SQL Editor

1. Confirm that the selected project is disposable and not production.
2. Confirm that both migrations have already succeeded.
3. Open the SQL Editor.
4. Paste the complete `gmail_connections_rls_validation.sql` file.
5. Replace the two placeholder UUIDs in the pasted SQL with the disposable
   Auth user IDs.
6. Execute the pasted SQL once as a single manual operation.

The script ends with `ROLLBACK`, so all Gmail connection fixtures and the
profile cascade check are reverted. Remove the two disposable Auth users
manually after success or failure; their profiles are removed by cascade.

## `google_oauth_states_validation.sql`

Validates the `public.google_oauth_states` migration after the profile and
OAuth state migrations have been applied once. Do not run either migration
again in the same database.

Required fixtures:

1. Apply `supabase/migrations/20260623135819_create_profiles.sql`.
2. Apply `supabase/migrations/20260624120000_create_google_oauth_states.sql`.
3. Create two disposable Supabase Auth users through an official Auth flow.
   Their `public.profiles` rows must exist before executing the script.

The script contains placeholder UUIDs for both Auth users. Replace those
placeholder values only in your local execution copy or SQL Editor paste. Do
not commit real Auth user IDs.

The script validates table shape, PK/FK/cascade, unique SHA-256 state hashes,
rejection of blank state hashes and invalid expiration, RLS, absence of grants
for `anon` and `authenticated`, administrative insert, atomic consume,
replay rejection, expired state rejection, cleanup, and rollback.

### Mode 1: `psql`

Run the whole file in one administrative session after replacing the two
placeholder UUIDs in a local, untracked execution copy:

```sh
cp supabase/tests/google_oauth_states_validation.sql \
  /tmp/google_oauth_states_validation.sql
# Edit only /tmp/google_oauth_states_validation.sql to replace placeholders.
psql -v ON_ERROR_STOP=1 -f /tmp/google_oauth_states_validation.sql
```

Do not put connection strings, service keys, state values, or passwords in
repository files.

### Mode 2: Supabase SQL Editor

1. Confirm that the selected project is disposable and not production.
2. Confirm that the required migrations have already succeeded once.
3. Open the SQL Editor.
4. Paste the complete `google_oauth_states_validation.sql` file.
5. Replace the two placeholder UUIDs in the pasted SQL with the disposable
   Auth user IDs.
6. Execute the pasted SQL once as a single manual operation.

The script ends with `ROLLBACK`, so all OAuth state fixtures and the profile
cascade check are reverted. Remove the two disposable Auth users manually after
success or failure; their profiles are removed by cascade.
