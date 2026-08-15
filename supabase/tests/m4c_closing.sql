begin;

select plan(43);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values
  ('81000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'm4c-owner@test.local', 'not-used', now()),
  ('81000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'm4c-closer@test.local', 'not-used', now()),
  ('81000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'm4c-worker@test.local', 'not-used', now()),
  ('81000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'm4c-foreign-owner@test.local', 'not-used', now());

insert into public.restaurants (id, name)
values
  ('82000000-0000-0000-0000-000000000001', 'M4C KAFKA'),
  ('82000000-0000-0000-0000-000000000002', 'M4C Foreign');

insert into public.locations (id, restaurant_id, name, timezone)
values
  ('83000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001', 'M4C Main', 'Europe/Prague'),
  ('83000000-0000-0000-0000-000000000002', '82000000-0000-0000-0000-000000000002', 'M4C Foreign', 'Europe/Prague');

insert into public.restaurant_memberships (id, restaurant_id, user_id, role)
values
  ('84000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'owner'),
  ('84000000-0000-0000-0000-000000000002', '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', 'employee'),
  ('84000000-0000-0000-0000-000000000003', '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000003', 'employee'),
  ('84000000-0000-0000-0000-000000000004', '82000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000004', 'owner');

insert into public.membership_location_assignments (id, membership_id, location_id, can_submit_revenue, can_close_day)
values
  ('85000000-0000-0000-0000-000000000001', '84000000-0000-0000-0000-000000000002', '83000000-0000-0000-0000-000000000001', false, true),
  ('85000000-0000-0000-0000-000000000002', '84000000-0000-0000-0000-000000000003', '83000000-0000-0000-0000-000000000001', false, false);

insert into public.service_days (id, location_id, business_date)
values
  ('86000000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date),
  ('86000000-0000-0000-0000-000000000002', '83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1),
  ('86000000-0000-0000-0000-000000000003', '83000000-0000-0000-0000-000000000002', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date);

insert into public.revenue_entries (
  id, location_id, service_day_id, business_date, submitted_by,
  total_revenue_czk_minor, card_czk_minor, cash_czk_minor,
  cash_register_expenses_czk_minor, euros_minor,
  physical_cash_handed_over_czk_minor, note
) values
  ('87000000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001', '86000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, '81000000-0000-0000-0000-000000000001', 10000000, 7000000, 3000000, 400000, 12500, 250000, 'Current Revenue'),
  ('87000000-0000-0000-0000-000000000002', '83000000-0000-0000-0000-000000000001', '86000000-0000-0000-0000-000000000002', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1, '81000000-0000-0000-0000-000000000001', 9000000, 6000000, 3000000, 100000, 5000, 290000, 'Historical Revenue');

insert into public.cash_expense_entries (
  id, location_id, service_day_id, business_date, amount_czk_minor, description,
  status, version, captured_by, captured_at, confirmed_by, confirmed_at,
  confirmed_version, updated_at
) values
  ('88000000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001', '86000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, 300000, 'Confirmed close evidence', 'confirmed', 1, '81000000-0000-0000-0000-000000000001', now(), '81000000-0000-0000-0000-000000000001', now(), 1, now()),
  ('88000000-0000-0000-0000-000000000002', '83000000-0000-0000-0000-000000000001', '86000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, 25000, 'Draft close evidence', 'draft', 1, '81000000-0000-0000-0000-000000000001', now(), null, null, null, now());

insert into public.shifts (
  id, location_id, service_day_id, membership_id, business_date, started_at, ended_at
) values (
  '89000000-0000-0000-0000-000000000001',
  '83000000-0000-0000-0000-000000000001',
  '86000000-0000-0000-0000-000000000001',
  '84000000-0000-0000-0000-000000000003',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  now() - interval '2 hours',
  null
);

insert into public.invoice_records (
  id, restaurant_id, location_id, uploaded_by, storage_path,
  original_filename, original_mime_type, original_size_bytes, status
) values
  ('8a000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001/8a000000-0000-0000-0000-000000000001/test.pdf', 'needs-review.pdf', 'application/pdf', 100, 'needs_review'),
  ('8a000000-0000-0000-0000-000000000002', '82000000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001/8a000000-0000-0000-0000-000000000002/test.pdf', 'approved.pdf', 'application/pdf', 100, 'approved');

select ok(to_regclass('public.service_day_closures') is not null, 'service_day_closures table exists');
select ok(to_regclass('public.service_day_closure_revisions') is not null, 'service_day_closure_revisions table exists');
select ok(to_regclass('public.service_day_handoff_notes') is not null, 'service_day_handoff_notes table exists');
select ok(to_regprocedure('public.can_close_service_day(uuid)') is not null, 'can_close_service_day helper exists');
select ok(to_regprocedure('public.close_service_day(uuid,uuid,date,uuid,integer,bigint,bigint,bigint,bigint,bigint,text)') is not null, 'close_service_day RPC exists');
select ok(to_regprocedure('public.correct_service_day_closure(uuid,integer,uuid,integer,bigint,bigint,bigint,bigint,bigint,text,text)') is not null, 'correct_service_day_closure RPC exists');
select ok(to_regprocedure('public.add_service_day_handoff_note(uuid,uuid,date,text)') is not null, 'handoff note RPC exists');
select ok(to_regprocedure('public.get_service_day_close_state(uuid,date)') is not null, 'close state RPC exists');
select ok((select relrowsecurity from pg_class where oid='public.service_day_closures'::regclass), 'closure RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.service_day_closure_revisions'::regclass), 'closure revision RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.service_day_handoff_notes'::regclass), 'handoff note RLS enabled');
select ok(not has_function_privilege('anon', 'public.close_service_day(uuid,uuid,date,uuid,integer,bigint,bigint,bigint,bigint,bigint,text)', 'EXECUTE'), 'anonymous cannot close');
select ok(not has_function_privilege('anon', 'public.get_service_day_close_state(uuid,date)', 'EXECUTE'), 'anonymous cannot read close state');
select ok(not has_function_privilege('authenticated', 'public.cash_expense_reconciliation_snapshot(uuid,date)', 'EXECUTE'), 'internal reconciliation snapshot is not exposed to authenticated clients');

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','81000000-0000-0000-0000-000000000001','role','authenticated')::text, true);
select ok(public.can_close_service_day('83000000-0000-0000-0000-000000000001'), 'owner can close restaurant location without assignment');

select set_config('request.jwt.claims', json_build_object('sub','81000000-0000-0000-0000-000000000002','role','authenticated')::text, true);
select ok(public.can_close_service_day('83000000-0000-0000-0000-000000000001'), 'assigned closer capability grants close access');

select set_config('request.jwt.claims', json_build_object('sub','81000000-0000-0000-0000-000000000003','role','authenticated')::text, true);
select ok(not public.can_close_service_day('83000000-0000-0000-0000-000000000001'), 'assigned employee without close capability is denied');
select throws_ok($$select * from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)$$, 'P0001', null, 'non-closer cannot read closing state');

select set_config('request.jwt.claims', json_build_object('sub','81000000-0000-0000-0000-000000000004','role','authenticated')::text, true);
select ok(not public.can_close_service_day('83000000-0000-0000-0000-000000000001'), 'foreign owner cannot close another tenant location');

select set_config('request.jwt.claims', json_build_object('sub','81000000-0000-0000-0000-000000000002','role','authenticated')::text, true);
select is((select total_revenue_czk_minor from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '10000000', 'close state reuses exact M1 total revenue');
select is((select cash_register_expenses_czk_minor from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '400000', 'close state reuses exact M1 cash-register expenses');
select is((select current_confirmed_cash_expenses_minor from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '300000', 'readiness includes confirmed M4B1 evidence');
select is((select current_cash_expense_difference_minor from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '100000', 'readiness includes signed M4B2 difference');
select is((select draft_cash_expense_count from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 1, 'readiness surfaces draft cash evidence count');
select is((select open_shift_count from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 1, 'readiness surfaces open shift warning');
select is((select invoices_needing_review_count from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 1, 'readiness counts only invoices needing review');
select ok(not (select is_closed from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 'service day starts unclosed');

select throws_ok($$select * from public.close_service_day('8b000000-0000-0000-0000-000000000099','83000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'87000000-0000-0000-0000-000000000001',99,100,100,100,100,100,'stale')$$, 'P0001', 'Revenue changed; reload the closing review before closing', 'stale Revenue version cannot close');
select throws_ok($$select * from public.close_service_day('8b000000-0000-0000-0000-000000000098','83000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date + 1,'87000000-0000-0000-0000-000000000001',1,100,100,100,100,100,'future')$$, 'P0001', 'A future service day cannot be closed', 'future service day is rejected');
select throws_ok($$select * from public.close_service_day('8b000000-0000-0000-0000-000000000097','83000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1,'87000000-0000-0000-0000-000000000002',1,100,100,100,100,100,'historical closer')$$, 'P0001', 'Operational closers may close only the current service day', 'non-owner closer cannot close historical day');

select ok((select count(*) = 1 from public.close_service_day('8b000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'87000000-0000-0000-0000-000000000001',1,12345,6789,12500,2500,900,'  Normal close  ')), 'authorized closer can close current day');
select is((select closed_by from public.service_day_closures where id='8b000000-0000-0000-0000-000000000001'), '81000000-0000-0000-0000-000000000002'::uuid, 'closer actor comes from auth');
select ok((select closed_at <= now() and closed_at >= now() - interval '5 seconds' from public.service_day_closures where id='8b000000-0000-0000-0000-000000000001'), 'close timestamp comes from DB');
select is((select note from public.service_day_closures where id='8b000000-0000-0000-0000-000000000001'), 'Normal close', 'closing note is normalized');
select is((select usd_minor from public.service_day_closures where id='8b000000-0000-0000-0000-000000000001'), 12345::bigint, 'USD amount stored exactly');
select is((select gbp_minor from public.service_day_closures where id='8b000000-0000-0000-0000-000000000001'), 6789::bigint, 'GBP amount stored exactly');
select is((select physical_eur_minor from public.service_day_closures where id='8b000000-0000-0000-0000-000000000001'), 12500::bigint, 'physical EUR stored exactly');
select is((select cash_expense_confirmed_minor_at_close from public.service_day_closures where id='8b000000-0000-0000-0000-000000000001'), 300000::bigint, 'close snapshots confirmed cash evidence');
select is((select cash_expense_difference_minor_at_close from public.service_day_closures where id='8b000000-0000-0000-0000-000000000001'), 100000::bigint, 'close snapshots unresolved cash difference without blocking');
select is((select cash_expense_acknowledgment_id_at_close from public.service_day_closures where id='8b000000-0000-0000-0000-000000000001'), null::uuid, 'unacknowledged difference remains explicit at close');
select ok((select is_closed from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 'readiness shows day closed');
select ok((select revenue_binding_current from public.get_service_day_close_state('83000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 'new close is bound to current exact Revenue version');
select ok((select count(*) = 1 from public.close_service_day('8b000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'87000000-0000-0000-0000-000000000001',1,12345,6789,12500,2500,900,'Normal close')), 'exact close retry is idempotent');
select is((select count(*)::integer from public.service_day_closures where location_id='83000000-0000-0000-0000-000000000001' and business_date=((now() at time zone 'Europe/Prague') - interval '5 hours')::date), 1, 'exact retry does not duplicate close');
select throws_ok($$select * from public.close_service_day('8b000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'87000000-0000-0000-0000-000000000001',1,999,6789,12500,2500,900,'Normal close')$$, 'P0001', 'Closure id is already used with a different payload', 'conflicting close UUID reuse is rejected');
select throws_ok($$select * from public.close_service_day('8b000000-0000-0000-0000-000000000002','83000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'87000000-0000-0000-0000-000000000001',1,12345,6789,12500,2500,900,'Another id')$$, 'P0001', 'This service day is already closed', 'second close identity for same day is rejected');

select set_config('request.jwt.claims', json_build_object('sub','81000000-0000-0000-0000-000000000001','role','authenticated')::text, true);
select ok((select count(*) = 1 from public.close_service_day('8b000000-0000-0000-0000-000000000003','83000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1,'87000000-0000-0000-0000-000000000002',1,0,0,5000,0,0,'Historical recovery')), 'owner can deliberately close historical Revenue day');

reset role;
select * from finish();
rollback;
