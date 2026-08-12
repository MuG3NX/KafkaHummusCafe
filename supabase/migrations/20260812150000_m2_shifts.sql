create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  service_day_id uuid not null references public.service_days(id),
  membership_id uuid not null references public.restaurant_memberships(id),
  business_date date not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shifts_service_day_identity_fk
    foreign key (service_day_id, location_id, business_date)
    references public.service_days (id, location_id, business_date),
  constraint shifts_employee_location_assignment_fk
    foreign key (membership_id, location_id)
    references public.membership_location_assignments (membership_id, location_id),
  constraint shifts_end_after_start_check
    check (ended_at is null or ended_at > started_at),
  unique (membership_id, service_day_id)
);

create table public.shift_revisions (
  id uuid primary key default gen_random_uuid(),
  shift_id uuid not null references public.shifts(id),
  version integer not null check (version > 0),
  changed_by uuid not null references auth.users(id),
  reason text not null check (length(trim(reason)) > 0),
  previous_started_at timestamptz not null,
  previous_ended_at timestamptz,
  changed_at timestamptz not null default now(),
  unique (shift_id, version)
);

create unique index shifts_one_open_per_membership_idx
  on public.shifts (membership_id)
  where ended_at is null;

create index shifts_location_date_idx
  on public.shifts (location_id, business_date desc, started_at desc);

create index shifts_membership_date_idx
  on public.shifts (membership_id, business_date desc, started_at desc);

create index shift_revisions_shift_changed_idx
  on public.shift_revisions (shift_id, changed_at desc);

create or replace function public.start_shift(p_location_id uuid)
returns setof public.shifts
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_membership public.restaurant_memberships;
  service_day public.service_days;
  current_business_date date;
  started_at_instant timestamptz := clock_timestamp();
  new_shift public.shifts;
begin
  select m.* into employee_membership
  from public.restaurant_memberships m
  join public.membership_location_assignments a
    on a.membership_id = m.id and a.location_id = p_location_id
  where m.user_id = auth.uid()
  limit 1;

  if employee_membership.id is null then
    raise exception 'Not authorized to start a shift';
  end if;

  current_business_date := public.get_business_date_for_instant(p_location_id, started_at_instant);

  if exists (
    select 1 from public.shifts
    where membership_id = employee_membership.id and ended_at is null
  ) then
    raise exception 'You already have an open shift';
  end if;

  if exists (
    select 1 from public.shifts
    where membership_id = employee_membership.id and business_date = current_business_date
  ) then
    raise exception 'You already have a shift for this service day';
  end if;

  insert into public.service_days (location_id, business_date)
  values (p_location_id, current_business_date)
  on conflict (location_id, business_date) do update set business_date = excluded.business_date
  returning * into service_day;

  insert into public.shifts (
    location_id, service_day_id, membership_id, business_date, started_at
  ) values (
    p_location_id, service_day.id, employee_membership.id, current_business_date, started_at_instant
  ) returning * into new_shift;

  return next new_shift;
end;
$$;

create or replace function public.end_shift(p_shift_id uuid)
returns setof public.shifts
language plpgsql
security definer
set search_path = public
as $$
declare
  shift public.shifts;
  ended_at_instant timestamptz := clock_timestamp();
  closed_shift public.shifts;
begin
  select s.* into shift
  from public.shifts s
  join public.restaurant_memberships m on m.id = s.membership_id
  where s.id = p_shift_id and m.user_id = auth.uid()
  for update;

  if shift.id is null then
    raise exception 'Not authorized to end this shift';
  end if;
  if shift.ended_at is not null then
    raise exception 'This shift is already closed';
  end if;

  update public.shifts
  set ended_at = ended_at_instant, updated_at = ended_at_instant
  where id = shift.id
  returning * into closed_shift;

  return next closed_shift;
end;
$$;

create or replace function public.correct_shift(
  p_shift_id uuid,
  p_started_at timestamptz,
  p_ended_at timestamptz,
  p_reason text
)
returns setof public.shifts
language plpgsql
security definer
set search_path = public
as $$
declare
  shift public.shifts;
  corrected_shift public.shifts;
begin
  select * into shift from public.shifts where id = p_shift_id for update;
  if shift.id is null or not public.is_location_owner(shift.location_id) then
    raise exception 'Only the owner can correct shifts';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'A correction reason is required';
  end if;
  if p_started_at is null then
    raise exception 'A start time is required';
  end if;
  if p_ended_at is not null and p_ended_at <= p_started_at then
    raise exception 'Shift end must be after shift start';
  end if;

  insert into public.shift_revisions (
    shift_id, version, changed_by, reason, previous_started_at, previous_ended_at
  ) values (
    shift.id, shift.version, auth.uid(), trim(p_reason), shift.started_at, shift.ended_at
  );

  update public.shifts
  set started_at = p_started_at,
      ended_at = p_ended_at,
      version = shift.version + 1,
      updated_at = clock_timestamp()
  where id = shift.id
  returning * into corrected_shift;

  return next corrected_shift;
end;
$$;

alter table public.shifts enable row level security;
alter table public.shift_revisions enable row level security;

create policy shifts_read on public.shifts for select using (
  public.is_location_owner(location_id)
  or exists (
    select 1
    from public.restaurant_memberships m
    where m.id = shifts.membership_id
      and m.user_id = auth.uid()
      and public.can_access_location(shifts.location_id)
  )
);

create policy shift_revisions_read on public.shift_revisions for select using (
  public.is_location_owner((select location_id from public.shifts where id = shift_id))
);

revoke all on table public.shifts from anon, authenticated;
revoke all on table public.shift_revisions from anon, authenticated;
grant select on table public.shifts, public.shift_revisions to authenticated;

revoke execute on function public.start_shift(uuid) from public;
revoke execute on function public.end_shift(uuid) from public;
revoke execute on function public.correct_shift(uuid, timestamptz, timestamptz, text) from public;
grant execute on function public.start_shift(uuid) to authenticated;
grant execute on function public.end_shift(uuid) to authenticated;
grant execute on function public.correct_shift(uuid, timestamptz, timestamptz, text) to authenticated;
