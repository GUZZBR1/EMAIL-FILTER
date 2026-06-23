-- Manual validation for public.gmail_connections.
--
-- Prerequisites:
-- 1. Apply the profile migration and the Gmail connection migration once in a
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
     where oid = 'public.gmail_connections'::regclass),
    'gmail_connections must be a postgres-owned table with enabled, non-forced RLS'
);

select pg_temp.assert_true(
    (select count(*) = 15
     from pg_catalog.pg_attribute
     where attrelid = 'public.gmail_connections'::regclass
       and attnum > 0
       and not attisdropped)
    and exists (
        select 1
        from pg_catalog.pg_attribute as attribute
        join pg_catalog.pg_attrdef as default_value
          on default_value.adrelid = attribute.attrelid
         and default_value.adnum = attribute.attnum
        where attribute.attrelid = 'public.gmail_connections'::regclass
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
        where attrelid = 'public.gmail_connections'::regclass
          and attname = 'profile_id'
          and atttypid = 'uuid'::regtype
          and attnotnull
    )
    and (
        select count(*) = 3
        from pg_catalog.pg_attribute
        where attrelid = 'public.gmail_connections'::regclass
          and attname in (
              'google_subject',
              'gmail_email',
              'connection_status'
          )
          and atttypid = 'text'::regtype
          and attnotnull
    )
    and exists (
        select 1
        from pg_catalog.pg_attribute
        where attrelid = 'public.gmail_connections'::regclass
          and attname = 'gmail_email_normalized'
          and atttypid = 'text'::regtype
          and attgenerated = 's'
    )
    and (
        select count(*) = 2
        from pg_catalog.pg_attribute
        where attrelid = 'public.gmail_connections'::regclass
          and attname in ('display_name', 'avatar_url')
          and atttypid = 'text'::regtype
          and not attnotnull
    )
    and exists (
        select 1
        from pg_catalog.pg_attribute
        where attrelid = 'public.gmail_connections'::regclass
          and attname = 'granted_scopes'
          and atttypid = 'text[]'::regtype
          and attnotnull
    )
    and (
        select count(*) = 6
        from pg_catalog.pg_attribute
        where attrelid = 'public.gmail_connections'::regclass
          and attname in (
              'created_at',
              'updated_at',
              'last_connected_at',
              'last_validated_at',
              'revoked_at',
              'disconnected_at'
          )
          and atttypid = 'timestamptz'::regtype
    )
    and not exists (
        select 1
        from pg_catalog.pg_attribute
        where attrelid = 'public.gmail_connections'::regclass
          and attname ilike '%token%'
    ),
    'gmail_connections must have the expected columns and no token fields'
);

select pg_temp.assert_true(
    exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.gmail_connections'::regclass
          and conname = 'gmail_connections_pkey'
          and contype = 'p'
    )
    and exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.gmail_connections'::regclass
          and conname = 'gmail_connections_profile_google_subject_key'
          and contype = 'u'
    )
    and exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.gmail_connections'::regclass
          and conname = 'gmail_connections_profile_id_fkey'
          and contype = 'f'
          and confrelid = 'public.profiles'::regclass
          and confdeltype = 'c'
    )
    and exists (
        select 1
        from pg_catalog.pg_constraint
        where conrelid = 'public.gmail_connections'::regclass
          and conname = 'gmail_connections_status_check'
          and contype = 'c'
    )
    and (
        select count(*) = 2
               and count(*) filter (where indisunique) = 2
               and count(*) filter (where indisprimary) = 1
        from pg_catalog.pg_index
        where indrelid = 'public.gmail_connections'::regclass
    ),
    'gmail_connections must have expected constraints, cascade FK, and no redundant index'
);

select pg_temp.assert_true(
    exists (
        select 1
        from pg_catalog.pg_trigger
        where tgrelid = 'public.gmail_connections'::regclass
          and tgname = 'gmail_connections_set_updated_at'
          and tgfoid = 'public.set_profile_updated_at()'::regprocedure
          and tgenabled = 'O'
          and not tgisinternal
          and pg_catalog.pg_get_triggerdef(oid) like
              '%BEFORE UPDATE ON public.gmail_connections%'
    )
    and exists (
        select 1
        from pg_catalog.pg_trigger
        where tgrelid = 'public.gmail_connections'::regclass
          and tgname = 'gmail_connections_enforce_active_limit'
          and tgfoid =
              'public.enforce_gmail_connections_active_limit()'::regprocedure
          and tgenabled = 'O'
          and not tgisinternal
          and pg_catalog.pg_get_triggerdef(oid) like
              '%BEFORE INSERT OR UPDATE ON public.gmail_connections%'
    ),
    'gmail connection limit and updated_at triggers must be enabled'
);

select pg_temp.assert_true(
    (select count(*) = 1
     from pg_catalog.pg_policies
     where schemaname = 'public'
       and tablename = 'gmail_connections')
    and exists (
        select 1
        from pg_catalog.pg_policies
        where schemaname = 'public'
          and tablename = 'gmail_connections'
          and policyname =
              'Authenticated users can read their own Gmail connections'
          and permissive = 'PERMISSIVE'
          and roles = array['authenticated']::name[]
          and cmd = 'SELECT'
          and qual is not null
          and with_check is null
    ),
    'gmail_connections must expose only the authenticated SELECT policy'
);

select pg_temp.assert_true(
    not has_table_privilege('anon', 'public.gmail_connections', 'SELECT')
    and not has_table_privilege('anon', 'public.gmail_connections', 'INSERT')
    and not has_table_privilege('anon', 'public.gmail_connections', 'UPDATE')
    and not has_table_privilege('anon', 'public.gmail_connections', 'DELETE'),
    'anon must have no privileges on public.gmail_connections'
);

select pg_temp.assert_true(
    has_table_privilege('authenticated', 'public.gmail_connections', 'SELECT')
    and not has_table_privilege(
        'authenticated',
        'public.gmail_connections',
        'INSERT'
    )
    and not has_table_privilege(
        'authenticated',
        'public.gmail_connections',
        'UPDATE'
    )
    and not has_table_privilege(
        'authenticated',
        'public.gmail_connections',
        'DELETE'
    ),
    'authenticated must have only SELECT on public.gmail_connections'
);

select pg_temp.assert_true(
    not has_function_privilege(
        'anon',
        'public.enforce_gmail_connections_active_limit()',
        'EXECUTE'
    )
    and not has_function_privilege(
        'authenticated',
        'public.enforce_gmail_connections_active_limit()',
        'EXECUTE'
    )
    and (
        select not p.prosecdef
                and pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
                and exists (
                    select 1
                    from unnest(
                        coalesce(p.proconfig, array[]::text[])
                    ) as setting
                    where split_part(setting, '=', 1) = 'search_path'
                      and replace(split_part(setting, '=', 2), '"', '') = ''
                )
         from pg_catalog.pg_proc as p
         where p.oid =
            'public.enforce_gmail_connections_active_limit()'::regprocedure),
    'active limit function must be internal, invoker-rights, and use empty search_path'
);

insert into public.gmail_connections (
    profile_id,
    google_subject,
    gmail_email,
    display_name,
    avatar_url,
    connection_status,
    granted_scopes,
    last_connected_at,
    last_validated_at
)
values
    (
        current_setting('validation.profile_a')::uuid,
        'validation-google-subject-a-1',
        'Validation.A.One@example.invalid',
        'Validation A One',
        'https://example.invalid/a-one.png',
        'connected',
        array['https://www.googleapis.com/auth/gmail.readonly'],
        now(),
        now()
    ),
    (
        current_setting('validation.profile_a')::uuid,
        'validation-google-subject-a-2',
        'validation.a.two@example.invalid',
        'Validation A Two',
        null,
        'disconnected',
        array[]::text[],
        null,
        null
    ),
    (
        current_setting('validation.profile_b')::uuid,
        'validation-google-subject-b-1',
        'validation.b.one@example.invalid',
        'Validation B One',
        null,
        'connected',
        array['https://www.googleapis.com/auth/gmail.readonly'],
        now(),
        now()
    );

select pg_temp.assert_true(
    (select count(*) = 2
     from public.gmail_connections
     where profile_id = current_setting('validation.profile_a')::uuid),
    'different Google accounts can coexist in the same profile'
);

select pg_temp.assert_true(
    (select count(*) = 1
     from public.gmail_connections
     where profile_id = current_setting('validation.profile_a')::uuid
       and gmail_email = 'Validation.A.One@example.invalid'
       and gmail_email_normalized = 'validation.a.one@example.invalid'),
    'gmail email must preserve display value and store normalized comparison value'
);

do $$
begin
    begin
        insert into public.gmail_connections (
            profile_id,
            google_subject,
            gmail_email
        )
        values (
            gen_random_uuid(),
            'validation-missing-profile',
            'missing-profile@example.invalid'
        );
        raise exception 'validation failed: missing profile FK insert succeeded';
    exception
        when foreign_key_violation then null;
    end;

    begin
        insert into public.gmail_connections (
            profile_id,
            google_subject,
            gmail_email
        )
        values (
            current_setting('validation.profile_a')::uuid,
            'validation-google-subject-a-1',
            'duplicate@example.invalid'
        );
        raise exception 'validation failed: duplicate Google subject insert succeeded';
    exception
        when unique_violation then null;
    end;

    begin
        insert into public.gmail_connections (
            profile_id,
            google_subject,
            gmail_email,
            connection_status
        )
        values (
            current_setting('validation.profile_a')::uuid,
            'validation-invalid-status',
            'invalid-status@example.invalid',
            'invalid'
        );
        raise exception 'validation failed: invalid connection status insert succeeded';
    exception
        when check_violation then null;
    end;
end;
$$;

insert into public.gmail_connections (
    profile_id,
    google_subject,
    gmail_email,
    connection_status,
    last_connected_at
)
values
    (
        current_setting('validation.profile_a')::uuid,
        'validation-google-subject-a-limit-2',
        'limit-2@example.invalid',
        'connected',
        now()
    ),
    (
        current_setting('validation.profile_a')::uuid,
        'validation-google-subject-a-limit-3',
        'limit-3@example.invalid',
        'connected',
        now()
    ),
    (
        current_setting('validation.profile_a')::uuid,
        'validation-google-subject-a-limit-4',
        'limit-4@example.invalid',
        'connected',
        now()
    ),
    (
        current_setting('validation.profile_a')::uuid,
        'validation-google-subject-a-limit-5',
        'limit-5@example.invalid',
        'refreshing',
        now()
    );

select pg_temp.assert_true(
    (select count(*) = 5
     from public.gmail_connections
     where profile_id = current_setting('validation.profile_a')::uuid
       and connection_status in ('connected', 'refreshing')),
    'profile A fixture must have five active Gmail connections'
);

do $$
begin
    begin
        insert into public.gmail_connections (
            profile_id,
            google_subject,
            gmail_email,
            connection_status,
            last_connected_at
        )
        values (
            current_setting('validation.profile_a')::uuid,
            'validation-google-subject-a-limit-6',
            'limit-6@example.invalid',
            'connected',
            now()
        );
        raise exception 'validation failed: sixth active Gmail connection succeeded';
    exception
        when check_violation then null;
    end;
end;
$$;

do $$
begin
    begin
        update public.gmail_connections
        set connection_status = 'connected',
            last_connected_at = now()
        where profile_id = current_setting('validation.profile_a')::uuid
          and google_subject = 'validation-google-subject-a-2';
        raise exception 'validation failed: activating a sixth Gmail connection succeeded';
    exception
        when check_violation then null;
    end;
end;
$$;

update public.gmail_connections
set connection_status = 'expired'
where profile_id = current_setting('validation.profile_a')::uuid
  and google_subject = 'validation-google-subject-a-limit-5';

update public.gmail_connections
set connection_status = 'connected',
    last_connected_at = now()
where profile_id = current_setting('validation.profile_a')::uuid
  and google_subject = 'validation-google-subject-a-2';

select pg_temp.assert_true(
    (select count(*) = 5
     from public.gmail_connections
     where profile_id = current_setting('validation.profile_a')::uuid
       and connection_status in ('connected', 'refreshing'))
    and exists (
        select 1
        from public.gmail_connections
        where profile_id = current_setting('validation.profile_a')::uuid
          and google_subject = 'validation-google-subject-a-2'
          and connection_status = 'connected'
    ),
    'active limit must block update activation until an active slot is free'
);

insert into public.gmail_connections (
    profile_id,
    google_subject,
    gmail_email,
    connection_status,
    created_at,
    updated_at
)
values (
    current_setting('validation.profile_b')::uuid,
    'validation-google-subject-b-updated-at',
    'updated-at@example.invalid',
    'disconnected',
    now(),
    '2000-01-01 00:00:00+00'::timestamptz
);

select set_config(
    'validation.updated_at_connection',
    (
        select id::text
        from public.gmail_connections
        where google_subject = 'validation-google-subject-b-updated-at'
    ),
    true
);

update public.gmail_connections
set display_name = 'Updated at validation'
where id = current_setting('validation.updated_at_connection')::uuid;

select pg_temp.assert_true(
    (select updated_at > '2000-01-01 00:00:00+00'::timestamptz
     from public.gmail_connections
     where id = current_setting('validation.updated_at_connection')::uuid),
    'updated_at must advance on an administrative update'
);

set local role authenticated;
select set_config(
    'request.jwt.claim.sub',
    current_setting('validation.user_a'),
    true
);

select pg_temp.assert_true(
    (select count(*) = 6 from public.gmail_connections),
    'user A must read only their own Gmail connections'
);

select pg_temp.assert_true(
    (select count(*) = 0
     from public.gmail_connections
     where profile_id = current_setting('validation.profile_b')::uuid),
    'user A must not read user B Gmail connections'
);

do $$
begin
    begin
        insert into public.gmail_connections (
            profile_id,
            google_subject,
            gmail_email
        )
        values (
            current_setting('validation.profile_a')::uuid,
            'validation-client-insert',
            'client-insert@example.invalid'
        );
        raise exception 'validation failed: authenticated user inserted Gmail connection';
    exception
        when insufficient_privilege then null;
    end;

    begin
        update public.gmail_connections
        set connection_status = 'revoked'
        where profile_id = current_setting('validation.profile_a')::uuid;
        raise exception 'validation failed: authenticated user updated status';
    exception
        when insufficient_privilege then null;
    end;

    begin
        update public.gmail_connections
        set google_subject = 'validation-client-updated-subject'
        where profile_id = current_setting('validation.profile_a')::uuid;
        raise exception 'validation failed: authenticated user updated Google identity';
    exception
        when insufficient_privilege then null;
    end;

    begin
        delete from public.gmail_connections
        where profile_id = current_setting('validation.profile_a')::uuid;
        raise exception 'validation failed: authenticated user deleted Gmail connection';
    exception
        when insufficient_privilege then null;
    end;

    begin
        perform public.enforce_gmail_connections_active_limit();
        raise exception 'validation failed: authenticated user called active limit function';
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
        perform count(*) from public.gmail_connections;
        raise exception 'validation failed: anon read Gmail connections';
    exception
        when insufficient_privilege then null;
    end;
end;
$$;

reset role;

delete from public.profiles
where id = current_setting('validation.profile_b')::uuid;

select pg_temp.assert_true(
    not exists (
        select 1
        from public.gmail_connections
        where profile_id = current_setting('validation.profile_b')::uuid
    ),
    'deleting profile B must cascade to its Gmail connections'
);

select 'gmail connections runtime validation passed' as result;

rollback;
