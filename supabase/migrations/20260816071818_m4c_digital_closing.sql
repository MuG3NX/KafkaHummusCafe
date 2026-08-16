alter table public.membership_location_assignments
  add column can_close_day boolean not null default false;

create table public.service_day_closures (
  id uuid primary key,
  location_id uuid not null references public.locations(id),
  service_day_id uuid not null references public.service_days(id),
  business_date date not null,
  revenue_entry_id uuid not null references public.revenue_entries(id),
  revenue_entry_version integer not null check (revenue_entry_version > 0),
  usd_minor bigint not null check (usd_minor >= 0),
  gbp_minor bigint not null check (gbp_minor >= 0),
  physical_eur_minor bigint not null check (physical_eur_minor >= 0),
  physical_usd_minor bigint not null check (physical_usd_minor >= 0),
  physical_gbp_minor bigint not null check (physical_gbp_minor >= 0),
  note text,
  cash_expense_confirmed_minor_at_close bigint not null check (cash_expense_confirmed_minor_at_close >= 0),
  cash_expense_fingerprint_at_close text not null check (cash_expense_fingerprint_at_close ~ '^[0-9a-f]{64}$'),
  cash_expense_difference_minor_at_close bigint not null,
  cash_expense_acknowledgment_id_at_close uuid null references public.cash_expense_reconciliation_acknowledgments(id),
  version integer not null default 1 check (version > 0),
  closed_by uuid not null references auth.users(id),
  closed_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_day_closures_service_day_identity_fk
    foreign key (service_day_id, location_id, business_date)
    references public.service_days (id, location_id, business_date),
  unique (location_id, business_date)
);

create table public.service_day_closure_revisions (
  id uuid primary key default gen_random_uuid(),
  closure_id uuid not null references public.service_day_closures(id),
  version integer not null check (version > 0),
  changed_by uuid not null references auth.users(id),
  reason text not null check (reason = trim(reason) and length(reason) > 0),
  previous_values jsonb not null check (jsonb_typeof(previous_values) = 'object'),
  changed_at timestamptz not null default now(),
  unique (closure_id, version)
);

create table public.service_day_handoff_notes (
  id uuid primary key,
  location_id uuid not null references public.locations(id),
  service_day_id uuid not null references public.service_days(id),
  business_date date not null,
  note text not null check (note = trim(note) and length(note) > 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  constraint service_day_handoff_notes_service_day_identity_fk
    foreign key (service_day_id, location_id, business_date)
    references public.service_days (id, location_id, business_date)
);

create index service_day_closures_location_date_idx
  on public.service_day_closures (location_id, business_date desc);
create index service_day_closure_revisions_closure_changed_idx
  on public.service_day_closure_revisions (closure_id, changed_at desc, id);
create index service_day_handoff_notes_location_date_idx
  on public.service_day_handoff_notes (location_id, business_date desc, created_at desc, id);

create or replace function public.can_close_service_day(target_location_id uuid)
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
        or coalesce(assignment.can_close_day, false)
      )
  );
$$;

create or replace function public.cash_expense_reconciliation_snapshot(
  p_location_id uuid,
  p_business_date date
)
returns table (
  revenue_entry_id uuid,
  revenue_entry_version integer,
  closing_minor bigint,
  confirmed_minor bigint,
  confirmed_fingerprint text,
  difference_minor bigint,
  current_acknowledgment_id uuid,
  current_acknowledgment_reason text
)
language sql
stable
security definer
set search_path = public
as $$
  with revenue as (
    select
      entry.id,
      entry.version,
      entry.cash_register_expenses_czk_minor
    from public.revenue_entries entry
    where entry.location_id = p_location_id
      and entry.business_date = p_business_date
    limit 1
  ),
  expense_summary as (
    select
      coalesce(sum(entry.amount_czk_minor) filter (where entry.status = 'confirmed'), 0)::bigint as confirmed_minor,
      encode(
        extensions.digest(
          coalesce(
            string_agg(
              entry.id::text || ':' || entry.version::text || ':' || entry.amount_czk_minor::text,
              '|' order by entry.id::text
            ) filter (where entry.status = 'confirmed'),
            ''
          ),
          'sha256'
        ),
        'hex'
      ) as confirmed_fingerprint
    from public.cash_expense_entries entry
    where entry.location_id = p_location_id
      and entry.business_date = p_business_date
  ),
  current_values as (
    select
      revenue.id as revenue_entry_id,
      revenue.version as revenue_entry_version,
      revenue.cash_register_expenses_czk_minor as closing_minor,
      expense_summary.confirmed_minor,
      expense_summary.confirmed_fingerprint,
      case
        when revenue.id is null then null::bigint
        else revenue.cash_register_expenses_czk_minor - expense_summary.confirmed_minor
      end as difference_minor
    from expense_summary
    left join revenue on true
  )
  select
    current_values.revenue_entry_id,
    current_values.revenue_entry_version,
    current_values.closing_minor,
    current_values.confirmed_minor,
    current_values.confirmed_fingerprint,
    current_values.difference_minor,
    current_ack.id,
    current_ack.reason
  from current_values
  left join lateral (
    select acknowledgment.id, acknowledgment.reason
    from public.cash_expense_reconciliation_acknowledgments acknowledgment
    where current_values.revenue_entry_id is not null
      and acknowledgment.location_id = p_location_id
      and acknowledgment.business_date = p_business_date
      and acknowledgment.revenue_entry_id = current_values.revenue_entry_id
      and acknowledgment.revenue_entry_version = current_values.revenue_entry_version
      and acknowledgment.revenue_cash_register_expenses_czk_minor = current_values.closing_minor
      and acknowledgment.confirmed_cash_expenses_czk_minor = current_values.confirmed_minor
      and acknowledgment.confirmed_source_fingerprint = current_values.confirmed_fingerprint
      and acknowledgment.difference_czk_minor = current_values.difference_minor
    order by acknowledgment.acknowledged_at desc, acknowledgment.id desc
    limit 1
  ) current_ack on true;
$$;

create or replace function public.close_service_day(
  p_closure_id uuid,
  p_location_id uuid,
  p_business_date date,
  p_expected_revenue_entry_id uuid,
  p_expected_revenue_entry_version integer,
  p_usd_minor bigint,
  p_gbp_minor bigint,
  p_physical_eur_minor bigint,
  p_physical_usd_minor bigint,
  p_physical_gbp_minor bigint,
  p_note text default null
)
returns setof public.service_day_closures
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_note text;
  current_business_date date;
  owner_actor boolean;
  existing_by_id public.service_day_closures;
  existing_for_day public.service_day_closures;
  revenue_entry public.revenue_entries;
  reconciliation record;
  created_closure public.service_day_closures;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_closure_id is null or p_location_id is null or p_business_date is null then
    raise exception 'Closure id, location and service day are required';
  end if;
  if p_expected_revenue_entry_id is null
     or p_expected_revenue_entry_version is null
     or p_expected_revenue_entry_version <= 0 then
    raise exception 'A complete expected Revenue snapshot is required';
  end if;
  if p_usd_minor is null or p_usd_minor < 0
     or p_gbp_minor is null or p_gbp_minor < 0
     or p_physical_eur_minor is null or p_physical_eur_minor < 0
     or p_physical_usd_minor is null or p_physical_usd_minor < 0
     or p_physical_gbp_minor is null or p_physical_gbp_minor < 0 then
    raise exception 'Closing money values cannot be negative';
  end if;

  normalized_note := nullif(trim(coalesce(p_note, '')), '');

  perform pg_advisory_xact_lock(hashtextextended(p_location_id::text || ':' || p_business_date::text, 0));
  perform pg_advisory_xact_lock(hashtextextended(p_closure_id::text, 0));

  select * into existing_by_id
  from public.service_day_closures closure
  where closure.id = p_closure_id
  for update;

  if existing_by_id.id is not null then
    if not public.can_close_service_day(existing_by_id.location_id) then
      raise exception 'Not authorized to access this close';
    end if;
    if existing_by_id.location_id = p_location_id
       and existing_by_id.business_date = p_business_date
       and existing_by_id.revenue_entry_id = p_expected_revenue_entry_id
       and existing_by_id.revenue_entry_version = p_expected_revenue_entry_version
       and existing_by_id.usd_minor = p_usd_minor
       and existing_by_id.gbp_minor = p_gbp_minor
       and existing_by_id.physical_eur_minor = p_physical_eur_minor
       and existing_by_id.physical_usd_minor = p_physical_usd_minor
       and existing_by_id.physical_gbp_minor = p_physical_gbp_minor
       and coalesce(existing_by_id.note, '') = coalesce(normalized_note, '')
       and existing_by_id.closed_by = auth.uid() then
      return next existing_by_id;
      return;
    end if;
    raise exception 'Closure id is already used with a different payload';
  end if;

  if not public.can_close_service_day(p_location_id) then
    raise exception 'Not authorized to close this service day';
  end if;

  current_business_date := public.get_current_business_date(p_location_id);
  if p_business_date > current_business_date then
    raise exception 'A future service day cannot be closed';
  end if;

  owner_actor := public.is_location_owner(p_location_id);
  if not owner_actor and p_business_date <> current_business_date then
    raise exception 'Operational closers may close only the current service day';
  end if;

  select * into existing_for_day
  from public.service_day_closures closure
  where closure.location_id = p_location_id
    and closure.business_date = p_business_date
  for update;

  if existing_for_day.id is not null then
    raise exception 'This service day is already closed';
  end if;

  select * into revenue_entry
  from public.revenue_entries entry
  where entry.id = p_expected_revenue_entry_id
    and entry.location_id = p_location_id
    and entry.business_date = p_business_date
  for share;

  if revenue_entry.id is null then
    raise exception 'Revenue must be submitted before closing the service day';
  end if;
  if revenue_entry.version <> p_expected_revenue_entry_version then
    raise exception 'Revenue changed; reload the closing review before closing';
  end if;

  select * into reconciliation
  from public.cash_expense_reconciliation_snapshot(p_location_id, p_business_date);

  insert into public.service_day_closures (
    id,
    location_id,
    service_day_id,
    business_date,
    revenue_entry_id,
    revenue_entry_version,
    usd_minor,
    gbp_minor,
    physical_eur_minor,
    physical_usd_minor,
    physical_gbp_minor,
    note,
    cash_expense_confirmed_minor_at_close,
    cash_expense_fingerprint_at_close,
    cash_expense_difference_minor_at_close,
    cash_expense_acknowledgment_id_at_close,
    version,
    closed_by,
    closed_at,
    updated_at
  ) values (
    p_closure_id,
    p_location_id,
    revenue_entry.service_day_id,
    p_business_date,
    revenue_entry.id,
    revenue_entry.version,
    p_usd_minor,
    p_gbp_minor,
    p_physical_eur_minor,
    p_physical_usd_minor,
    p_physical_gbp_minor,
    normalized_note,
    reconciliation.confirmed_minor,
    reconciliation.confirmed_fingerprint,
    reconciliation.difference_minor,
    reconciliation.current_acknowledgment_id,
    1,
    auth.uid(),
    now(),
    now()
  )
  returning * into created_closure;

  return next created_closure;
end;
$$;

create or replace function public.correct_service_day_closure(
  p_closure_id uuid,
  p_expected_version integer,
  p_expected_revenue_entry_id uuid,
  p_expected_revenue_entry_version integer,
  p_usd_minor bigint,
  p_gbp_minor bigint,
  p_physical_eur_minor bigint,
  p_physical_usd_minor bigint,
  p_physical_gbp_minor bigint,
  p_note text,
  p_reason text
)
returns setof public.service_day_closures
language plpgsql
security definer
set search_path = public
as $$
declare
  closure public.service_day_closures;
  revenue_entry public.revenue_entries;
  reconciliation record;
  normalized_note text;
  normalized_reason text;
  corrected_closure public.service_day_closures;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  normalized_note := nullif(trim(coalesce(p_note, '')), '');
  normalized_reason := trim(coalesce(p_reason, ''));
  if length(normalized_reason) = 0 then
    raise exception 'A correction reason is required';
  end if;
  if p_expected_version is null or p_expected_version <= 0
     or p_expected_revenue_entry_id is null
     or p_expected_revenue_entry_version is null
     or p_expected_revenue_entry_version <= 0 then
    raise exception 'A complete expected closure and Revenue snapshot is required';
  end if;
  if p_usd_minor is null or p_usd_minor < 0
     or p_gbp_minor is null or p_gbp_minor < 0
     or p_physical_eur_minor is null or p_physical_eur_minor < 0
     or p_physical_usd_minor is null or p_physical_usd_minor < 0
     or p_physical_gbp_minor is null or p_physical_gbp_minor < 0 then
    raise exception 'Closing money values cannot be negative';
  end if;

  select * into closure
  from public.service_day_closures current_closure
  where current_closure.id = p_closure_id
  for update;

  if closure.id is null or not public.is_location_owner(closure.location_id) then
    raise exception 'Only the owner can correct a completed close';
  end if;
  if closure.version <> p_expected_version then
    raise exception 'Closure version is stale';
  end if;

  select * into revenue_entry
  from public.revenue_entries entry
  where entry.id = p_expected_revenue_entry_id
    and entry.location_id = closure.location_id
    and entry.business_date = closure.business_date
  for share;

  if revenue_entry.id is null then
    raise exception 'The expected Revenue entry does not match this close';
  end if;
  if revenue_entry.version <> p_expected_revenue_entry_version then
    raise exception 'Revenue changed; reload before correcting the close';
  end if;

  select * into reconciliation
  from public.cash_expense_reconciliation_snapshot(closure.location_id, closure.business_date);

  insert into public.service_day_closure_revisions (
    closure_id,
    version,
    changed_by,
    reason,
    previous_values
  ) values (
    closure.id,
    closure.version,
    auth.uid(),
    normalized_reason,
    jsonb_build_object(
      'revenue_entry_id', closure.revenue_entry_id,
      'revenue_entry_version', closure.revenue_entry_version,
      'usd_minor', closure.usd_minor,
      'gbp_minor', closure.gbp_minor,
      'physical_eur_minor', closure.physical_eur_minor,
      'physical_usd_minor', closure.physical_usd_minor,
      'physical_gbp_minor', closure.physical_gbp_minor,
      'note', closure.note,
      'cash_expense_confirmed_minor_at_close', closure.cash_expense_confirmed_minor_at_close,
      'cash_expense_fingerprint_at_close', closure.cash_expense_fingerprint_at_close,
      'cash_expense_difference_minor_at_close', closure.cash_expense_difference_minor_at_close,
      'cash_expense_acknowledgment_id_at_close', closure.cash_expense_acknowledgment_id_at_close,
      'version', closure.version,
      'closed_by', closure.closed_by,
      'closed_at', closure.closed_at,
      'updated_at', closure.updated_at
    )
  );

  update public.service_day_closures
  set revenue_entry_id = revenue_entry.id,
      revenue_entry_version = revenue_entry.version,
      usd_minor = p_usd_minor,
      gbp_minor = p_gbp_minor,
      physical_eur_minor = p_physical_eur_minor,
      physical_usd_minor = p_physical_usd_minor,
      physical_gbp_minor = p_physical_gbp_minor,
      note = normalized_note,
      cash_expense_confirmed_minor_at_close = reconciliation.confirmed_minor,
      cash_expense_fingerprint_at_close = reconciliation.confirmed_fingerprint,
      cash_expense_difference_minor_at_close = reconciliation.difference_minor,
      cash_expense_acknowledgment_id_at_close = reconciliation.current_acknowledgment_id,
      version = closure.version + 1,
      updated_at = now()
  where id = closure.id
  returning * into corrected_closure;

  return next corrected_closure;
end;
$$;

create or replace function public.add_service_day_handoff_note(
  p_note_id uuid,
  p_location_id uuid,
  p_business_date date,
  p_note text
)
returns setof public.service_day_handoff_notes
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_note text;
  current_business_date date;
  owner_actor boolean;
  existing_note public.service_day_handoff_notes;
  service_day public.service_days;
  created_note public.service_day_handoff_notes;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_note_id is null or p_location_id is null or p_business_date is null then
    raise exception 'Note id, location and service day are required';
  end if;
  normalized_note := trim(coalesce(p_note, ''));
  if length(normalized_note) = 0 then
    raise exception 'A handoff note is required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_note_id::text, 0));

  select * into existing_note
  from public.service_day_handoff_notes note
  where note.id = p_note_id
  for update;

  if existing_note.id is not null then
    if not public.can_close_service_day(existing_note.location_id) then
      raise exception 'Not authorized to access this handoff note';
    end if;
    if existing_note.location_id = p_location_id
       and existing_note.business_date = p_business_date
       and existing_note.note = normalized_note
       and existing_note.created_by = auth.uid() then
      return next existing_note;
      return;
    end if;
    raise exception 'Handoff note id is already used with a different payload';
  end if;

  if not public.can_close_service_day(p_location_id) then
    raise exception 'Not authorized to add a handoff note';
  end if;

  current_business_date := public.get_current_business_date(p_location_id);
  if p_business_date > current_business_date then
    raise exception 'A future service day cannot receive a handoff note';
  end if;
  owner_actor := public.is_location_owner(p_location_id);
  if not owner_actor and p_business_date <> current_business_date then
    raise exception 'Operational closers may add notes only to the current service day';
  end if;

  insert into public.service_days (location_id, business_date)
  values (p_location_id, p_business_date)
  on conflict (location_id, business_date)
  do update set business_date = excluded.business_date
  returning * into service_day;

  insert into public.service_day_handoff_notes (
    id,
    location_id,
    service_day_id,
    business_date,
    note,
    created_by,
    created_at
  ) values (
    p_note_id,
    p_location_id,
    service_day.id,
    p_business_date,
    normalized_note,
    auth.uid(),
    now()
  )
  returning * into created_note;

  return next created_note;
end;
$$;

create or replace function public.get_service_day_close_state(
  p_location_id uuid,
  p_business_date date
)
returns table (
  location_id uuid,
  service_day_id uuid,
  business_date date,
  current_business_date date,
  has_revenue boolean,
  revenue_entry_id uuid,
  revenue_entry_version integer,
  total_revenue_czk_minor text,
  card_czk_minor text,
  cash_czk_minor text,
  cash_register_expenses_czk_minor text,
  euros_minor text,
  physical_cash_handed_over_czk_minor text,
  is_closed boolean,
  closure_id uuid,
  closure_version integer,
  closure_revenue_entry_id uuid,
  closure_revenue_entry_version integer,
  revenue_binding_current boolean,
  usd_minor text,
  gbp_minor text,
  physical_eur_minor text,
  physical_usd_minor text,
  physical_gbp_minor text,
  closure_note text,
  closed_by uuid,
  closed_at timestamptz,
  closing_snapshot_confirmed_minor text,
  closing_snapshot_difference_minor text,
  closing_snapshot_acknowledgment_id uuid,
  current_confirmed_cash_expenses_minor text,
  current_cash_expense_difference_minor text,
  current_cash_expense_acknowledgment_id uuid,
  current_cash_expense_acknowledgment_reason text,
  draft_cash_expense_count integer,
  open_shift_count integer,
  invoices_needing_review_count integer,
  handoff_note_count integer,
  latest_handoff_note text,
  latest_handoff_note_by uuid,
  latest_handoff_note_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_date_for_location date;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_location_id is null or p_business_date is null then
    raise exception 'Location and service day are required';
  end if;
  if not public.can_close_service_day(p_location_id) then
    raise exception 'Not authorized to read closing state for this location';
  end if;

  current_date_for_location := public.get_current_business_date(p_location_id);

  return query
  with day_identity as (
    select day.id
    from public.service_days day
    where day.location_id = p_location_id
      and day.business_date = p_business_date
    limit 1
  ),
  revenue as (
    select entry.*
    from public.revenue_entries entry
    where entry.location_id = p_location_id
      and entry.business_date = p_business_date
    limit 1
  ),
  closure as (
    select current_closure.*
    from public.service_day_closures current_closure
    where current_closure.location_id = p_location_id
      and current_closure.business_date = p_business_date
    limit 1
  ),
  reconciliation as (
    select * from public.cash_expense_reconciliation_snapshot(p_location_id, p_business_date)
  ),
  draft_expenses as (
    select count(*)::integer as count
    from public.cash_expense_entries entry
    where entry.location_id = p_location_id
      and entry.business_date = p_business_date
      and entry.status = 'draft'
  ),
  open_shifts as (
    select count(*)::integer as count
    from public.shifts shift
    where shift.location_id = p_location_id
      and shift.business_date = p_business_date
      and shift.ended_at is null
  ),
  invoices_review as (
    select count(*)::integer as count
    from public.invoice_records invoice
    where invoice.location_id = p_location_id
      and invoice.status = 'needs_review'
  ),
  note_summary as (
    select count(*)::integer as count
    from public.service_day_handoff_notes note
    where note.location_id = p_location_id
      and note.business_date = p_business_date
  ),
  latest_note as (
    select note.note, note.created_by, note.created_at
    from public.service_day_handoff_notes note
    where note.location_id = p_location_id
      and note.business_date = p_business_date
    order by note.created_at desc, note.id desc
    limit 1
  )
  select
    p_location_id,
    coalesce(revenue.service_day_id, closure.service_day_id, day_identity.id),
    p_business_date,
    current_date_for_location,
    revenue.id is not null,
    revenue.id,
    revenue.version,
    case when revenue.id is null then null else revenue.total_revenue_czk_minor::text end,
    case when revenue.id is null then null else revenue.card_czk_minor::text end,
    case when revenue.id is null then null else revenue.cash_czk_minor::text end,
    case when revenue.id is null then null else revenue.cash_register_expenses_czk_minor::text end,
    case when revenue.id is null then null else revenue.euros_minor::text end,
    case when revenue.id is null then null else revenue.physical_cash_handed_over_czk_minor::text end,
    closure.id is not null,
    closure.id,
    closure.version,
    closure.revenue_entry_id,
    closure.revenue_entry_version,
    case
      when closure.id is null then false
      when revenue.id is null then false
      else closure.revenue_entry_id = revenue.id
        and closure.revenue_entry_version = revenue.version
    end,
    case when closure.id is null then null else closure.usd_minor::text end,
    case when closure.id is null then null else closure.gbp_minor::text end,
    case when closure.id is null then null else closure.physical_eur_minor::text end,
    case when closure.id is null then null else closure.physical_usd_minor::text end,
    case when closure.id is null then null else closure.physical_gbp_minor::text end,
    closure.note,
    closure.closed_by,
    closure.closed_at,
    case when closure.id is null then null else closure.cash_expense_confirmed_minor_at_close::text end,
    case when closure.id is null then null else closure.cash_expense_difference_minor_at_close::text end,
    closure.cash_expense_acknowledgment_id_at_close,
    reconciliation.confirmed_minor::text,
    case when reconciliation.difference_minor is null then null else reconciliation.difference_minor::text end,
    reconciliation.current_acknowledgment_id,
    reconciliation.current_acknowledgment_reason,
    draft_expenses.count,
    open_shifts.count,
    invoices_review.count,
    note_summary.count,
    latest_note.note,
    latest_note.created_by,
    latest_note.created_at
  from draft_expenses
  cross join open_shifts
  cross join invoices_review
  cross join note_summary
  left join day_identity on true
  left join revenue on true
  left join closure on true
  left join reconciliation on true
  left join latest_note on true;
end;
$$;

alter table public.service_day_closures enable row level security;
alter table public.service_day_closure_revisions enable row level security;
alter table public.service_day_handoff_notes enable row level security;

create policy service_day_closures_read
on public.service_day_closures
for select
using (public.can_close_service_day(location_id));

create policy service_day_closure_revisions_read
on public.service_day_closure_revisions
for select
using (
  public.can_close_service_day((
    select closure.location_id
    from public.service_day_closures closure
    where closure.id = closure_id
  ))
);

create policy service_day_handoff_notes_read
on public.service_day_handoff_notes
for select
using (public.can_close_service_day(location_id));

revoke all on public.service_day_closures from public, anon, authenticated;
revoke all on public.service_day_closure_revisions from public, anon, authenticated;
revoke all on public.service_day_handoff_notes from public, anon, authenticated;
grant select on public.service_day_closures, public.service_day_closure_revisions, public.service_day_handoff_notes to authenticated;

revoke execute on function public.can_close_service_day(uuid) from public, anon, authenticated;
revoke execute on function public.cash_expense_reconciliation_snapshot(uuid, date) from public, anon, authenticated;
revoke execute on function public.close_service_day(uuid, uuid, date, uuid, integer, bigint, bigint, bigint, bigint, bigint, text) from public, anon, authenticated;
revoke execute on function public.correct_service_day_closure(uuid, integer, uuid, integer, bigint, bigint, bigint, bigint, bigint, text, text) from public, anon, authenticated;
revoke execute on function public.add_service_day_handoff_note(uuid, uuid, date, text) from public, anon, authenticated;
revoke execute on function public.get_service_day_close_state(uuid, date) from public, anon, authenticated;

grant execute on function public.can_close_service_day(uuid) to authenticated;
grant execute on function public.close_service_day(uuid, uuid, date, uuid, integer, bigint, bigint, bigint, bigint, bigint, text) to authenticated;
grant execute on function public.correct_service_day_closure(uuid, integer, uuid, integer, bigint, bigint, bigint, bigint, bigint, text, text) to authenticated;
grant execute on function public.add_service_day_handoff_note(uuid, uuid, date, text) to authenticated;
grant execute on function public.get_service_day_close_state(uuid, date) to authenticated;
