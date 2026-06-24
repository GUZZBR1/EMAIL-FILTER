-- Manual validation for public.google_oauth_states.
--
-- Prerequisites:
-- 1. Apply the profile migration and Google OAuth state migration once in a
--    disposable local or staging database.
-- 2. Create two disposable Supabase Auth users through an official Auth flow
--    so that public.profiles contains one profile for each user.
-- 3. Replace the two placeholder UUIDs below in your local execution copy
--    only. Do not commit real Auth user IDs.
-- 4. Run this entire file in one administrative session. The canonical
--    automated mode is psql. The same plain SQL can also be pasted into the
--    Supabase SQL Editor and run as one complete manual operation.
-- 5. The validation ends with ROLLBACK and must never be run against
--    production users or production data.

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
        from public.profiles
        where auth_user_id = current_setting('validation.user_a')::uuid
    )
    and exists (
        select 1
        from public.profiles
        where auth_user_id = current_setting('validation.user_b')::uuid
    ),
    'both configured disposable Auth users must have profiles'
);

select set_config(
    'validation.profile_a',
    (
        select id::text
        from public.profiles
        where auth_user_id = current_setting('validation.user_a')::uuid
    ),
    true
);

select set_config(
    'validation.profile_b',
    (
        select id::text
        from public.profiles
        where auth_user_id = current_setting('validation.user_b')::uuid
    ),
    true
);

select pg_temp.assert_true(
    (select relkind = 'r'
            and relrowsecurity
            and not relforcerowsecurity
            and pg_catalog.pg_get_userbyid(relowner) = 'postgres'
     from pg_catalog.pg_class
     where oid = 'public.google_oauth_states'::regclass),
    'google_oauth_states must be postgres-owned with enabled, non-forced RLS'
);

select pg_temp.assert_true(
    (select count(*) = 7
     from pg_catalog.pg_attribute
     where attrelid = 'public.google_oauth_states'::regclass
       and attnum > 0
       and not attisdropped)
    and exists (
        select 1
        from pg_catalog.pg_attribute as attribute
        join pg_catalog.pg_attrdef as default_value
          on default_value.adrelid = attribute.attrelid
         and default_value.adnum = attribute.attnum
        where attribute.attrelid = 'public.google_oauth_states'::regclass
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
        where attrelid = 'public.google_oauth_states'::regclass
          and attname = 'profile_id'
          and atttypid = 'uuid'::regtype
          and attnotnull
    )
    and (
        select count(*) = 2
        from pg_catalog.pg_attribute
        where attrelid = 'public.google_oauth_states'::regclass
          and attname in ('state_hash', 'return_url')
          and atttypid = 'text'::regtype
          and attnotnull
    )
    and (
        select count(*) = 3
        from pg_catalog.pg_attribute
        where attrelid = 'public.google_oauth_states'::regclass
          and attname in ('created_at', 'expires_at', 'consumed_at')
          and atttypid = 'timestamptz'::regtype
    )
    and not exists (
        select 1
        from pg_catalog.pg_attribute
        where attrelid = 'public.google_oauth_states'::regclass
          and attname in ('state', 'raw_state')
    )
    and not exists (
        select 1
        from pg_catalog.pg_attribute
        where attrelid = 'public.google_oauth_states'::regclass
          and attname ilike '%token%'
    ),
    'google_oauth_states must have expected columns and no raw state or token'
);

select pg_temp.assert_true(
    exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.google_oauth_states'::regclass
          and conname = 'google_oauth_states_pkey'
          and contype = 'p'
    )
    and exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.google_oauth_states'::regclass
          and conname = 'google_oauth_states_profile_id_fkey'
          and contype = 'f'
          and confrelid = 'public.profiles'::regclass
          and confdeltype = 'c'
    )
    and exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.google_oauth_states'::regclass
          and conname = 'google_oauth_states_state_hash_key'
          and contype = 'u'
    )
    and exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.google_oauth_states'::regclass
          and conname = 'google_oauth_states_state_hash_format'
          and contype = 'c'
    )
    and exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.google_oauth_states'::regclass
          and conname = 'google_oauth_states_expires_after_created'
          and contype = 'c'
    ),
    'google_oauth_states must have expected PK, FK, unique hash, and checks'
);

select pg_temp.assert_true(
    (select count(*) = 0
     from pg_catalog.pg_policies
     where schemaname = 'public'
       and tablename = 'google_oauth_states'),
    'google_oauth_states must not expose client RLS policies'
);

select pg_temp.assert_true(
    not has_table_privilege('anon', 'public.google_oauth_states', 'SELECT')
    and not has_table_privilege('anon', 'public.google_oauth_states', 'INSERT')
    and not has_table_privilege('anon', 'public.google_oauth_states', 'UPDATE')
    and not has_table_privilege('anon', 'public.google_oauth_states', 'DELETE'),
    'anon must have no privileges on public.google_oauth_states'
);

select pg_temp.assert_true(
    not has_table_privilege(
        'authenticated',
        'public.google_oauth_states',
        'SELECT'
    )
    and not has_table_privilege(
        'authenticated',
        'public.google_oauth_states',
        'INSERT'
    )
    and not has_table_privilege(
        'authenticated',
        'public.google_oauth_states',
        'UPDATE'
    )
    and not has_table_privilege(
        'authenticated',
        'public.google_oauth_states',
        'DELETE'
    ),
    'authenticated must have no privileges on public.google_oauth_states'
);

insert into public.google_oauth_states (
    profile_id,
    state_hash,
    return_url,
    created_at,
    expires_at
)
values (
    current_setting('validation.profile_a')::uuid,
    repeat('a', 64),
    'https://app.example.invalid/settings/accounts?gmail=connected',
    now(),
    now() + interval '10 minutes'
);

select pg_temp.assert_true(
    (select count(*) = 1
     from public.google_oauth_states
     where profile_id = current_setting('validation.profile_a')::uuid
       and state_hash = repeat('a', 64)
       and consumed_at is null),
    'administrative insert must persist one hashed OAuth state'
);

do $$
begin
    begin
        insert into public.google_oauth_states (
            profile_id,
            state_hash,
            return_url,
            expires_at
        )
        values (
            current_setting('validation.profile_a')::uuid,
            repeat('a', 64),
            'https://app.example.invalid/settings/accounts?gmail=connected',
            now() + interval '10 minutes'
        );
        raise exception 'validation failed: duplicate state hash insert succeeded';
    exception
        when unique_violation then null;
    end;

    begin
        insert into public.google_oauth_states (
            profile_id,
            state_hash,
            return_url,
            expires_at
        )
        values (
            current_setting('validation.profile_a')::uuid,
            '',
            'https://app.example.invalid/settings/accounts?gmail=connected',
            now() + interval '10 minutes'
        );
        raise exception 'validation failed: blank state hash insert succeeded';
    exception
        when check_violation then null;
    end;

    begin
        insert into public.google_oauth_states (
            profile_id,
            state_hash,
            return_url,
            created_at,
            expires_at
        )
        values (
            current_setting('validation.profile_a')::uuid,
            repeat('b', 64),
            'https://app.example.invalid/settings/accounts?gmail=connected',
            now(),
            now()
        );
        raise exception 'validation failed: non-future expiration insert succeeded';
    exception
        when check_violation then null;
    end;
end;
$$;

set local role authenticated;
select set_config(
    'request.jwt.claim.sub',
    current_setting('validation.user_a'),
    true
);

do $$
begin
    begin
        perform count(*) from public.google_oauth_states;
        raise exception 'validation failed: authenticated user read OAuth states';
    exception
        when insufficient_privilege then null;
    end;

    begin
        insert into public.google_oauth_states (
            profile_id,
            state_hash,
            return_url,
            expires_at
        )
        values (
            current_setting('validation.profile_a')::uuid,
            repeat('c', 64),
            'https://app.example.invalid/settings/accounts?gmail=connected',
            now() + interval '10 minutes'
        );
        raise exception 'validation failed: authenticated user inserted OAuth state';
    exception
        when insufficient_privilege then null;
    end;
end;
$$;

reset role;

set local role anon;

do $$
begin
    begin
        perform count(*) from public.google_oauth_states;
        raise exception 'validation failed: anon read OAuth states';
    exception
        when insufficient_privilege then null;
    end;
end;
$$;

reset role;

with consumed as (
    update public.google_oauth_states
       set consumed_at = now()
     where state_hash = repeat('a', 64)
       and profile_id = current_setting('validation.profile_a')::uuid
       and return_url =
           'https://app.example.invalid/settings/accounts?gmail=connected'
       and consumed_at is null
       and expires_at > now()
    returning id
)
select pg_temp.assert_true(
    (select count(*) = 1 from consumed),
    'first atomic state consumption must return one row'
);

with consumed as (
    update public.google_oauth_states
       set consumed_at = now()
     where state_hash = repeat('a', 64)
       and profile_id = current_setting('validation.profile_a')::uuid
       and return_url =
           'https://app.example.invalid/settings/accounts?gmail=connected'
       and consumed_at is null
       and expires_at > now()
    returning id
)
select pg_temp.assert_true(
    (select count(*) = 0 from consumed),
    'second atomic state consumption must return no rows'
);

insert into public.google_oauth_states (
    profile_id,
    state_hash,
    return_url,
    created_at,
    expires_at
)
values (
    current_setting('validation.profile_a')::uuid,
    repeat('d', 64),
    'https://app.example.invalid/settings/accounts?gmail=connected',
    now() - interval '20 minutes',
    now() - interval '10 minutes'
);

with consumed as (
    update public.google_oauth_states
       set consumed_at = now()
     where state_hash = repeat('d', 64)
       and consumed_at is null
       and expires_at > now()
    returning id
)
select pg_temp.assert_true(
    (select count(*) = 0 from consumed),
    'expired OAuth state must not be consumed'
);

insert into public.google_oauth_states (
    profile_id,
    state_hash,
    return_url,
    created_at,
    expires_at
)
values (
    current_setting('validation.profile_b')::uuid,
    repeat('e', 64),
    'https://app.example.invalid/settings/accounts?gmail=error',
    now() - interval '30 minutes',
    now() - interval '20 minutes'
);

delete from public.google_oauth_states
where expires_at <= now()
   or consumed_at <= now();

select pg_temp.assert_true(
    not exists (
        select 1
        from public.google_oauth_states
        where state_hash in (repeat('a', 64), repeat('d', 64), repeat('e', 64))
    ),
    'cleanup must delete expired and consumed OAuth state rows'
);

insert into public.google_oauth_states (
    profile_id,
    state_hash,
    return_url,
    expires_at
)
values (
    current_setting('validation.profile_b')::uuid,
    repeat('f', 64),
    'https://app.example.invalid/settings/accounts?gmail=connected',
    now() + interval '10 minutes'
);

delete from public.profiles
where id = current_setting('validation.profile_b')::uuid;

select pg_temp.assert_true(
    not exists (
        select 1
        from public.google_oauth_states
        where profile_id = current_setting('validation.profile_b')::uuid
    ),
    'deleting a profile must cascade to its OAuth states'
);

select 'google oauth states runtime validation passed' as result;

rollback;
