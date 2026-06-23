create table public.gmail_connections (
    id uuid not null default gen_random_uuid(),
    profile_id uuid not null,
    google_subject text not null,
    gmail_email text not null,
    gmail_email_normalized text generated always as (
        pg_catalog.lower(gmail_email)
    ) stored,
    display_name text,
    avatar_url text,
    connection_status text not null default 'disconnected',
    granted_scopes text[] not null default array[]::text[],
    last_connected_at timestamptz,
    last_validated_at timestamptz,
    revoked_at timestamptz,
    disconnected_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint gmail_connections_pkey primary key (id),
    constraint gmail_connections_profile_google_subject_key
        unique (profile_id, google_subject),
    constraint gmail_connections_profile_id_fkey
        foreign key (profile_id)
        references public.profiles (id)
        on delete cascade,
    constraint gmail_connections_google_subject_not_blank
        check (
            google_subject = pg_catalog.btrim(google_subject)
            and google_subject <> ''
        ),
    constraint gmail_connections_gmail_email_not_blank
        check (
            gmail_email = pg_catalog.btrim(gmail_email)
            and gmail_email <> ''
        ),
    constraint gmail_connections_status_check
        check (
            connection_status in (
                'connected',
                'revoked',
                'blocked_by_workspace_admin',
                'expired',
                'refreshing',
                'disconnected'
            )
        ),
    constraint gmail_connections_granted_scopes_no_nulls
        check (array_position(granted_scopes, null) is null)
);

alter table public.gmail_connections owner to postgres;

create function public.enforce_gmail_connections_active_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    active_connection_count integer;
    active_connection_limit integer;
begin
    if new.connection_status in ('connected', 'refreshing') then
        active_connection_limit := coalesce(
            nullif(
                pg_catalog.current_setting(
                    'app.gmail_connections_active_limit',
                    true
                ),
                ''
            )::integer,
            5
        );

        if active_connection_limit < 1 then
            raise exception 'app.gmail_connections_active_limit must be greater than zero'
                using errcode = 'check_violation';
        end if;

        perform pg_catalog.pg_advisory_xact_lock(
            pg_catalog.hashtextextended(new.profile_id::text, 0)
        );

        if tg_op = 'INSERT' then
            select count(*)
            into active_connection_count
            from public.gmail_connections as connection
            where connection.profile_id = new.profile_id
              and connection.connection_status in ('connected', 'refreshing');
        else
            select count(*)
            into active_connection_count
            from public.gmail_connections as connection
            where connection.profile_id = new.profile_id
              and connection.connection_status in ('connected', 'refreshing')
              and connection.id <> old.id;
        end if;

        if active_connection_count >= active_connection_limit then
            raise exception 'a profile can have at most % active Gmail connections',
                active_connection_limit
                using errcode = 'check_violation';
        end if;
    end if;

    return new;
end;
$$;

alter function public.enforce_gmail_connections_active_limit() owner to postgres;

create trigger gmail_connections_enforce_active_limit
before insert or update on public.gmail_connections
for each row
execute function public.enforce_gmail_connections_active_limit();

create trigger gmail_connections_set_updated_at
before update on public.gmail_connections
for each row
execute function public.set_profile_updated_at();

alter table public.gmail_connections enable row level security;

create policy "Authenticated users can read their own Gmail connections"
on public.gmail_connections
for select
to authenticated
using (
    exists (
        select 1
        from public.profiles
        where profiles.id = gmail_connections.profile_id
          and profiles.auth_user_id = auth.uid()
    )
);

revoke all privileges on table public.gmail_connections from public;
revoke all privileges on table public.gmail_connections from anon;
revoke all privileges on table public.gmail_connections from authenticated;

grant select on table public.gmail_connections to authenticated;

revoke all on function public.enforce_gmail_connections_active_limit()
    from public;
revoke all on function public.enforce_gmail_connections_active_limit()
    from anon;
revoke all on function public.enforce_gmail_connections_active_limit()
    from authenticated;
