create table public.cash_expense_entries (
  id uuid primary key,
  location_id uuid not null references public.locations(id),
  service_day_id uuid not null references public.service_days(id),
  business_date date not null,
  amount_czk_minor bigint not null check (amount_czk_minor > 0),
  description text not null check (description = trim(description) and length(description) > 0),
  status text not null default 'draft' check (status in ('draft', 'confirmed')),
  version integer not null default 1 check (version > 0),
  captured_by uuid not null references auth.users(id),
  captured_at timestamptz not null default now(),
  confirmed_by uuid null references auth.users(id),
  confirmed_at timestamptz null,
  confirmed_version integer null check (confirmed_version is null or confirmed_version > 0),
  updated_at timestamptz not null default now(),
  constraint cash_expense_entries_service_day_identity_fk
    foreign key (service_day_id, location_id, business_date)
    references public.service_days (id, location_id, business_date),
  constraint cash_expense_entries_confirmation_state_check check (
    (status = 'draft'
      and confirmed_by is null
      and confirmed_at is null
      and confirmed_version is null)
    or
    (status = 'confirmed'
      and confirmed_by is not null
      and confirmed_at is not null
      and confirmed_version = version)
  )
);

create table public.cash_expense_audit_events (
  id uuid primary key default gen_random_uuid(),
  cash_expense_id uuid not null references public.cash_expense_entries(id),
  event_type text not null check (event_type in ('captured', 'confirmed', 'corrected')),
  expense_version integer not null check (expense_version > 0),
  actor_id uuid not null references auth.users(id),
  reason text null,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  unique (cash_expense_id, event_type, expense_version),
  constraint cash_expense_audit_reason_check check (
    (event_type = 'corrected' and reason is not null and reason = trim(reason) and length(reason) > 0)
    or (event_type <> 'corrected' and reason is null)
  )
);

create index cash_expense_entries_location_date_idx
  on public.cash_expense_entries (location_id, business_date desc, captured_at desc);
create index cash_expense_audit_events_expense_created_idx
  on public.cash_expense_audit_events (cash_expense_id, created_at, id);

create or replace function public.can_manage_cash_expenses(target_location_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.locations location
    join public.restaurant_memberships membership
      on membership.restaurant_id = location.restaurant_id
    left join public.membership_location_assignments assignment
      on assignment.membership_id = membership.id
     and assignment.location_id = location.id
    where location.id = target_location_id
      and membership.user_id = auth.uid()
      and (
        membership.role = 'owner'
        or (membership.role = 'manager' and assignment.id is not null)
      )
  );
$$;

create or replace function public.capture_cash_expense(
  p_expense_id uuid,
  p_location_id uuid,
  p_business_date date,
  p_amount_czk_minor bigint,
  p_description text
)
returns setof public.cash_expense_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_description text;
  current_date_for_location date;
  target_service_day public.service_days;
  existing_entry public.cash_expense_entries;
  captured_entry public.cash_expense_entries;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_expense_id is null or p_location_id is null or p_business_date is null then
    raise exception 'Expense id, location and service day are required';
  end if;

  normalized_description := trim(coalesce(p_description, ''));
  if p_amount_czk_minor is null or p_amount_czk_minor <= 0 then
    raise exception 'Cash expense amount must be greater than zero';
  end if;
  if length(normalized_description) = 0 then
    raise exception 'A description or reason is required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_expense_id::text, 0));
  select * into existing_entry
  from public.cash_expense_entries
  where id = p_expense_id
  for update;

  if existing_entry.id is not null then
    if not public.can_manage_cash_expenses(existing_entry.location_id) then
      raise exception 'Not authorized to manage this cash expense';
    end if;
    if existing_entry.version = 1
       and existing_entry.location_id = p_location_id
       and existing_entry.business_date = p_business_date
       and existing_entry.amount_czk_minor = p_amount_czk_minor
       and existing_entry.description = normalized_description
       and existing_entry.captured_by = auth.uid() then
      return next existing_entry;
      return;
    end if;
    raise exception 'Expense id is already used with a different capture payload';
  end if;

  if not public.can_manage_cash_expenses(p_location_id) then
    raise exception 'Not authorized to capture cash expenses for this location';
  end if;
  current_date_for_location := public.get_current_business_date(p_location_id);
  if p_business_date > current_date_for_location then
    raise exception 'Cash expenses cannot be assigned to a future service day';
  end if;

  insert into public.service_days (location_id, business_date)
  values (p_location_id, p_business_date)
  on conflict (location_id, business_date)
  do update set business_date = excluded.business_date
  returning * into target_service_day;

  insert into public.cash_expense_entries (
    id, location_id, service_day_id, business_date, amount_czk_minor,
    description, status, version, captured_by, captured_at, updated_at
  ) values (
    p_expense_id, p_location_id, target_service_day.id, p_business_date,
    p_amount_czk_minor, normalized_description, 'draft', 1, auth.uid(), now(), now()
  )
  returning * into captured_entry;

  insert into public.cash_expense_audit_events (
    cash_expense_id, event_type, expense_version, actor_id, payload
  ) values (
    captured_entry.id,
    'captured',
    captured_entry.version,
    auth.uid(),
    jsonb_build_object(
      'location_id', captured_entry.location_id,
      'service_day_id', captured_entry.service_day_id,
      'business_date', captured_entry.business_date,
      'amount_czk_minor', captured_entry.amount_czk_minor,
      'description', captured_entry.description,
      'status', captured_entry.status,
      'version', captured_entry.version,
      'captured_by', captured_entry.captured_by,
      'captured_at', captured_entry.captured_at
    )
  );

  return next captured_entry;
end;
$$;

create or replace function public.confirm_cash_expense(
  p_expense_id uuid,
  p_expected_version integer
)
returns setof public.cash_expense_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_entry public.cash_expense_entries;
  confirmed_entry public.cash_expense_entries;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  select * into existing_entry
  from public.cash_expense_entries
  where id = p_expense_id
  for update;

  if existing_entry.id is null
     or not public.can_manage_cash_expenses(existing_entry.location_id) then
    raise exception 'Not authorized to confirm this cash expense';
  end if;
  if p_expected_version is null or existing_entry.version <> p_expected_version then
    raise exception 'Cash expense version is stale';
  end if;
  if existing_entry.status = 'confirmed'
     and existing_entry.confirmed_version = p_expected_version then
    return next existing_entry;
    return;
  end if;

  update public.cash_expense_entries
  set status = 'confirmed',
      confirmed_by = auth.uid(),
      confirmed_at = now(),
      confirmed_version = version,
      updated_at = now()
  where id = existing_entry.id
  returning * into confirmed_entry;

  insert into public.cash_expense_audit_events (
    cash_expense_id, event_type, expense_version, actor_id, payload
  ) values (
    confirmed_entry.id,
    'confirmed',
    confirmed_entry.version,
    auth.uid(),
    jsonb_build_object(
      'status', confirmed_entry.status,
      'confirmed_version', confirmed_entry.confirmed_version,
      'confirmed_by', confirmed_entry.confirmed_by,
      'confirmed_at', confirmed_entry.confirmed_at
    )
  );

  return next confirmed_entry;
end;
$$;

create or replace function public.correct_cash_expense(
  p_expense_id uuid,
  p_expected_version integer,
  p_business_date date,
  p_amount_czk_minor bigint,
  p_description text,
  p_reason text
)
returns setof public.cash_expense_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_entry public.cash_expense_entries;
  corrected_entry public.cash_expense_entries;
  target_service_day public.service_days;
  normalized_description text;
  normalized_reason text;
  current_date_for_location date;
  next_version integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  select * into existing_entry
  from public.cash_expense_entries
  where id = p_expense_id
  for update;

  if existing_entry.id is null
     or not public.can_manage_cash_expenses(existing_entry.location_id) then
    raise exception 'Not authorized to correct this cash expense';
  end if;
  if p_expected_version is null or existing_entry.version <> p_expected_version then
    raise exception 'Cash expense version is stale';
  end if;

  normalized_description := trim(coalesce(p_description, ''));
  normalized_reason := trim(coalesce(p_reason, ''));
  if p_amount_czk_minor is null or p_amount_czk_minor <= 0 then
    raise exception 'Cash expense amount must be greater than zero';
  end if;
  if length(normalized_description) = 0 then
    raise exception 'A description or reason is required';
  end if;
  if length(normalized_reason) = 0 then
    raise exception 'A correction reason is required';
  end if;
  if p_business_date is null then
    raise exception 'A service day is required';
  end if;

  current_date_for_location := public.get_current_business_date(existing_entry.location_id);
  if p_business_date > current_date_for_location then
    raise exception 'Cash expenses cannot be assigned to a future service day';
  end if;

  insert into public.service_days (location_id, business_date)
  values (existing_entry.location_id, p_business_date)
  on conflict (location_id, business_date)
  do update set business_date = excluded.business_date
  returning * into target_service_day;

  next_version := existing_entry.version + 1;

  insert into public.cash_expense_audit_events (
    cash_expense_id, event_type, expense_version, actor_id, reason, payload
  ) values (
    existing_entry.id,
    'corrected',
    next_version,
    auth.uid(),
    normalized_reason,
    jsonb_build_object(
      'location_id', existing_entry.location_id,
      'service_day_id', existing_entry.service_day_id,
      'business_date', existing_entry.business_date,
      'amount_czk_minor', existing_entry.amount_czk_minor,
      'description', existing_entry.description,
      'status', existing_entry.status,
      'version', existing_entry.version,
      'captured_by', existing_entry.captured_by,
      'captured_at', existing_entry.captured_at,
      'confirmed_by', existing_entry.confirmed_by,
      'confirmed_at', existing_entry.confirmed_at,
      'confirmed_version', existing_entry.confirmed_version,
      'updated_at', existing_entry.updated_at
    )
  );

  update public.cash_expense_entries
  set service_day_id = target_service_day.id,
      business_date = p_business_date,
      amount_czk_minor = p_amount_czk_minor,
      description = normalized_description,
      status = 'draft',
      version = next_version,
      confirmed_by = null,
      confirmed_at = null,
      confirmed_version = null,
      updated_at = now()
  where id = existing_entry.id
  returning * into corrected_entry;

  return next corrected_entry;
end;
$$;

alter table public.cash_expense_entries enable row level security;
alter table public.cash_expense_audit_events enable row level security;

create policy cash_expense_entries_read
on public.cash_expense_entries
for select
using (public.can_manage_cash_expenses(location_id));

create policy cash_expense_audit_events_read
on public.cash_expense_audit_events
for select
using (
  public.can_manage_cash_expenses((
    select entry.location_id
    from public.cash_expense_entries entry
    where entry.id = cash_expense_id
  ))
);

revoke all on public.cash_expense_entries from public, anon, authenticated;
revoke all on public.cash_expense_audit_events from public, anon, authenticated;
grant select on public.cash_expense_entries, public.cash_expense_audit_events to authenticated;

revoke execute on function public.can_manage_cash_expenses(uuid) from public, anon, authenticated;
revoke execute on function public.capture_cash_expense(uuid, uuid, date, bigint, text) from public, anon, authenticated;
revoke execute on function public.confirm_cash_expense(uuid, integer) from public, anon, authenticated;
revoke execute on function public.correct_cash_expense(uuid, integer, date, bigint, text, text) from public, anon, authenticated;

grant execute on function public.can_manage_cash_expenses(uuid) to authenticated;
grant execute on function public.capture_cash_expense(uuid, uuid, date, bigint, text) to authenticated;
grant execute on function public.confirm_cash_expense(uuid, integer) to authenticated;
grant execute on function public.correct_cash_expense(uuid, integer, date, bigint, text, text) to authenticated;
