create table public.profiles (
    id uuid not null default gen_random_uuid(),
    auth_user_id uuid not null,
    display_name text,
    avatar_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_pkey primary key (id),
    constraint profiles_auth_user_id_key unique (auth_user_id),
    constraint profiles_auth_user_id_fkey
        foreign key (auth_user_id)
        references auth.users (id)
        on delete cascade
);

create function public.set_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = pg_catalog.now();
    return new;
end;
$$;

alter function public.set_profile_updated_at() owner to postgres;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_profile_updated_at();

create function public.create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (
        auth_user_id,
        display_name,
        avatar_url
    )
    values (
        new.id,
        coalesce(
            nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'full_name'), ''),
            nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'name'), '')
        ),
        coalesce(
            nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'avatar_url'), ''),
            nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'picture'), '')
        )
    );

    return new;
end;
$$;

alter function public.create_profile_for_auth_user() owner to postgres;

create trigger auth_user_create_profile
after insert on auth.users
for each row
execute function public.create_profile_for_auth_user();

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
on conflict (auth_user_id) do nothing;

alter table public.profiles enable row level security;

create policy "Authenticated users can read their own profile"
on public.profiles
for select
to authenticated
using (auth.uid() = auth_user_id);

create policy "Authenticated users can update their own profile"
on public.profiles
for update
to authenticated
using (auth.uid() = auth_user_id)
with check (auth.uid() = auth_user_id);

revoke all privileges on table public.profiles from public;
revoke all privileges on table public.profiles from anon;
revoke all privileges on table public.profiles from authenticated;

grant select on table public.profiles to authenticated;
grant update (display_name, avatar_url) on table public.profiles to authenticated;

revoke all on function public.set_profile_updated_at() from public;
revoke all on function public.set_profile_updated_at() from anon;
revoke all on function public.set_profile_updated_at() from authenticated;

revoke all on function public.create_profile_for_auth_user() from public;
revoke all on function public.create_profile_for_auth_user() from anon;
revoke all on function public.create_profile_for_auth_user() from authenticated;
