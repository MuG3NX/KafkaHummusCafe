begin;

select plan(91);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values
  ('51000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'm4b-owner@test.local', 'not-used', now()),
  ('51000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'm4b-manager@test.local', 'not-used', now()),
  ('51000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'm4b-employee@test.local', 'not-used', now()),
  ('51000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'm4b-unassigned-manager@test.local', 'not-used', now()),
  ('51000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'm4b-foreign-owner@test.local', 'not-used', now()),
  ('51000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'm4b-foreign-manager@test.local', 'not-used', now());

update public.profiles
set display_name = case id
  when '51000000-0000-0000-0000-000000000001' then 'M4B Owner'
  when '51000000-0000-0000-0000-000000000002' then 'M4B Manager'
  else 'M4B Team Member'
end
where id::text like '51000000-%';

insert into public.restaurants (id, name)
values
  ('52000000-0000-0000-0000-000000000001', 'M4B KAFKA'),
  ('52000000-0000-0000-0000-000000000002', 'M4B Foreign Restaurant');

insert into public.locations (id, restaurant_id, name, timezone)
values
  ('53000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', 'M4B Main', 'Europe/Prague'),
  ('53000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000001', 'M4B Second', 'Europe/Prague'),
  ('53000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000002', 'M4B Foreign', 'Europe/Prague');

insert into public.restaurant_memberships (id, restaurant_id, user_id, role)
values
  ('54000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'owner'),
  ('54000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000002', 'manager'),
  ('54000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000003', 'employee'),
  ('54000000-0000-0000-0000-000000000004', '52000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000004', 'manager'),
  ('54000000-0000-0000-0000-000000000005', '52000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000005', 'owner'),
  ('54000000-0000-0000-0000-000000000006', '52000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000006', 'manager');

insert into public.membership_location_assignments (membership_id, location_id, can_submit_revenue)
values
  ('54000000-0000-0000-0000-000000000002', '53000000-0000-0000-0000-000000000001', false),
  ('54000000-0000-0000-0000-000000000003', '53000000-0000-0000-0000-000000000001', false),
  ('54000000-0000-0000-0000-000000000006', '53000000-0000-0000-0000-000000000003', false);

insert into public.service_days (id, location_id, business_date)
values (
  '55000000-0000-0000-0000-000000000001',
  '53000000-0000-0000-0000-000000000001',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date
);

insert into public.revenue_entries (
  id, location_id, service_day_id, business_date, submitted_by,
  total_revenue_czk_minor, card_czk_minor, cash_czk_minor,
  cash_register_expenses_czk_minor, euros_minor,
  physical_cash_handed_over_czk_minor, note
) values (
  '56000000-0000-0000-0000-000000000001',
  '53000000-0000-0000-0000-000000000001',
  '55000000-0000-0000-0000-000000000001',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  '51000000-0000-0000-0000-000000000001',
  100000, 60000, 40000, 4321, 0, 35679, 'M4B non-interference fixture'
);

insert into public.invoice_records (
  id, restaurant_id, location_id, uploaded_by, storage_path,
  original_filename, original_mime_type, original_size_bytes, status, version
) values (
  '57000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000001',
  '53000000-0000-0000-0000-000000000001',
  '51000000-0000-0000-0000-000000000001',
  '53000000-0000-0000-0000-000000000001/57000000-0000-0000-0000-000000000001/original.pdf',
  'original.pdf', 'application/pdf', 1000, 'uploading', 1
);

create temp table m4b_revenue_snapshot as
select to_jsonb(entry)::text as row_state
from public.revenue_entries entry
where entry.id = '56000000-0000-0000-0000-000000000001';

create temp table m4b_invoice_snapshot as
select to_jsonb(invoice)::text as row_state
from public.invoice_records invoice
where invoice.id = '57000000-0000-0000-0000-000000000001';

grant select on m4b_revenue_snapshot, m4b_invoice_snapshot to authenticated;

set role authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select ok(public.can_manage_cash_expenses('53000000-0000-0000-0000-000000000001'), 'owner can manage a restaurant location');
select ok(public.can_manage_cash_expenses('53000000-0000-0000-0000-000000000002'), 'owner authority is restaurant-wide');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
select ok(public.can_manage_cash_expenses('53000000-0000-0000-0000-000000000001'), 'assigned manager can manage the assigned location');
select ok(not public.can_manage_cash_expenses('53000000-0000-0000-0000-000000000002'), 'manager cannot cross into an unassigned location');
select throws_ok(
  $$select * from public.get_approved_invoice_costs('53000000-0000-0000-0000-000000000001', current_date)$$,
  'P0001', null, 'M4B manager authority does not grant M4A approved-invoice reporting'
);

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);
select ok(not public.can_manage_cash_expenses('53000000-0000-0000-0000-000000000001'), 'employee cannot manage cash expenses');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000004', 'role', 'authenticated')::text, true);
select ok(not public.can_manage_cash_expenses('53000000-0000-0000-0000-000000000001'), 'unassigned manager cannot manage cash expenses');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000005', 'role', 'authenticated')::text, true);
select ok(not public.can_manage_cash_expenses('53000000-0000-0000-0000-000000000001'), 'foreign restaurant owner cannot cross tenant');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000006', 'role', 'authenticated')::text, true);
select ok(not public.can_manage_cash_expenses('53000000-0000-0000-0000-000000000001'), 'foreign restaurant manager cannot cross tenant');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select ok((select count(*) = 1 from public.capture_cash_expense(
  '58000000-0000-0000-0000-000000000001',
  '53000000-0000-0000-0000-000000000001',
  public.get_current_business_date('53000000-0000-0000-0000-000000000001'),
  9007199254740993,
  '  Emergency market purchase  '
)), 'owner can capture a current-service-day expense');
select is((select amount_czk_minor from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), 9007199254740993::bigint, 'cash amount remains exact beyond Number safe range');
select is((select description from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), 'Emergency market purchase', 'capture trims the mandatory description');
select is((select captured_by from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), '51000000-0000-0000-0000-000000000001'::uuid, 'captured_by comes from auth identity');
select ok((select captured_at <= now() and captured_at >= now() - interval '5 seconds' from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), 'captured_at comes from the database clock');
select ok((select status = 'draft' and version = 1 and confirmed_by is null and confirmed_at is null and confirmed_version is null from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), 'first capture is draft version 1 without confirmation');
select is((select count(*)::int from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'captured'), 1, 'capture appends one audit event');
select ok((select actor_id = '51000000-0000-0000-0000-000000000001'::uuid and expense_version = 1 and (payload ->> 'amount_czk_minor')::bigint = 9007199254740993 from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'captured'), 'capture audit records actor, version and resulting evidence identity');
select ok((select count(*) = 1 from public.cash_expense_entries entry join public.service_days day on (day.id, day.location_id, day.business_date) = (entry.service_day_id, entry.location_id, entry.business_date) where entry.id = '58000000-0000-0000-0000-000000000001'), 'service-day relational identity is coherent');
select is((select to_jsonb(entry)::text from public.revenue_entries entry where id = '56000000-0000-0000-0000-000000000001'), (select row_state from m4b_revenue_snapshot), 'capture leaves the complete M1 revenue row unchanged');

select ok((select count(*) = 1 from public.capture_cash_expense(
  '58000000-0000-0000-0000-000000000001',
  '53000000-0000-0000-0000-000000000001',
  public.get_current_business_date('53000000-0000-0000-0000-000000000001'),
  9007199254740993,
  'Emergency market purchase'
)), 'exact capture retry returns the existing row');
select is((select count(*)::int from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'captured'), 1, 'exact retry does not duplicate capture audit');
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000001', public.get_current_business_date('53000000-0000-0000-0000-000000000001'), 1, 'Conflicting payload')$$,
  'P0001', null, 'same UUID with conflicting capture payload is rejected'
);
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000010', '53000000-0000-0000-0000-000000000001', public.get_current_business_date('53000000-0000-0000-0000-000000000001'), 0, 'Zero')$$,
  'P0001', null, 'cash expense amount must be greater than zero'
);
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000011', '53000000-0000-0000-0000-000000000001', public.get_current_business_date('53000000-0000-0000-0000-000000000001'), 100, '   ')$$,
  'P0001', null, 'blank capture description is rejected'
);
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000012', '53000000-0000-0000-0000-000000000001', public.get_current_business_date('53000000-0000-0000-0000-000000000001') + 1, 100, 'Future')$$,
  'P0001', null, 'future service-day capture is rejected'
);

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
select ok((select count(*) = 1 from public.capture_cash_expense(
  '58000000-0000-0000-0000-000000000002',
  '53000000-0000-0000-0000-000000000001',
  public.get_current_business_date('53000000-0000-0000-0000-000000000001') - 1,
  12500,
  'Historical register movement'
)), 'assigned manager can capture a historical service-day expense');
select is((select business_date from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000002'), public.get_current_business_date('53000000-0000-0000-0000-000000000001') - 1, 'expense belongs to the explicitly selected historical service day');
select is((select captured_by from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000002'), '51000000-0000-0000-0000-000000000002'::uuid, 'manager capture records the manager actor');
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000013', '53000000-0000-0000-0000-000000000002', public.get_current_business_date('53000000-0000-0000-0000-000000000001'), 100, 'Wrong location')$$,
  'P0001', null, 'manager cannot capture across location assignment'
);

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000014', '53000000-0000-0000-0000-000000000001', current_date, 100, 'Employee attempt')$$,
  'P0001', null, 'employee cannot capture cash expenses'
);
select is((select count(*)::int from public.cash_expense_entries), 0, 'employee cannot read cash expenses');
select is((select count(*)::int from public.cash_expense_audit_events), 0, 'employee cannot read cash-expense audit');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000004', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000015', '53000000-0000-0000-0000-000000000001', current_date, 100, 'Unassigned manager')$$,
  'P0001', null, 'unassigned manager cannot capture cash expenses'
);

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000005', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000016', '53000000-0000-0000-0000-000000000001', current_date, 100, 'Foreign owner')$$,
  'P0001', null, 'foreign restaurant owner cannot capture across tenant'
);
select is((select count(*)::int from public.cash_expense_entries), 0, 'foreign restaurant owner cannot read tenant expenses');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000006', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000017', '53000000-0000-0000-0000-000000000001', current_date, 100, 'Foreign manager')$$,
  'P0001', null, 'foreign restaurant manager cannot capture across tenant'
);

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.cash_expense_entries where location_id = '53000000-0000-0000-0000-000000000001'), 2, 'owner reads all selected-location cash expenses');
select is((select count(*)::int from public.cash_expense_audit_events), 2, 'owner reads cash-expense audit events');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.cash_expense_entries where location_id = '53000000-0000-0000-0000-000000000001'), 2, 'assigned manager reads assigned-location expenses');
select is((select count(*)::int from public.cash_expense_entries where location_id = '53000000-0000-0000-0000-000000000002'), 0, 'manager cannot read an unassigned location');
select is((select count(*)::int from public.cash_expense_audit_events), 2, 'assigned manager reads audit for assigned expenses');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select * from public.confirm_cash_expense('58000000-0000-0000-0000-000000000001', null)$$,
  'P0001', null, 'null confirmation version is rejected as stale'
);
select ok((select count(*) = 1 from public.confirm_cash_expense('58000000-0000-0000-0000-000000000001', 1)), 'owner can confirm the exact current expense version');
select ok((select status = 'confirmed' and confirmed_version = 1 and confirmed_by = '51000000-0000-0000-0000-000000000001'::uuid from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), 'confirmation records exact version and auth actor');
select ok((select confirmed_at <= now() and confirmed_at >= now() - interval '5 seconds' from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), 'confirmed_at comes from the database clock');
select is((select count(*)::int from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'confirmed'), 1, 'confirmation appends one audit event');
select ok((select actor_id = '51000000-0000-0000-0000-000000000001'::uuid and expense_version = 1 and (payload ->> 'confirmed_version')::int = 1 from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'confirmed'), 'confirmation audit records actor and exact confirmed version');
select is((select to_jsonb(entry)::text from public.revenue_entries entry where id = '56000000-0000-0000-0000-000000000001'), (select row_state from m4b_revenue_snapshot), 'confirmation leaves the complete M1 revenue row unchanged');
select ok((select count(*) = 1 from public.confirm_cash_expense('58000000-0000-0000-0000-000000000001', 1)), 'exact confirmation retry returns existing confirmed evidence');
select is((select count(*)::int from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'confirmed'), 1, 'confirmation retry does not duplicate audit');
select throws_ok(
  $$select * from public.confirm_cash_expense('58000000-0000-0000-0000-000000000001', 2)$$,
  'P0001', null, 'stale confirmation version is rejected'
);

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
select ok((select count(*) = 1 from public.confirm_cash_expense('58000000-0000-0000-0000-000000000002', 1)), 'assigned manager can confirm an assigned-location expense');
select is((select confirmed_by from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000002'), '51000000-0000-0000-0000-000000000002'::uuid, 'manager confirmation records the manager actor');
select ok((select count(*) = 1 from public.correct_cash_expense(
  '58000000-0000-0000-0000-000000000002',
  1,
  public.get_current_business_date('53000000-0000-0000-0000-000000000001') - 1,
  12600,
  'Manager-corrected movement',
  'Correct manager fixture'
)), 'assigned manager can correct an assigned-location expense');
select ok((select status = 'draft' and version = 2 from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000002'), 'manager correction returns the new version to draft');
select is((select actor_id from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000002' and event_type = 'corrected'), '51000000-0000-0000-0000-000000000002'::uuid, 'manager correction audit records the manager actor');
select ok((select count(*) = 1 from public.confirm_cash_expense('58000000-0000-0000-0000-000000000002', 2)), 'assigned manager can re-confirm the corrected version');

select set_config('request.jwt.claims', json_build_object('sub', '51000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select * from public.correct_cash_expense('58000000-0000-0000-0000-000000000001', null, public.get_current_business_date('53000000-0000-0000-0000-000000000001'), 100, 'Valid description', 'Missing version')$$,
  'P0001', null, 'null correction version is rejected as stale'
);
select throws_ok(
  $$select * from public.correct_cash_expense('58000000-0000-0000-0000-000000000001', 1, public.get_current_business_date('53000000-0000-0000-0000-000000000001'), 100, 'Valid description', '   ')$$,
  'P0001', null, 'correction requires a non-empty reason'
);
select throws_ok(
  $$select * from public.correct_cash_expense('58000000-0000-0000-0000-000000000001', 1, public.get_current_business_date('53000000-0000-0000-0000-000000000001'), 0, 'Valid description', 'Fix amount')$$,
  'P0001', null, 'correction retains positive amount validation'
);
select throws_ok(
  $$select * from public.correct_cash_expense('58000000-0000-0000-0000-000000000001', 1, public.get_current_business_date('53000000-0000-0000-0000-000000000001'), 100, '   ', 'Fix description')$$,
  'P0001', null, 'correction retains description validation'
);
select throws_ok(
  $$select * from public.correct_cash_expense('58000000-0000-0000-0000-000000000001', 1, public.get_current_business_date('53000000-0000-0000-0000-000000000001') + 1, 100, 'Valid description', 'Move day')$$,
  'P0001', null, 'future service-day correction is rejected'
);
select ok((select count(*) = 1 from public.correct_cash_expense(
  '58000000-0000-0000-0000-000000000001',
  1,
  public.get_current_business_date('53000000-0000-0000-0000-000000000001') - 1,
  7777,
  '  Corrected market purchase  ',
  '  Correct amount and service day  '
)), 'owner can correct the exact current version');
select ok((select version = 2 and amount_czk_minor = 7777 and description = 'Corrected market purchase' from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), 'correction increments version and stores normalized evidence');
select ok((select status = 'draft' and confirmed_by is null and confirmed_at is null and confirmed_version is null from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), 'correction invalidates confirmation and returns to draft');
select ok((select count(*) = 1 from public.cash_expense_entries entry join public.service_days day on (day.id, day.location_id, day.business_date) = (entry.service_day_id, entry.location_id, entry.business_date) where entry.id = '58000000-0000-0000-0000-000000000001' and entry.business_date = public.get_current_business_date('53000000-0000-0000-0000-000000000001') - 1), 'corrected service-day identity remains coherent');
select is((select reason from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'corrected'), 'Correct amount and service day', 'correction audit records normalized mandatory reason');
select is((select (payload ->> 'amount_czk_minor')::bigint from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'corrected'), 9007199254740993::bigint, 'correction audit preserves previous exact amount');
select is((select (payload ->> 'business_date')::date from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'corrected'), public.get_current_business_date('53000000-0000-0000-0000-000000000001'), 'correction audit preserves previous service day');
select is((select payload ->> 'description' from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'corrected'), 'Emergency market purchase', 'correction audit preserves previous description');
select is((select payload ->> 'status' from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'corrected'), 'confirmed', 'correction audit preserves previous confirmation state');
select ok((select (payload ->> 'confirmed_by')::uuid = '51000000-0000-0000-0000-000000000001'::uuid and (payload ->> 'confirmed_version')::int = 1 from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'corrected'), 'correction audit preserves previous confirmation actor and version');
select is((select (payload ->> 'version')::int from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'corrected'), 1, 'correction audit preserves previous version');
select throws_ok(
  $$select * from public.correct_cash_expense('58000000-0000-0000-0000-000000000001', 1, current_date, 100, 'Stale', 'Stale correction')$$,
  'P0001', null, 'stale correction version is rejected'
);
select is((select to_jsonb(entry)::text from public.revenue_entries entry where id = '56000000-0000-0000-0000-000000000001'), (select row_state from m4b_revenue_snapshot), 'correction leaves the complete M1 revenue row unchanged');
select ok((select count(*) = 1 from public.confirm_cash_expense('58000000-0000-0000-0000-000000000001', 2)), 'corrected expense can be re-confirmed at the exact new version');
select ok((select status = 'confirmed' and confirmed_version = 2 from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'), 're-confirmation records the corrected version');
select is((select count(*)::int from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001' and event_type = 'confirmed' and expense_version = 2), 1, 're-confirmation appends a version-2 confirmation event');
select is((select to_jsonb(entry)::text from public.revenue_entries entry where id = '56000000-0000-0000-0000-000000000001'), (select row_state from m4b_revenue_snapshot), 're-confirmation leaves the complete M1 revenue row unchanged');

select throws_ok(
  $$insert into public.cash_expense_entries (id, location_id, service_day_id, business_date, amount_czk_minor, description, captured_by) values ('58000000-0000-0000-0000-000000000020', '53000000-0000-0000-0000-000000000001', '55000000-0000-0000-0000-000000000001', current_date, 100, 'Direct insert', '51000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'direct cash-expense INSERT is denied'
);
select throws_ok(
  $$update public.cash_expense_entries set amount_czk_minor = 1 where id = '58000000-0000-0000-0000-000000000001'$$,
  '42501', null, 'direct cash-expense UPDATE is denied'
);
select throws_ok(
  $$delete from public.cash_expense_entries where id = '58000000-0000-0000-0000-000000000001'$$,
  '42501', null, 'direct cash-expense DELETE is denied'
);
select throws_ok(
  $$insert into public.cash_expense_audit_events (cash_expense_id, event_type, expense_version, actor_id, payload) values ('58000000-0000-0000-0000-000000000001', 'confirmed', 2, '51000000-0000-0000-0000-000000000001', '{}')$$,
  '42501', null, 'direct audit INSERT is denied'
);
select throws_ok(
  $$update public.cash_expense_audit_events set payload = '{}' where cash_expense_id = '58000000-0000-0000-0000-000000000001'$$,
  '42501', null, 'direct audit UPDATE is denied'
);
select throws_ok(
  $$delete from public.cash_expense_audit_events where cash_expense_id = '58000000-0000-0000-0000-000000000001'$$,
  '42501', null, 'direct audit DELETE is denied'
);

reset role;
set role anon;
select set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
select throws_ok(
  $$select count(*) from public.cash_expense_entries$$,
  '42501', null, 'anonymous user cannot read cash expenses'
);
select throws_ok(
  $$select * from public.capture_cash_expense('58000000-0000-0000-0000-000000000021', '53000000-0000-0000-0000-000000000001', current_date, 100, 'Anonymous')$$,
  '42501', null, 'anonymous user cannot invoke cash-expense mutation RPCs'
);

reset role;
select is((select to_jsonb(invoice)::text from public.invoice_records invoice where id = '57000000-0000-0000-0000-000000000001'), (select row_state from m4b_invoice_snapshot), 'M4B1 leaves the complete M3 invoice row unchanged');
select is((select approved_draft_version from public.invoice_records where id = '57000000-0000-0000-0000-000000000001'), null, 'M4B1 does not touch approved invoice pointers');
select is((select count(*)::int from storage.objects where name like '53000000-0000-0000-0000-000000000001/%'), 0, 'M4B1 creates no Storage object');
select is((select count(*)::int from information_schema.columns where table_schema = 'public' and table_name in ('cash_expense_entries', 'cash_expense_audit_events') and column_name ~ '(paid|payment|invoice|receipt|vat)'), 0, 'M4B1 creates no payment, invoice, receipt, or VAT state');

select * from finish();
rollback;
