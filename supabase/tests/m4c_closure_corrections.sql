begin;

select plan(23);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values
  ('8c000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'm4c-correction-owner@test.local', 'not-used', now()),
  ('8c000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'm4c-correction-closer@test.local', 'not-used', now());

insert into public.restaurants (id, name)
values ('8c000000-0000-0000-0000-000000000010', 'M4C Correction Restaurant');

insert into public.locations (id, restaurant_id, name, timezone)
values ('8c000000-0000-0000-0000-000000000020', '8c000000-0000-0000-0000-000000000010', 'M4C Correction Location', 'Europe/Prague');

insert into public.restaurant_memberships (id, restaurant_id, user_id, role)
values
  ('8c000000-0000-0000-0000-000000000030', '8c000000-0000-0000-0000-000000000010', '8c000000-0000-0000-0000-000000000001', 'owner'),
  ('8c000000-0000-0000-0000-000000000031', '8c000000-0000-0000-0000-000000000010', '8c000000-0000-0000-0000-000000000002', 'employee');

insert into public.membership_location_assignments (id, membership_id, location_id, can_submit_revenue, can_close_day)
values ('8c000000-0000-0000-0000-000000000040', '8c000000-0000-0000-0000-000000000031', '8c000000-0000-0000-0000-000000000020', false, true);

insert into public.service_days (id, location_id, business_date)
values ('8c000000-0000-0000-0000-000000000050', '8c000000-0000-0000-0000-000000000020', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date);

insert into public.revenue_entries (
  id, location_id, service_day_id, business_date, submitted_by,
  total_revenue_czk_minor, card_czk_minor, cash_czk_minor,
  cash_register_expenses_czk_minor, euros_minor,
  physical_cash_handed_over_czk_minor, note
) values (
  '8c000000-0000-0000-0000-000000000060',
  '8c000000-0000-0000-0000-000000000020',
  '8c000000-0000-0000-0000-000000000050',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  '8c000000-0000-0000-0000-000000000001',
  1000000, 700000, 300000, 0, 5000, 300000, 'Initial Revenue'
);

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','8c000000-0000-0000-0000-000000000002','role','authenticated')::text, true);

select ok((select count(*) = 1 from public.close_service_day(
  '8c000000-0000-0000-0000-000000000070',
  '8c000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  '8c000000-0000-0000-0000-000000000060',
  1,
  1234, 2345, 5000, 1234, 2345,
  'Initial close'
)), 'closer creates initial completed close');

select throws_ok(
  $$select * from public.correct_service_day_closure(
    '8c000000-0000-0000-0000-000000000070',1,
    '8c000000-0000-0000-0000-000000000060',1,
    1234,2345,5000,1234,2345,'Initial close','Closer correction'
  )$$,
  'P0001',
  'Only the owner can correct a completed close',
  'operational closer cannot correct completed close'
);

select set_config('request.jwt.claims', json_build_object('sub','8c000000-0000-0000-0000-000000000001','role','authenticated')::text, true);

select throws_ok(
  $$select * from public.correct_service_day_closure(
    '8c000000-0000-0000-0000-000000000070',1,
    '8c000000-0000-0000-0000-000000000060',1,
    1234,2345,5000,1234,2345,'Initial close','   '
  )$$,
  'P0001',
  'A correction reason is required',
  'owner correction requires non-empty reason'
);

select ok((select count(*) = 1 from public.correct_revenue_entry(
  '8c000000-0000-0000-0000-000000000060',
  1000000,700000,300000,1000,5000,299000,
  'Corrected Revenue','Closing discovered register expense'
)), 'existing M1 owner correction increments Revenue version');

select is((select version from public.revenue_entries where id='8c000000-0000-0000-0000-000000000060'), 2, 'Revenue is now version 2');
select ok(not (select revenue_binding_current from public.get_service_day_close_state('8c000000-0000-0000-0000-000000000020', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 'Revenue correction makes completed close binding stale');
select is((select closure_revenue_entry_version from public.get_service_day_close_state('8c000000-0000-0000-0000-000000000020', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 1, 'historic close keeps original Revenue version until owner review');
select is((select revenue_entry_version from public.get_service_day_close_state('8c000000-0000-0000-0000-000000000020', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 2, 'read model exposes current Revenue version separately');

select throws_ok(
  $$select * from public.correct_service_day_closure(
    '8c000000-0000-0000-0000-000000000070',99,
    '8c000000-0000-0000-0000-000000000060',2,
    1234,2345,5000,1234,2345,'Rebound','Wrong close version'
  )$$,
  'P0001',
  'Closure version is stale',
  'stale close version is rejected'
);

select throws_ok(
  $$select * from public.correct_service_day_closure(
    '8c000000-0000-0000-0000-000000000070',1,
    '8c000000-0000-0000-0000-000000000060',1,
    1234,2345,5000,1234,2345,'Rebound','Wrong Revenue version'
  )$$,
  'P0001',
  'Revenue changed; reload before correcting the close',
  'stale Revenue version is rejected during owner correction'
);

create temp table m4c_original_close as
select closed_by, closed_at
from public.service_day_closures
where id='8c000000-0000-0000-0000-000000000070';
grant select on m4c_original_close to authenticated;

select ok((select count(*) = 1 from public.correct_service_day_closure(
  '8c000000-0000-0000-0000-000000000070',1,
  '8c000000-0000-0000-0000-000000000060',2,
  2000,3000,6000,2000,3000,
  '  Owner reviewed final handover  ',
  '  Rebind after audited Revenue correction  '
)), 'owner can audit-correct and rebind close to current Revenue');

select is((select version from public.service_day_closures where id='8c000000-0000-0000-0000-000000000070'), 2, 'close version increments');
select is((select revenue_entry_version from public.service_day_closures where id='8c000000-0000-0000-0000-000000000070'), 2, 'corrected close binds current Revenue version');
select ok((select revenue_binding_current from public.get_service_day_close_state('8c000000-0000-0000-0000-000000000020', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 'owner correction restores current Revenue binding');
select is((select note from public.service_day_closures where id='8c000000-0000-0000-0000-000000000070'), 'Owner reviewed final handover', 'owner correction normalizes closing note');
select is((select usd_minor from public.service_day_closures where id='8c000000-0000-0000-0000-000000000070'), 2000::bigint, 'owner correction updates exact USD evidence');
select is((select count(*)::integer from public.service_day_closure_revisions where closure_id='8c000000-0000-0000-0000-000000000070'), 1, 'owner correction appends one revision');
select is((select version from public.service_day_closure_revisions where closure_id='8c000000-0000-0000-0000-000000000070'), 1, 'revision identifies previous close version');
select is((select reason from public.service_day_closure_revisions where closure_id='8c000000-0000-0000-0000-000000000070'), 'Rebind after audited Revenue correction', 'revision reason is normalized');
select is((select previous_values->>'revenue_entry_version' from public.service_day_closure_revisions where closure_id='8c000000-0000-0000-0000-000000000070'), '1', 'revision preserves previous Revenue binding');
select is((select previous_values->>'usd_minor' from public.service_day_closure_revisions where closure_id='8c000000-0000-0000-0000-000000000070'), '1234', 'revision preserves previous closing evidence');
select is((select closed_by from public.service_day_closures where id='8c000000-0000-0000-0000-000000000070'), (select closed_by from m4c_original_close), 'owner correction preserves original closer');
select is((select closed_at from public.service_day_closures where id='8c000000-0000-0000-0000-000000000070'), (select closed_at from m4c_original_close), 'owner correction preserves original close timestamp');

reset role;
select * from finish();
rollback;