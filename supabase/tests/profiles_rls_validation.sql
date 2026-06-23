-- Manual validation for public.profiles.
--
-- Prerequisites:
-- 1. In a disposable database before applying this migration, create user B
--    without user metadata.
-- 2. Apply the local migrations. User B must be created by the backfill.
-- 3. After applying the migration, create user A through Supabase Auth with
--      full_name = "Profile Validation A" and
--      avatar_url = "https://example.invalid/original-avatar-a.png";
--    User A must be created by the auth.users trigger.
-- 4. Replace the two placeholder UUIDs below in your local execution copy
--    only. Do not commit real Auth user IDs.
-- 5. Run this entire file in one administrative session. The canonical
--    automated mode is psql. The same plain SQL can also be pasted into the
--    Supabase SQL Editor and run as one complete manual operation.
-- 6. Do not reapply the migration before running this validation.
-- 7. The validation ends with ROLLBACK. Remove both disposable Auth users
--    manually after success or failure; their profiles are removed by cascade.
--
-- This script must never be run against production users.

begin;

select set_config(
    'validation.user_a',
    '00000000-0000-0000-0000-000000000001',
    true
);

select set_config(
    'validation.user_b',
    '00000000-0000-0000-0000-000000000002',
    true
);

create or replace function pg_temp.assert_true(
    condition boolean,
    message text
)
returns void
language plpgsql
as $$
begin
    if not coalesce(condition, false) then
        raise exception 'validation failed: %', message;
    end if;
end;
$$;

select pg_temp.assert_true(
    current_setting('validation.user_a')::uuid <>
        '00000000-0000-0000-0000-000000000001'::uuid
    and current_setting('validation.user_b')::uuid <>
        '00000000-0000-0000-0000-000000000002'::uuid
    and current_setting('validation.user_a')::uuid <>
        current_setting('validation.user_b')::uuid,
    'replace placeholder UUIDs with two distinct disposable Auth user IDs'
);

select pg_temp.assert_true(
    exists (
        select 1
        from auth.users
        where id = current_setting('validation.user_a')::uuid
    )
    and exists (
        select 1
        from auth.users
        where id = current_setting('validation.user_b')::uuid
    ),
    'both configured disposable Auth users must exist'
);

select pg_temp.assert_true(
    (select count(*) = 1
     from public.profiles
     where auth_user_id = current_setting('validation.user_a')::uuid),
    'creating user A must create exactly one profile'
);

select pg_temp.assert_true(
    (select count(*) = 1
     from public.profiles
     where auth_user_id = current_setting('validation.user_b')::uuid),
    'creating user B without metadata must create exactly one profile'
);

select pg_temp.assert_true(
    (select auth_user_id = current_setting('validation.user_a')::uuid
            and id <> auth_user_id
            and display_name = 'Profile Validation A'
            and avatar_url =
                'https://example.invalid/original-avatar-a.png'
     from public.profiles
     where auth_user_id = current_setting('validation.user_a')::uuid),
    'profile must keep the auth link, independent id, name, and avatar metadata'
);

select pg_temp.assert_true(
    (select display_name is null and avatar_url is null
     from public.profiles
     where auth_user_id = current_setting('validation.user_b')::uuid),
    'missing metadata must produce nullable profile fields'
);

select pg_temp.assert_true(
    (select relkind = 'r'
            and relrowsecurity
            and not relforcerowsecurity
            and pg_catalog.pg_get_userbyid(relowner) = 'postgres'
     from pg_catalog.pg_class
     where oid = 'public.profiles'::regclass),
    'profiles must be a postgres-owned table with enabled, non-forced RLS'
);

select pg_temp.assert_true(
    (select count(*) = 6
     from pg_catalog.pg_attribute
     where attrelid = 'public.profiles'::regclass
       and attnum > 0
       and not attisdropped)
    and exists (
        select 1
        from pg_catalog.pg_attribute as attribute
        join pg_catalog.pg_attrdef as default_value
          on default_value.adrelid = attribute.attrelid
         and default_value.adnum = attribute.attnum
        where attribute.attrelid = 'public.profiles'::regclass
          and attribute.attname = 'id'
          and attribute.atttypid = 'uuid'::regtype
          and attribute.attnotnull
          and pg_catalog.pg_get_expr(
              default_value.adbin,
              default_value.adrelid
          ) like '%gen_random_uuid()%'
    )
    and exists (
        select 1
        from pg_catalog.pg_attribute
        where attrelid = 'public.profiles'::regclass
          and attname = 'auth_user_id'
          and atttypid = 'uuid'::regtype
          and attnotnull
    )
    and exists (
        select 1
        from pg_catalog.pg_attribute
        where attrelid = 'public.profiles'::regclass
          and attname = 'display_name'
          and atttypid = 'text'::regtype
          and not attnotnull
    )
    and exists (
        select 1
        from pg_catalog.pg_attribute
        where attrelid = 'public.profiles'::regclass
          and attname = 'avatar_url'
          and atttypid = 'text'::regtype
          and not attnotnull
    )
    and (
        select count(*) = 2
        from pg_catalog.pg_attribute as attribute
        join pg_catalog.pg_attrdef as default_value
          on default_value.adrelid = attribute.attrelid
         and default_value.adnum = attribute.attnum
        where attribute.attrelid = 'public.profiles'::regclass
          and attribute.attname in ('created_at', 'updated_at')
          and attribute.atttypid = 'timestamptz'::regtype
          and attribute.attnotnull
          and pg_catalog.pg_get_expr(
              default_value.adbin,
              default_value.adrelid
          ) like '%now()%'
    ),
    'profiles must have exactly the expected columns, nullability, and defaults'
);

select pg_temp.assert_true(
    exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.profiles'::regclass
          and conname = 'profiles_pkey'
          and contype = 'p'
          and conkey = array[
              (
                  select attnum
                  from pg_catalog.pg_attribute
                  where attrelid = 'public.profiles'::regclass
                    and attname = 'id'
              )
          ]::smallint[]
    )
    and exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.profiles'::regclass
          and conname = 'profiles_auth_user_id_key'
          and contype = 'u'
          and conkey = array[
              (
                  select attnum
                  from pg_catalog.pg_attribute
                  where attrelid = 'public.profiles'::regclass
                    and attname = 'auth_user_id'
              )
          ]::smallint[]
    )
    and exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.profiles'::regclass
          and conname = 'profiles_auth_user_id_fkey'
          and contype = 'f'
          and confrelid = 'auth.users'::regclass
          and confdeltype = 'c'
          and conkey = array[
              (
                  select attnum
                  from pg_catalog.pg_attribute
                  where attrelid = 'public.profiles'::regclass
                    and attname = 'auth_user_id'
              )
          ]::smallint[]
          and confkey = array[
              (
                  select attnum
                  from pg_catalog.pg_attribute
                  where attrelid = 'auth.users'::regclass
                    and attname = 'id'
              )
          ]::smallint[]
    )
    and (
        select count(*) = 2
               and count(*) filter (where indisunique) = 2
               and count(*) filter (where indisprimary) = 1
        from pg_catalog.pg_index
        where indrelid = 'public.profiles'::regclass
    ),
    'profiles must have the expected PK, unique FK, cascade, and no redundant index'
);

select pg_temp.assert_true(
    exists (
        select 1
        from pg_catalog.pg_trigger
        where tgrelid = 'public.profiles'::regclass
          and tgname = 'profiles_set_updated_at'
          and tgfoid = 'public.set_profile_updated_at()'::regprocedure
          and tgenabled = 'O'
          and not tgisinternal
          and pg_catalog.pg_get_triggerdef(oid) like
              '%BEFORE UPDATE ON public.profiles%'
    )
    and exists (
        select 1
        from pg_catalog.pg_trigger
        where tgrelid = 'auth.users'::regclass
          and tgname = 'auth_user_create_profile'
          and tgfoid =
              'public.create_profile_for_auth_user()'::regprocedure
          and tgenabled = 'O'
          and not tgisinternal
          and pg_catalog.pg_get_triggerdef(oid) like
              '%AFTER INSERT ON auth.users%'
    ),
    'profile creation and updated_at triggers must be enabled and correctly bound'
);

select pg_temp.assert_true(
    (select count(*) = 2
     from pg_catalog.pg_policies
     where schemaname = 'public'
       and tablename = 'profiles')
    and exists (
        select 1
        from pg_catalog.pg_policies
        where schemaname = 'public'
          and tablename = 'profiles'
          and policyname =
              'Authenticated users can read their own profile'
          and permissive = 'PERMISSIVE'
          and roles = array['authenticated']::name[]
          and cmd = 'SELECT'
          and qual is not null
          and with_check is null
    )
    and exists (
        select 1
        from pg_catalog.pg_policies
        where schemaname = 'public'
          and tablename = 'profiles'
          and policyname =
              'Authenticated users can update their own profile'
          and permissive = 'PERMISSIVE'
          and roles = array['authenticated']::name[]
          and cmd = 'UPDATE'
          and qual is not null
          and with_check is not null
    ),
    'profiles must have exactly the expected authenticated policies'
);

select pg_temp.assert_true(
    not has_table_privilege('anon', 'public.profiles', 'SELECT')
    and not has_table_privilege('anon', 'public.profiles', 'INSERT')
    and not has_table_privilege('anon', 'public.profiles', 'UPDATE')
    and not has_table_privilege('anon', 'public.profiles', 'DELETE'),
    'anon must have no privileges on public.profiles'
);

select pg_temp.assert_true(
    has_table_privilege('authenticated', 'public.profiles', 'SELECT')
    and not has_table_privilege('authenticated', 'public.profiles', 'INSERT')
    and not has_table_privilege('authenticated', 'public.profiles', 'DELETE')
    and has_column_privilege(
        'authenticated',
        'public.profiles',
        'display_name',
        'UPDATE'
    )
    and has_column_privilege(
        'authenticated',
        'public.profiles',
        'avatar_url',
        'UPDATE'
    )
    and not has_column_privilege(
        'authenticated',
        'public.profiles',
        'id',
        'UPDATE'
    )
    and not has_column_privilege(
        'authenticated',
        'public.profiles',
        'auth_user_id',
        'UPDATE'
    )
    and not has_column_privilege(
        'authenticated',
        'public.profiles',
        'created_at',
        'UPDATE'
    )
    and not has_column_privilege(
        'authenticated',
        'public.profiles',
        'updated_at',
        'UPDATE'
    ),
    'authenticated must have SELECT and only mutable-column UPDATE privileges'
);

select pg_temp.assert_true(
    not has_function_privilege(
        'anon',
        'public.create_profile_for_auth_user()',
        'EXECUTE'
    )
    and not has_function_privilege(
        'authenticated',
        'public.create_profile_for_auth_user()',
        'EXECUTE'
    )
    and not has_function_privilege(
        'anon',
        'public.set_profile_updated_at()',
        'EXECUTE'
    )
    and not has_function_privilege(
        'authenticated',
        'public.set_profile_updated_at()',
        'EXECUTE'
    ),
    'client roles must not execute internal trigger functions'
);

select pg_temp.assert_true(
    (select p.prosecdef
            and pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
            and exists (
                select 1
                from unnest(coalesce(p.proconfig, array[]::text[])) as setting
                where split_part(setting, '=', 1) = 'search_path'
                  and replace(split_part(setting, '=', 2), '"', '') = ''
            )
     from pg_catalog.pg_proc as p
     where p.oid = 'public.create_profile_for_auth_user()'::regprocedure),
    'auth trigger function must be SECURITY DEFINER owned by postgres with empty search_path'
);

select pg_temp.assert_true(
    (select not p.prosecdef
            and pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
            and exists (
                select 1
                from unnest(coalesce(p.proconfig, array[]::text[])) as setting
                where split_part(setting, '=', 1) = 'search_path'
                  and replace(split_part(setting, '=', 2), '"', '') = ''
            )
     from pg_catalog.pg_proc as p
     where p.oid = 'public.set_profile_updated_at()'::regprocedure),
    'updated_at function must be invoker-owned by postgres with empty search_path'
);

insert into public.profiles (
    auth_user_id,
    display_name,
    avatar_url
)
select
    users.id,
    coalesce(
        nullif(pg_catalog.btrim(users.raw_user_meta_data ->> 'full_name'), ''),
        nullif(pg_catalog.btrim(users.raw_user_meta_data ->> 'name'), '')
    ),
    coalesce(
        nullif(pg_catalog.btrim(users.raw_user_meta_data ->> 'avatar_url'), ''),
        nullif(pg_catalog.btrim(users.raw_user_meta_data ->> 'picture'), '')
    )
from auth.users as users
where users.id in (
    current_setting('validation.user_a')::uuid,
    current_setting('validation.user_b')::uuid
)
on conflict (auth_user_id) do nothing;

select pg_temp.assert_true(
    (select count(*) = 2
     from public.profiles
     where auth_user_id in (
         current_setting('validation.user_a')::uuid,
         current_setting('validation.user_b')::uuid
     )),
    'rerunning profile reconciliation must remain idempotent'
);

select set_config(
    'validation.profile_id',
    (
        select id::text
        from public.profiles
        where auth_user_id = current_setting('validation.user_a')::uuid
    ),
    true
);

select set_config(
    'validation.created_at',
    (
        select created_at::text
        from public.profiles
        where auth_user_id = current_setting('validation.user_a')::uuid
    ),
    true
);

select set_config(
    'validation.updated_at',
    (
        select updated_at::text
        from public.profiles
        where auth_user_id = current_setting('validation.user_a')::uuid
    ),
    true
);

set local role authenticated;
select set_config(
    'request.jwt.claim.sub',
    current_setting('validation.user_a'),
    true
);

select pg_temp.assert_true(
    (select count(*) = 1 from public.profiles),
    'user A must read exactly their own profile'
);

select pg_temp.assert_true(
    (select count(*) = 0
     from public.profiles
     where auth_user_id = current_setting('validation.user_b')::uuid),
    'user A must not read user B profile'
);

update public.profiles
set display_name = 'Profile validation A',
    avatar_url = 'https://example.invalid/avatar-a.png'
where auth_user_id = current_setting('validation.user_a')::uuid;

do $$
declare
    affected_rows bigint;
begin
    update public.profiles
    set display_name = 'forbidden'
    where auth_user_id = current_setting('validation.user_b')::uuid;

    get diagnostics affected_rows = row_count;
    if affected_rows <> 0 then
        raise exception 'validation failed: user A updated user B profile';
    end if;
end;
$$;

do $$
begin
    begin
        insert into public.profiles (auth_user_id)
        values (current_setting('validation.user_a')::uuid);
        raise exception 'validation failed: authenticated user inserted a profile';
    exception
        when insufficient_privilege then null;
    end;

    begin
        delete from public.profiles
        where auth_user_id = current_setting('validation.user_a')::uuid;
        raise exception 'validation failed: authenticated user deleted a profile';
    exception
        when insufficient_privilege then null;
    end;

    begin
        update public.profiles
        set id = gen_random_uuid()
        where auth_user_id = current_setting('validation.user_a')::uuid;
        raise exception 'validation failed: authenticated user changed id';
    exception
        when insufficient_privilege then null;
    end;

    begin
        update public.profiles
        set auth_user_id = current_setting('validation.user_b')::uuid
        where auth_user_id = current_setting('validation.user_a')::uuid;
        raise exception 'validation failed: authenticated user changed auth_user_id';
    exception
        when insufficient_privilege then null;
    end;

    begin
        update public.profiles
        set created_at = now()
        where auth_user_id = current_setting('validation.user_a')::uuid;
        raise exception 'validation failed: authenticated user changed created_at';
    exception
        when insufficient_privilege then null;
    end;

    begin
        update public.profiles
        set updated_at = now()
        where auth_user_id = current_setting('validation.user_a')::uuid;
        raise exception 'validation failed: authenticated user changed updated_at';
    exception
        when insufficient_privilege then null;
    end;

    begin
        perform public.create_profile_for_auth_user();
        raise exception 'validation failed: authenticated user called profile creation function';
    exception
        when insufficient_privilege then null;
    end;

    begin
        perform public.set_profile_updated_at();
        raise exception 'validation failed: authenticated user called updated_at function';
    exception
        when insufficient_privilege then null;
    end;
end;
$$;

reset role;

select pg_temp.assert_true(
    (select display_name = 'Profile validation A'
            and avatar_url = 'https://example.invalid/avatar-a.png'
            and id = current_setting('validation.profile_id')::uuid
            and created_at =
                current_setting('validation.created_at')::timestamptz
            and updated_at >
                current_setting('validation.updated_at')::timestamptz
     from public.profiles
     where auth_user_id = current_setting('validation.user_a')::uuid),
    'valid updates must preserve immutable fields and advance updated_at'
);

set local role anon;

do $$
begin
    begin
        perform count(*) from public.profiles;
        raise exception 'validation failed: anon read profiles';
    exception
        when insufficient_privilege then null;
    end;
end;
$$;

reset role;

do $$
begin
    begin
        insert into public.profiles (auth_user_id)
        values (current_setting('validation.user_a')::uuid);
        raise exception 'validation failed: duplicate profile insert succeeded';
    exception
        when unique_violation then null;
    end;
end;
$$;

select pg_temp.assert_true(
    (select count(*) = 1
     from public.profiles
     where auth_user_id = current_setting('validation.user_a')::uuid),
    'an idempotent duplicate attempt must not create another profile'
);

delete from auth.users
where id = current_setting('validation.user_b')::uuid;

select pg_temp.assert_true(
    not exists (
        select 1
        from public.profiles
        where auth_user_id = current_setting('validation.user_b')::uuid
    ),
    'deleting auth user B must cascade to its profile'
);

select 'runtime validation passed' as result;

rollback;
