create table public.cash_expense_reconciliation_acknowledgments (
  id uuid primary key,
  location_id uuid not null references public.locations(id),
  service_day_id uuid not null references public.service_days(id),
  business_date date not null,
  revenue_entry_id uuid not null references public.revenue_entries(id),
  revenue_entry_version integer not null check (revenue_entry_version > 0),
  revenue_cash_register_expenses_czk_minor bigint not null check (revenue_cash_register_expenses_czk_minor >= 0),
  confirmed_cash_expenses_czk_minor bigint not null check (confirmed_cash_expenses_czk_minor >= 0),
  confirmed_source_fingerprint text not null check (confirmed_source_fingerprint ~ '^[0-9a-f]{64}$'),
  difference_czk_minor bigint not null,
  reason text not null check (reason = trim(reason) and length(reason) > 0),
  acknowledged_by uuid not null references auth.users(id),
  acknowledged_at timestamptz not null default now(),
  constraint cash_expense_reconciliation_ack_service_day_identity_fk
    foreign key (service_day_id, location_id, business_date)
    references public.service_days (id, location_id, business_date)
);

create index cash_expense_reconciliation_ack_location_date_idx
  on public.cash_expense_reconciliation_acknowledgments (
    location_id,
    business_date desc,
    acknowledged_at desc,
    id
  );

create or replace function public.get_cash_expense_reconciliation(
  p_location_id uuid,
  p_business_date date
)
returns table (
  location_id uuid,
  service_day_id uuid,
  business_date date,
  has_revenue boolean,
  revenue_entry_id uuid,
  revenue_entry_version integer,
  closing_expenses_czk_minor text,
  confirmed_cash_expenses_czk_minor text,
  confirmed_source_fingerprint text,
  difference_czk_minor text,
  confirmed_count integer,
  draft_count integer,
  acknowledgment_id uuid,
  acknowledgment_reason text,
  acknowledged_by uuid,
  acknowledged_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_location_id is null or p_business_date is null then
    raise exception 'Location and service day are required';
  end if;
  if not public.can_manage_cash_expenses(p_location_id) then
    raise exception 'Not authorized to reconcile cash expenses for this location';
  end if;

  return query
  with revenue as (
    select
      entry.id,
      entry.service_day_id,
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
      count(*) filter (where entry.status = 'confirmed')::integer as confirmed_count,
      count(*) filter (where entry.status = 'draft')::integer as draft_count,
      encode(
        digest(
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
  day_identity as (
    select day.id
    from public.service_days day
    where day.location_id = p_location_id
      and day.business_date = p_business_date
    limit 1
  ),
  current_values as (
    select
      revenue.id as revenue_entry_id,
      coalesce(revenue.service_day_id, day_identity.id) as service_day_id,
      revenue.version as revenue_entry_version,
      revenue.cash_register_expenses_czk_minor as closing_minor,
      expense_summary.confirmed_minor,
      expense_summary.confirmed_count,
      expense_summary.draft_count,
      expense_summary.confirmed_fingerprint,
      case
        when revenue.id is null then null::bigint
        else revenue.cash_register_expenses_czk_minor - expense_summary.confirmed_minor
      end as difference_minor
    from expense_summary
    left join revenue on true
    left join day_identity on true
  )
  select
    p_location_id,
    current_values.service_day_id,
    p_business_date,
    current_values.revenue_entry_id is not null,
    current_values.revenue_entry_id,
    current_values.revenue_entry_version,
    case when current_values.closing_minor is null then null else current_values.closing_minor::text end,
    current_values.confirmed_minor::text,
    current_values.confirmed_fingerprint,
    case when current_values.difference_minor is null then null else current_values.difference_minor::text end,
    current_values.confirmed_count,
    current_values.draft_count,
    current_ack.id,
    current_ack.reason,
    current_ack.acknowledged_by,
    current_ack.acknowledged_at
  from current_values
  left join lateral (
    select acknowledgment.*
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
end;
$$;

create or replace function public.acknowledge_cash_expense_difference(
  p_acknowledgment_id uuid,
  p_location_id uuid,
  p_business_date date,
  p_expected_revenue_entry_id uuid,
  p_expected_revenue_entry_version integer,
  p_expected_closing_expenses_czk_minor bigint,
  p_expected_confirmed_cash_expenses_czk_minor bigint,
  p_expected_confirmed_source_fingerprint text,
  p_expected_difference_czk_minor bigint,
  p_reason text
)
returns setof public.cash_expense_reconciliation_acknowledgments
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_reason text;
  existing_ack public.cash_expense_reconciliation_acknowledgments;
  revenue_entry public.revenue_entries;
  confirmed_minor bigint;
  confirmed_fingerprint text;
  current_difference bigint;
  created_ack public.cash_expense_reconciliation_acknowledgments;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_acknowledgment_id is null or p_location_id is null or p_business_date is null then
    raise exception 'Acknowledgment id, location and service day are required';
  end if;

  normalized_reason := trim(coalesce(p_reason, ''));
  if length(normalized_reason) = 0 then
    raise exception 'An acknowledgment reason is required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_acknowledgment_id::text, 0));

  select * into existing_ack
  from public.cash_expense_reconciliation_acknowledgments acknowledgment
  where acknowledgment.id = p_acknowledgment_id
  for update;

  if existing_ack.id is not null then
    if not public.can_manage_cash_expenses(existing_ack.location_id) then
      raise exception 'Not authorized to read this acknowledgment';
    end if;
    if existing_ack.location_id = p_location_id
       and existing_ack.business_date = p_business_date
       and existing_ack.revenue_entry_id = p_expected_revenue_entry_id
       and existing_ack.revenue_entry_version = p_expected_revenue_entry_version
       and existing_ack.revenue_cash_register_expenses_czk_minor = p_expected_closing_expenses_czk_minor
       and existing_ack.confirmed_cash_expenses_czk_minor = p_expected_confirmed_cash_expenses_czk_minor
       and existing_ack.confirmed_source_fingerprint = p_expected_confirmed_source_fingerprint
       and existing_ack.difference_czk_minor = p_expected_difference_czk_minor
       and existing_ack.reason = normalized_reason
       and existing_ack.acknowledged_by = auth.uid() then
      return next existing_ack;
      return;
    end if;
    raise exception 'Acknowledgment id is already used with a different payload';
  end if;

  if not public.can_manage_cash_expenses(p_location_id) then
    raise exception 'Not authorized to acknowledge cash expense differences for this location';
  end if;

  select * into revenue_entry
  from public.revenue_entries entry
  where entry.location_id = p_location_id
    and entry.business_date = p_business_date
  for share;

  if revenue_entry.id is null then
    raise exception 'Revenue must be submitted before a difference can be acknowledged';
  end if;

  select
    coalesce(sum(entry.amount_czk_minor) filter (where entry.status = 'confirmed'), 0)::bigint,
    encode(
      digest(
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
    )
  into confirmed_minor, confirmed_fingerprint
  from public.cash_expense_entries entry
  where entry.location_id = p_location_id
    and entry.business_date = p_business_date;

  current_difference := revenue_entry.cash_register_expenses_czk_minor - confirmed_minor;

  if revenue_entry.id <> p_expected_revenue_entry_id
     or revenue_entry.version <> p_expected_revenue_entry_version
     or revenue_entry.cash_register_expenses_czk_minor <> p_expected_closing_expenses_czk_minor
     or confirmed_minor <> p_expected_confirmed_cash_expenses_czk_minor
     or confirmed_fingerprint <> p_expected_confirmed_source_fingerprint
     or current_difference <> p_expected_difference_czk_minor then
    raise exception 'Cash expense reconciliation is stale; reload before acknowledging';
  end if;

  if current_difference = 0 then
    raise exception 'Matched cash expenses do not require acknowledgment';
  end if;

  insert into public.cash_expense_reconciliation_acknowledgments (
    id,
    location_id,
    service_day_id,
    business_date,
    revenue_entry_id,
    revenue_entry_version,
    revenue_cash_register_expenses_czk_minor,
    confirmed_cash_expenses_czk_minor,
    confirmed_source_fingerprint,
    difference_czk_minor,
    reason,
    acknowledged_by,
    acknowledged_at
  ) values (
    p_acknowledgment_id,
    p_location_id,
    revenue_entry.service_day_id,
    p_business_date,
    revenue_entry.id,
    revenue_entry.version,
    revenue_entry.cash_register_expenses_czk_minor,
    confirmed_minor,
    confirmed_fingerprint,
    current_difference,
    normalized_reason,
    auth.uid(),
    now()
  )
  returning * into created_ack;

  return next created_ack;
end;
$$;

alter table public.cash_expense_reconciliation_acknowledgments enable row level security;

create policy cash_expense_reconciliation_acknowledgments_read
on public.cash_expense_reconciliation_acknowledgments
for select
using (public.can_manage_cash_expenses(location_id));

revoke all on public.cash_expense_reconciliation_acknowledgments from public, anon, authenticated;
grant select on public.cash_expense_reconciliation_acknowledgments to authenticated;

revoke execute on function public.get_cash_expense_reconciliation(uuid, date) from public, anon, authenticated;
revoke execute on function public.acknowledge_cash_expense_difference(uuid, uuid, date, uuid, integer, bigint, bigint, text, bigint, text) from public, anon, authenticated;

grant execute on function public.get_cash_expense_reconciliation(uuid, date) to authenticated;
grant execute on function public.acknowledge_cash_expense_difference(uuid, uuid, date, uuid, integer, bigint, bigint, text, bigint, text) to authenticated;
