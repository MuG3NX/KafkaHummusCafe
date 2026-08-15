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
  exact_existing_retry boolean := false;
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
  if p_expected_revenue_entry_id is null
     or p_expected_revenue_entry_version is null
     or p_expected_revenue_entry_version <= 0
     or p_expected_closing_expenses_czk_minor is null
     or p_expected_closing_expenses_czk_minor < 0
     or p_expected_confirmed_cash_expenses_czk_minor is null
     or p_expected_confirmed_cash_expenses_czk_minor < 0
     or p_expected_confirmed_source_fingerprint is null
     or p_expected_confirmed_source_fingerprint !~ '^[0-9a-f]{64}$'
     or p_expected_difference_czk_minor is null then
    raise exception 'A complete expected reconciliation snapshot is required';
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
    exact_existing_retry :=
      existing_ack.location_id = p_location_id
      and existing_ack.business_date = p_business_date
      and existing_ack.revenue_entry_id = p_expected_revenue_entry_id
      and existing_ack.revenue_entry_version = p_expected_revenue_entry_version
      and existing_ack.revenue_cash_register_expenses_czk_minor = p_expected_closing_expenses_czk_minor
      and existing_ack.confirmed_cash_expenses_czk_minor = p_expected_confirmed_cash_expenses_czk_minor
      and existing_ack.confirmed_source_fingerprint = p_expected_confirmed_source_fingerprint
      and existing_ack.difference_czk_minor = p_expected_difference_czk_minor
      and existing_ack.reason = normalized_reason
      and existing_ack.acknowledged_by = auth.uid();
    if not exact_existing_retry then
      raise exception 'Acknowledgment id is already used with a different payload';
    end if;
  elsif not public.can_manage_cash_expenses(p_location_id) then
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

  if exact_existing_retry then
    return next existing_ack;
    return;
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

revoke execute on function public.acknowledge_cash_expense_difference(uuid, uuid, date, uuid, integer, bigint, bigint, text, bigint, text) from public, anon, authenticated;
grant execute on function public.acknowledge_cash_expense_difference(uuid, uuid, date, uuid, integer, bigint, bigint, text, bigint, text) to authenticated;
