begin;

select plan(21);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'employee@test.local', 'not-used', now()),
  ('44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'submitter-a@test.local', 'not-used', now()),
  ('55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated', 'submitter-b@test.local', 'not-used', now()),
  ('66666666-6666-6666-6666-666666666666', 'authenticated', 'authenticated', 'owner@test.local', 'not-used', now());

insert into public.restaurants (id, name)
values ('11111111-1111-1111-1111-111111111111', 'Test KAFKA');

insert into public.locations (id, restaurant_id, name, timezone)
values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Main test location', 'Europe/Prague'),
  ('88888888-8888-8888-8888-888888888888', '11111111-1111-1111-1111-111111111111', 'Second test location', 'Europe/Prague');

insert into public.restaurant_memberships (id, restaurant_id, user_id, role)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'employee'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 'employee'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555', 'employee'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', '66666666-6666-6666-6666-666666666666', 'owner');

insert into public.membership_location_assignments (membership_id, location_id, can_submit_revenue)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', false),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '88888888-8888-8888-8888-888888888888', true),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', true),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '88888888-8888-8888-8888-888888888888', true);

insert into public.service_days (id, location_id, business_date)
values ('77777777-7777-7777-7777-777777777777', '22222222-2222-2222-2222-222222222222', current_date - 1);
insert into public.service_days (id, location_id, business_date)
values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '88888888-8888-8888-8888-888888888888', current_date);

insert into public.revenue_entries (
  id, location_id, service_day_id, business_date, submitted_by,
  total_revenue_czk_minor, card_czk_minor, cash_czk_minor,
  cash_register_expenses_czk_minor, euros_minor,
  physical_cash_handed_over_czk_minor
)
values (
  '99999999-9999-9999-9999-999999999999', '22222222-2222-2222-2222-222222222222',
  '77777777-7777-7777-7777-777777777777', current_date - 1, '44444444-4444-4444-4444-444444444444',
  10000, 5000, 5000, 0, 0, 5000
);

select throws_ok(
  $$insert into public.revenue_entries (location_id, service_day_id, business_date, submitted_by, total_revenue_czk_minor, card_czk_minor, cash_czk_minor, cash_register_expenses_czk_minor, euros_minor, physical_cash_handed_over_czk_minor)
    values ('22222222-2222-2222-2222-222222222222', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', current_date, '44444444-4444-4444-4444-444444444444', 1, 1, 0, 0, 0, 0)$$,
  '23503', null, 'service-day composite identity prevents mismatched revenue rows'
);

set role authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '33333333-3333-3333-3333-333333333333', 'role', 'authenticated')::text, true);
select is(public.get_business_date_for_instant('22222222-2222-2222-2222-222222222222', '2026-08-12 23:30:00+00'::timestamptz), '2026-08-12'::date, 'before 05:00 Europe/Prague belongs to the previous service day');
select is(public.get_business_date_for_instant('22222222-2222-2222-2222-222222222222', '2026-08-13 03:00:00+00'::timestamptz), '2026-08-13'::date, 'exactly 05:00 Europe/Prague starts the current service day');
select is(public.get_business_date_for_instant('22222222-2222-2222-2222-222222222222', '2026-08-13 03:00:01+00'::timestamptz), '2026-08-13'::date, 'after 05:00 Europe/Prague remains on the current service day');
select is(public.get_business_date_for_instant('22222222-2222-2222-2222-222222222222', '2026-08-13 09:00:00+00'::timestamptz), '2026-08-13'::date, 'database cutoff converts UTC using the location timezone');
select is((select count(*)::int from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222'), 0, 'unauthorized employee cannot read revenue');
select is((select count(*)::int from public.locations where restaurant_id = '11111111-1111-1111-1111-111111111111'), 1, 'assigned employee can list the assigned location');
select throws_ok(
  $$select * from public.submit_revenue_entry('22222222-2222-2222-2222-222222222222', public.get_current_business_date('22222222-2222-2222-2222-222222222222'), 10000, 5000, 5000, 0, 0, 5000, null)$$,
  'P0001', null, 'unauthorized employee cannot submit revenue'
);

select set_config('request.jwt.claims', json_build_object('sub', '44444444-4444-4444-4444-444444444444', 'role', 'authenticated')::text, true);
select ok((select count(*) = 1 from public.submit_revenue_entry('22222222-2222-2222-2222-222222222222', public.get_current_business_date('22222222-2222-2222-2222-222222222222'), 125000, 80000, 45000, 1200, 350, 43800, ' closing note ')), 'authorized submitter can submit current revenue');
select is((select note from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222' and business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222')), 'closing note', 'stored note is normalized');
select ok((select count(*) = 1 from public.submit_revenue_entry('22222222-2222-2222-2222-222222222222', public.get_current_business_date('22222222-2222-2222-2222-222222222222'), 125000, 80000, 45000, 1200, 350, 43800, 'closing note')), 'normalized identical retry is idempotent');
select throws_ok(
  $$select * from public.submit_revenue_entry('22222222-2222-2222-2222-222222222222', public.get_current_business_date('22222222-2222-2222-2222-222222222222'), 125001, 80000, 45000, 1200, 350, 43800, 'closing note')$$,
  'P0001', null, 'different duplicate submission is rejected'
);
select throws_ok(
  $$update public.revenue_entries set note = 'tampered' where business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222')$$,
  '42501', null, 'normal submitter cannot update revenue directly'
);
select throws_ok(
  $$delete from public.revenue_entries where business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222')$$,
  '42501', null, 'normal submitter cannot delete revenue directly'
);

select set_config('request.jwt.claims', json_build_object('sub', '55555555-5555-5555-5555-555555555555', 'role', 'authenticated')::text, true);
select ok(public.can_access_location('22222222-2222-2222-2222-222222222222') and public.can_access_location('88888888-8888-8888-8888-888888888888'), 'one membership can be assigned to multiple locations');
select is((select count(*)::int from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222' and business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222')), 1, 'authorized second submitter sees shared current-day status');
select is((select count(*)::int from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222' and business_date = current_date - 1), 0, 'authorized submitter cannot read arbitrary financial history');

select set_config('request.jwt.claims', json_build_object('sub', '66666666-6666-6666-6666-666666666666', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222'), 2, 'owner can read location history');
select ok((select count(*) = 1 from public.correct_revenue_entry((select id from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222' and business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222')), 126000, 80000, 46000, 1200, 350, 44800, 'corrected closing note', 'cash count corrected')), 'owner correction succeeds');
select is((select count(*)::int from public.revenue_revisions where revenue_entry_id = (select id from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222' and business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222'))), 1, 'owner correction creates one revision');
select is((select previous_values->>'total_revenue_czk_minor' from public.revenue_revisions limit 1), '125000', 'revision preserves previous values');

select * from finish();
rollback;
