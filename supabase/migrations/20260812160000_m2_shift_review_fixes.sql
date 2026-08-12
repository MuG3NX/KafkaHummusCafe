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
  corrected_business_date date;
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

  corrected_business_date := public.get_business_date_for_instant(shift.location_id, p_started_at);
  if corrected_business_date <> shift.business_date then
    raise exception 'Corrected start time must remain on the original service day';
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
