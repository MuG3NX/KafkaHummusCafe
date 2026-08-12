create or replace function public.get_business_date_for_instant(
  target_location_id uuid,
  p_instant timestamptz
)
returns date
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  location_timezone text;
  local_instant timestamp;
begin
  if not public.can_access_location(target_location_id) then
    raise exception 'Not authorized for this location';
  end if;

  select timezone into location_timezone
  from public.locations
  where id = target_location_id;

  if location_timezone is null then
    raise exception 'Location not found';
  end if;

  local_instant := p_instant at time zone location_timezone;
  if local_instant::time < time '05:00:00' then
    return local_instant::date - 1;
  end if;
  return local_instant::date;
end;
$$;

create or replace function public.get_current_business_date(target_location_id uuid)
returns date
language sql
stable
security definer
set search_path = public
as $$
  select public.get_business_date_for_instant($1, now());
$$;

revoke execute on function public.get_business_date_for_instant(uuid, timestamptz) from public;
grant execute on function public.get_business_date_for_instant(uuid, timestamptz) to authenticated;
