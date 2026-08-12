create extension if not exists pgcrypto;

create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id),
  name text not null check (length(trim(name)) > 0),
  timezone text not null default 'Europe/Prague',
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table public.restaurant_memberships (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'manager', 'employee')),
  created_at timestamptz not null default now(),
  unique (restaurant_id, user_id)
);

create table public.membership_location_assignments (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.restaurant_memberships(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete cascade,
  can_submit_revenue boolean not null default false,
  created_at timestamptz not null default now(),
  unique (membership_id, location_id)
);

create table public.service_days (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  business_date date not null,
  created_at timestamptz not null default now(),
  unique (location_id, business_date),
  unique (id, location_id, business_date)
);

create table public.revenue_entries (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  service_day_id uuid not null references public.service_days(id),
  business_date date not null,
  submitted_by uuid not null references auth.users(id),
  total_revenue_czk_minor bigint not null check (total_revenue_czk_minor >= 0),
  card_czk_minor bigint not null check (card_czk_minor >= 0),
  cash_czk_minor bigint not null check (cash_czk_minor >= 0),
  cash_register_expenses_czk_minor bigint not null check (cash_register_expenses_czk_minor >= 0),
  euros_minor bigint not null check (euros_minor >= 0),
  physical_cash_handed_over_czk_minor bigint not null check (physical_cash_handed_over_czk_minor >= 0),
  note text,
  status text not null default 'submitted' check (status = 'submitted'),
  version integer not null default 1 check (version > 0),
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint revenue_entries_service_day_identity_fk
    foreign key (service_day_id, location_id, business_date)
    references public.service_days (id, location_id, business_date),
  unique (location_id, business_date)
);

create table public.revenue_revisions (
  id uuid primary key default gen_random_uuid(),
  revenue_entry_id uuid not null references public.revenue_entries(id),
  version integer not null check (version > 0),
  changed_by uuid not null references auth.users(id),
  reason text not null check (length(trim(reason)) > 0),
  previous_values jsonb not null,
  created_at timestamptz not null default now(),
  unique (revenue_entry_id, version)
);

create index service_days_location_date_idx on public.service_days (location_id, business_date desc);
create index revenue_entries_location_date_idx on public.revenue_entries (location_id, business_date desc);
create index revenue_revisions_entry_created_idx on public.revenue_revisions (revenue_entry_id, created_at desc);

create or replace function public.is_restaurant_member(target_restaurant_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.restaurant_memberships
    where restaurant_id = target_restaurant_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_restaurant_owner(target_restaurant_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.restaurant_memberships
    where restaurant_id = target_restaurant_id and user_id = auth.uid() and role = 'owner'
  );
$$;

create or replace function public.is_location_owner(target_location_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.locations l
    join public.restaurant_memberships m on m.restaurant_id = l.restaurant_id
    where l.id = target_location_id and m.user_id = auth.uid() and m.role = 'owner'
  );
$$;

create or replace function public.can_access_location(target_location_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.locations l
    join public.restaurant_memberships m on m.restaurant_id = l.restaurant_id
    left join public.membership_location_assignments a
      on a.membership_id = m.id and a.location_id = l.id
    where l.id = target_location_id
      and m.user_id = auth.uid()
      and (m.role = 'owner' or a.id is not null)
  );
$$;

create or replace function public.can_submit_revenue(target_location_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.locations l
    join public.restaurant_memberships m on m.restaurant_id = l.restaurant_id
    left join public.membership_location_assignments a
      on a.membership_id = m.id and a.location_id = l.id
    where l.id = target_location_id
      and m.user_id = auth.uid()
      and (m.role = 'owner' or coalesce(a.can_submit_revenue, false))
  );
$$;

create or replace function public.get_current_business_date(target_location_id uuid)
returns date
language plpgsql stable security definer set search_path = public
as $$
declare
  location_timezone text;
  current_business_date date;
begin
  if not public.can_access_location(target_location_id) then
    raise exception 'Not authorized for this location';
  end if;
  select timezone into location_timezone from public.locations where id = target_location_id;
  if location_timezone is null then raise exception 'Location not found'; end if;
  current_business_date := (now() at time zone location_timezone)::date;
  return current_business_date;
end;
$$;

create or replace function public.submit_revenue_entry(
  p_location_id uuid,
  p_business_date date,
  p_total_revenue_czk_minor bigint,
  p_card_czk_minor bigint,
  p_cash_czk_minor bigint,
  p_cash_register_expenses_czk_minor bigint,
  p_euros_minor bigint,
  p_physical_cash_handed_over_czk_minor bigint,
  p_note text default null
)
returns setof public.revenue_entries
language plpgsql security definer set search_path = public
as $$
declare
  location_restaurant_id uuid;
  current_date_for_location date;
  service_day public.service_days;
  existing_entry public.revenue_entries;
  new_entry public.revenue_entries;
begin
  select restaurant_id into location_restaurant_id from public.locations where id = p_location_id;
  if location_restaurant_id is null or not public.can_submit_revenue(p_location_id) then
    raise exception 'Not authorized to submit revenue';
  end if;
  current_date_for_location := public.get_current_business_date(p_location_id);
  if p_business_date <> current_date_for_location then
    raise exception 'Revenue must be submitted for the current service day';
  end if;
  p_note := nullif(trim(p_note), '');
  if p_total_revenue_czk_minor < 0 or p_card_czk_minor < 0 or p_cash_czk_minor < 0
     or p_cash_register_expenses_czk_minor < 0 or p_euros_minor < 0
     or p_physical_cash_handed_over_czk_minor < 0 then
    raise exception 'Money values cannot be negative';
  end if;

  insert into public.service_days (location_id, business_date)
  values (p_location_id, p_business_date)
  on conflict (location_id, business_date) do update set business_date = excluded.business_date
  returning * into service_day;

  select * into existing_entry
  from public.revenue_entries
  where location_id = p_location_id and business_date = p_business_date
  for update;
  if existing_entry.id is not null then
    if existing_entry.submitted_by = auth.uid()
       and existing_entry.total_revenue_czk_minor = p_total_revenue_czk_minor
       and existing_entry.card_czk_minor = p_card_czk_minor
       and existing_entry.cash_czk_minor = p_cash_czk_minor
       and existing_entry.cash_register_expenses_czk_minor = p_cash_register_expenses_czk_minor
       and existing_entry.euros_minor = p_euros_minor
       and existing_entry.physical_cash_handed_over_czk_minor = p_physical_cash_handed_over_czk_minor
       and coalesce(existing_entry.note, '') = coalesce(p_note, '') then
      return next existing_entry;
      return;
    end if;
    raise exception 'This service day already has a submitted revenue entry';
  end if;

  insert into public.revenue_entries (
    location_id, service_day_id, business_date, submitted_by,
    total_revenue_czk_minor, card_czk_minor, cash_czk_minor,
    cash_register_expenses_czk_minor, euros_minor,
    physical_cash_handed_over_czk_minor, note
  ) values (
    p_location_id, service_day.id, p_business_date, auth.uid(),
    p_total_revenue_czk_minor, p_card_czk_minor, p_cash_czk_minor,
    p_cash_register_expenses_czk_minor, p_euros_minor,
    p_physical_cash_handed_over_czk_minor, nullif(trim(p_note), '')
  ) returning * into new_entry;
  return next new_entry;
end;
$$;

create or replace function public.correct_revenue_entry(
  p_revenue_entry_id uuid,
  p_total_revenue_czk_minor bigint,
  p_card_czk_minor bigint,
  p_cash_czk_minor bigint,
  p_cash_register_expenses_czk_minor bigint,
  p_euros_minor bigint,
  p_physical_cash_handed_over_czk_minor bigint,
  p_note text,
  p_reason text
)
returns setof public.revenue_entries
language plpgsql security definer set search_path = public
as $$
declare
  entry public.revenue_entries;
  corrected_entry public.revenue_entries;
begin
  select * into entry from public.revenue_entries where id = p_revenue_entry_id for update;
  if entry.id is null or not public.is_location_owner(entry.location_id) then
    raise exception 'Only the owner can correct revenue';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then raise exception 'A correction reason is required'; end if;
  if p_total_revenue_czk_minor < 0 or p_card_czk_minor < 0 or p_cash_czk_minor < 0
     or p_cash_register_expenses_czk_minor < 0 or p_euros_minor < 0
     or p_physical_cash_handed_over_czk_minor < 0 then
    raise exception 'Money values cannot be negative';
  end if;

  insert into public.revenue_revisions (revenue_entry_id, version, changed_by, reason, previous_values)
  values (
    entry.id, entry.version, auth.uid(), trim(p_reason),
    jsonb_build_object(
      'total_revenue_czk_minor', entry.total_revenue_czk_minor,
      'card_czk_minor', entry.card_czk_minor,
      'cash_czk_minor', entry.cash_czk_minor,
      'cash_register_expenses_czk_minor', entry.cash_register_expenses_czk_minor,
      'euros_minor', entry.euros_minor,
      'physical_cash_handed_over_czk_minor', entry.physical_cash_handed_over_czk_minor,
      'note', entry.note,
      'version', entry.version,
      'updated_at', entry.updated_at
    )
  );
  update public.revenue_entries set
    total_revenue_czk_minor = p_total_revenue_czk_minor,
    card_czk_minor = p_card_czk_minor,
    cash_czk_minor = p_cash_czk_minor,
    cash_register_expenses_czk_minor = p_cash_register_expenses_czk_minor,
    euros_minor = p_euros_minor,
    physical_cash_handed_over_czk_minor = p_physical_cash_handed_over_czk_minor,
    note = nullif(trim(p_note), ''),
    version = entry.version + 1,
    updated_at = now()
  where id = entry.id
  returning * into corrected_entry;
  return next corrected_entry;
end;
$$;

alter table public.restaurants enable row level security;
alter table public.locations enable row level security;
alter table public.profiles enable row level security;
alter table public.restaurant_memberships enable row level security;
alter table public.membership_location_assignments enable row level security;
alter table public.service_days enable row level security;
alter table public.revenue_entries enable row level security;
alter table public.revenue_revisions enable row level security;

create policy restaurants_read on public.restaurants for select using (public.is_restaurant_member(id));
create policy locations_read on public.locations for select using (public.can_access_location(id));
create policy profiles_read on public.profiles for select using (
  id = auth.uid() or exists (
    select 1 from public.restaurant_memberships mine
    join public.restaurant_memberships other on other.restaurant_id = mine.restaurant_id
    where mine.user_id = auth.uid() and other.user_id = profiles.id
  )
);
create policy memberships_read on public.restaurant_memberships for select using (
  user_id = auth.uid() or public.is_restaurant_owner(restaurant_id)
);
create policy membership_location_assignments_read on public.membership_location_assignments for select using (
  exists (
    select 1 from public.restaurant_memberships m
    where m.id = membership_id and (m.user_id = auth.uid() or public.is_restaurant_owner(m.restaurant_id))
  )
);
create policy service_days_read on public.service_days for select using (
  public.can_access_location(location_id)
);
create policy revenue_entries_read on public.revenue_entries for select using (
  public.is_location_owner(location_id)
  or (public.can_submit_revenue(location_id) and business_date = public.get_current_business_date(location_id))
);
create policy revenue_revisions_read on public.revenue_revisions for select using (
  public.is_location_owner((select location_id from public.revenue_entries where id = revenue_entry_id))
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$ begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end; $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

revoke execute on function public.is_restaurant_member(uuid) from public;
revoke execute on function public.is_restaurant_owner(uuid) from public;
revoke execute on function public.is_location_owner(uuid) from public;
revoke execute on function public.can_access_location(uuid) from public;
revoke execute on function public.can_submit_revenue(uuid) from public;
revoke execute on function public.get_current_business_date(uuid) from public;
revoke execute on function public.submit_revenue_entry(uuid, date, bigint, bigint, bigint, bigint, bigint, bigint, text) from public;
revoke execute on function public.correct_revenue_entry(uuid, bigint, bigint, bigint, bigint, bigint, bigint, text, text) from public;
revoke execute on function public.handle_new_user() from public;

grant usage on schema public to authenticated;
grant execute on function public.is_restaurant_member(uuid) to authenticated;
grant execute on function public.is_restaurant_owner(uuid) to authenticated;
grant execute on function public.is_location_owner(uuid) to authenticated;
grant execute on function public.can_access_location(uuid) to authenticated;
grant execute on function public.can_submit_revenue(uuid) to authenticated;
grant select on public.restaurants, public.locations, public.profiles, public.restaurant_memberships, public.membership_location_assignments, public.service_days, public.revenue_entries, public.revenue_revisions to authenticated;
grant execute on function public.get_current_business_date(uuid) to authenticated;
grant execute on function public.submit_revenue_entry(uuid, date, bigint, bigint, bigint, bigint, bigint, bigint, text) to authenticated;
grant execute on function public.correct_revenue_entry(uuid, bigint, bigint, bigint, bigint, bigint, bigint, text, text) to authenticated;
