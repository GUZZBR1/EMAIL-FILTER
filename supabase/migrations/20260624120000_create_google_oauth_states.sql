create table public.google_oauth_states (
    id uuid not null default gen_random_uuid(),
    profile_id uuid not null,
    state_hash text not null,
    return_url text not null,
    created_at timestamptz not null default now(),
    expires_at timestamptz not null,
    consumed_at timestamptz,
    constraint google_oauth_states_pkey primary key (id),
    constraint google_oauth_states_profile_id_fkey
        foreign key (profile_id)
        references public.profiles (id)
        on delete cascade,
    constraint google_oauth_states_state_hash_key unique (state_hash),
    constraint google_oauth_states_state_hash_format
        check (
            state_hash = pg_catalog.lower(state_hash)
            and state_hash ~ '^[0-9a-f]{64}$'
        ),
    constraint google_oauth_states_return_url_not_blank
        check (
            return_url = pg_catalog.btrim(return_url)
            and return_url <> ''
        ),
    constraint google_oauth_states_expires_after_created
        check (expires_at > created_at),
    constraint google_oauth_states_consumed_after_created
        check (consumed_at is null or consumed_at >= created_at)
);

alter table public.google_oauth_states owner to postgres;

create index google_oauth_states_profile_id_idx
    on public.google_oauth_states (profile_id);

create index google_oauth_states_cleanup_idx
    on public.google_oauth_states (expires_at, consumed_at);

alter table public.google_oauth_states enable row level security;

revoke all privileges on table public.google_oauth_states from public;
revoke all privileges on table public.google_oauth_states from anon;
revoke all privileges on table public.google_oauth_states from authenticated;
