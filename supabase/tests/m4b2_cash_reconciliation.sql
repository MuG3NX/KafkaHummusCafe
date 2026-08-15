begin;

select plan(49);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values
  ('71000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'm4b2-owner@test.local', 'not-used', now()),
  ('71000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'm4b2-manager@test.local', 'not-used', now()),
  ('71000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'm4b2-employee@test.local', 'not-used', now()),
  ('71000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'm4b2-unassigned-manager@test.local', 'not-used', now()),
  ('71000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'm4b2-foreign-owner@test.local', 'not-used', now());

insert into public.restaurants (id, name)
values
  ('72000000-0000-0000-0000-000000000001', 'M4B2 KAFKA'),
  ('72000000-0000-0000-0000-000000000002', 'M4B2 Foreign');

insert into public.locations (id, restaurant_id, name, timezone)
values
  ('73000000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000001', 'M4B2 Main', 'Europe/Prague'),
  ('73000000-0000-0000-0000-000000000002', '72000000-0000-0000-0000-000000000001', 'M4B2 Second', 'Europe/Prague'),
  ('73000000-0000-0000-0000-000000000003', '72000000-0000-0000-0000-000000000002', 'M4B2 Foreign', 'Europe/Prague');

insert into public.restaurant_memberships (id, restaurant_id, user_id, role)
values
  ('74000000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'owner'),
  ('74000000-0000-0000-0000-000000000002', '72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000002', 'manager'),
  ('74000000-0000-0000-0000-000000000003', '72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000003', 'employee'),
  ('74000000-0000-0000-0000-000000000004', '72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000004', 'manager'),
  ('74000000-0000-0000-0000-000000000005', '72000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000005', 'owner');

insert into public.membership_location_assignments (membership_id, location_id, can_submit_revenue)
values
  ('74000000-0000-0000-0000-000000000002', '73000000-0000-0000-0000-000000000001', false),
  ('74000000-0000-0000-0000-000000000003', '73000000-0000-0000-0000-000000000001', false);

insert into public.service_days (id, location_id, business_date)
values
  ('75000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date),
  ('75000000-0000-0000-0000-000000000002', '73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1),
  ('75000000-0000-0000-0000-000000000003', '73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 2),
  ('75000000-0000-0000-0000-000000000004', '73000000-0000-0000-0000-000000000002', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date),
  ('75000000-0000-0000-0000-000000000005', '73000000-0000-0000-0000-000000000003', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date);

insert into public.revenue_entries (
  id, location_id, service_day_id, business_date, submitted_by,
  total_revenue_czk_minor, card_czk_minor, cash_czk_minor,
  cash_register_expenses_czk_minor, euros_minor,
  physical_cash_handed_over_czk_minor, note
) values
  ('76000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, '71000000-0000-0000-0000-000000000001', 100000, 60000, 40000, 40000, 0, 0, 'M4B2 difference'),
  ('76000000-0000-0000-0000-000000000002', '73000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000002', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1, '71000000-0000-0000-0000-000000000001', 100000, 60000, 40000, 10000, 0, 0, 'M4B2 matched'),
  ('76000000-0000-0000-0000-000000000003', '73000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000003', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 2, '71000000-0000-0000-0000-000000000001', 100000, 60000, 40000, 5000, 0, 0, 'M4B2 manager ack'),
  ('76000000-0000-0000-0000-000000000004', '73000000-0000-0000-0000-000000000002', '75000000-0000-0000-0000-000000000004', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, '71000000-0000-0000-0000-000000000001', 100000, 60000, 40000, 10000, 0, 0, 'M4B2 over explained'),
  ('76000000-0000-0000-0000-000000000005', '73000000-0000-0000-0000-000000000003', '75000000-0000-0000-0000-000000000005', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, '71000000-0000-0000-0000-000000000005', 100000, 60000, 40000, 8000, 0, 0, 'M4B2 foreign');

insert into public.cash_expense_entries (
  id, location_id, service_day_id, business_date, amount_czk_minor, description,
  status, version, captured_by, captured_at, confirmed_by, confirmed_at, confirmed_version, updated_at
) values
  ('77000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, 30000, 'Confirmed A', 'confirmed', 1, '71000000-0000-0000-0000-000000000001', now(), '71000000-0000-0000-0000-000000000001', now(), 1, now()),
  ('77000000-0000-0000-0000-000000000002', '73000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, 7000, 'Confirmed B', 'confirmed', 1, '71000000-0000-0000-0000-000000000001', now(), '71000000-0000-0000-0000-000000000001', now(), 1, now()),
  ('77000000-0000-0000-0000-000000000003', '73000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, 5000, 'Draft ignored', 'draft', 1, '71000000-0000-0000-0000-000000000001', now(), null, null, null, now()),
  ('77000000-0000-0000-0000-000000000004', '73000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000002', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1, 10000, 'Matched evidence', 'confirmed', 1, '71000000-0000-0000-0000-000000000001', now(), '71000000-0000-0000-0000-000000000001', now(), 1, now()),
  ('77000000-0000-0000-0000-000000000005', '73000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000003', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 2, 4000, 'Manager evidence', 'confirmed', 1, '71000000-0000-0000-0000-000000000002', now(), '71000000-0000-0000-0000-000000000002', now(), 1, now()),
  ('77000000-0000-0000-0000-000000000006', '73000000-0000-0000-0000-000000000002', '75000000-0000-0000-0000-000000000004', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date, 12000, 'Over explained evidence', 'confirmed', 1, '71000000-0000-0000-0000-000000000001', now(), '71000000-0000-0000-0000-000000000001', now(), 1, now());

create temp table m4b2_revenue_before as
select to_jsonb(entry)::text as row_state from public.revenue_entries entry where entry.id = '76000000-0000-0000-0000-000000000001';
create temp table m4b2_expenses_before as
select jsonb_agg(to_jsonb(entry) order by entry.id)::text as row_state
from public.cash_expense_entries entry
where entry.location_id = '73000000-0000-0000-0000-000000000001'
  and entry.business_date = ((now() at time zone 'Europe/Prague') - interval '5 hours')::date;
grant select on m4b2_revenue_before, m4b2_expenses_before to authenticated;

select ok(to_regclass('public.cash_expense_reconciliation_acknowledgments') is not null, 'acknowledgment table exists');
select ok(to_regprocedure('public.get_cash_expense_reconciliation(uuid,date)') is not null, 'reconciliation read RPC exists');
select ok(to_regprocedure('public.acknowledge_cash_expense_difference(uuid,uuid,date,uuid,integer,bigint,bigint,text,bigint,text)') is not null, 'acknowledgment RPC exists');
select ok((select relrowsecurity from pg_class where oid = 'public.cash_expense_reconciliation_acknowledgments'::regclass), 'acknowledgment RLS is enabled');
select ok(not has_function_privilege('anon', 'public.get_cash_expense_reconciliation(uuid,date)', 'EXECUTE'), 'anonymous cannot execute reconciliation RPC');
select ok(not has_function_privilege('anon', 'public.acknowledge_cash_expense_difference(uuid,uuid,date,uuid,integer,bigint,bigint,text,bigint,text)', 'EXECUTE'), 'anonymous cannot acknowledge');
select ok(has_function_privilege('authenticated', 'public.get_cash_expense_reconciliation(uuid,date)', 'EXECUTE'), 'authenticated role may enter reconciliation RPC');
select ok(has_function_privilege('authenticated', 'public.acknowledge_cash_expense_difference(uuid,uuid,date,uuid,integer,bigint,bigint,text,bigint,text)', 'EXECUTE'), 'authenticated role may enter acknowledgment RPC');

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '71000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

select ok((select has_revenue from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 'owner reconciliation sees submitted Revenue');
select is((select closing_expenses_czk_minor from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '40000', 'closing aggregate comes from M1 Revenue');
select is((select confirmed_cash_expenses_czk_minor from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '37000', 'only confirmed M4B1 evidence is summed');
select is((select difference_czk_minor from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '3000', 'under-explained day returns positive difference');
select is((select confirmed_count from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 2, 'confirmed count excludes Draft evidence');
select is((select draft_count from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 1, 'draft count is surfaced separately');
select is(length((select confirmed_source_fingerprint from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date))), 64, 'confirmed source fingerprint is a SHA-256 hex digest');
select is((select difference_czk_minor from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1)), '0', 'matched day returns zero difference');
select is((select difference_czk_minor from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000002', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '-2000', 'over-explained day returns negative difference without clamping');
select ok(not (select has_revenue from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 3)), 'missing Revenue is represented explicitly');
select is((select difference_czk_minor from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 3)), null::text, 'missing Revenue produces no fake difference');
select is((select to_jsonb(entry)::text from public.revenue_entries entry where entry.id = '76000000-0000-0000-0000-000000000001'), (select row_state from m4b2_revenue_before), 'read reconciliation does not mutate M1 Revenue');
select is((select jsonb_agg(to_jsonb(entry) order by entry.id)::text from public.cash_expense_entries entry where entry.location_id = '73000000-0000-0000-0000-000000000001' and entry.business_date = ((now() at time zone 'Europe/Prague') - interval '5 hours')::date), (select row_state from m4b2_expenses_before), 'read reconciliation does not mutate M4B1 evidence');

select set_config('request.jwt.claims', json_build_object('sub', '71000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
select ok((select has_revenue from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 'assigned manager may read assigned-location reconciliation');
select throws_ok($$select * from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000002', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)$$, 'P0001', null, 'manager cannot reconcile unassigned location');

select set_config('request.jwt.claims', json_build_object('sub', '71000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);
select throws_ok($$select * from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)$$, 'P0001', null, 'employee cannot read reconciliation');
select set_config('request.jwt.claims', json_build_object('sub', '71000000-0000-0000-0000-000000000004', 'role', 'authenticated')::text, true);
select throws_ok($$select * from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)$$, 'P0001', null, 'unassigned manager cannot read reconciliation');
select set_config('request.jwt.claims', json_build_object('sub', '71000000-0000-0000-0000-000000000005', 'role', 'authenticated')::text, true);
select throws_ok($$select * from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)$$, 'P0001', null, 'foreign owner cannot cross tenant');

select set_config('request.jwt.claims', json_build_object('sub', '71000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select throws_ok($$insert into public.cash_expense_reconciliation_acknowledgments (id, location_id, service_day_id, business_date, revenue_entry_id, revenue_entry_version, revenue_cash_register_expenses_czk_minor, confirmed_cash_expenses_czk_minor, confirmed_source_fingerprint, difference_czk_minor, reason, acknowledged_by) values ('78000000-0000-0000-0000-000000000099','73000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000001',current_date,'76000000-0000-0000-0000-000000000001',1,40000,37000,repeat('a',64),3000,'direct','71000000-0000-0000-0000-000000000001')$$, '42501', null, 'direct acknowledgment insert is denied');
select throws_ok($$select * from public.acknowledge_cash_expense_difference('78000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'76000000-0000-0000-0000-000000000001',1,40000,37000,(select confirmed_source_fingerprint from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)),3000,'   ')$$, 'P0001', null, 'blank acknowledgment reason is rejected');
select ok((select count(*) = 1 from public.acknowledge_cash_expense_difference('78000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'76000000-0000-0000-0000-000000000001',1,40000,37000,(select confirmed_source_fingerprint from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)),3000,'  Receipt unavailable; reviewed with closer  ')), 'owner can acknowledge an exact current difference');
select is((select reason from public.cash_expense_reconciliation_acknowledgments where id='78000000-0000-0000-0000-000000000001'), 'Receipt unavailable; reviewed with closer', 'acknowledgment reason is normalized');
select is((select acknowledged_by from public.cash_expense_reconciliation_acknowledgments where id='78000000-0000-0000-0000-000000000001'), '71000000-0000-0000-0000-000000000001'::uuid, 'acknowledgment actor comes from auth');
select ok((select acknowledged_at <= now() and acknowledged_at >= now() - interval '5 seconds' from public.cash_expense_reconciliation_acknowledgments where id='78000000-0000-0000-0000-000000000001'), 'acknowledgment timestamp comes from DB clock');
select is((select acknowledgment_id from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '78000000-0000-0000-0000-000000000001'::uuid, 'exact current acknowledgment is surfaced');
select ok((select count(*) = 1 from public.acknowledge_cash_expense_difference('78000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'76000000-0000-0000-0000-000000000001',1,40000,37000,(select confirmed_source_fingerprint from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)),3000,'Receipt unavailable; reviewed with closer')), 'exact acknowledgment retry is idempotent');
select is((select count(*)::int from public.cash_expense_reconciliation_acknowledgments where id='78000000-0000-0000-0000-000000000001'), 1, 'exact retry does not duplicate acknowledgment');
select throws_ok($$select * from public.acknowledge_cash_expense_difference('78000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'76000000-0000-0000-0000-000000000001',1,40000,37000,(select confirmed_source_fingerprint from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)),3000,'Different payload')$$, 'P0001', null, 'same acknowledgment UUID with conflicting payload is rejected');
select throws_ok($$select * from public.acknowledge_cash_expense_difference('78000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'76000000-0000-0000-0000-000000000001',1,40000,36000,(select confirmed_source_fingerprint from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)),4000,'Stale browser')$$, 'P0001', null, 'stale compared values cannot be acknowledged');
select throws_ok($$select * from public.acknowledge_cash_expense_difference('78000000-0000-0000-0000-000000000003','73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1,'76000000-0000-0000-0000-000000000002',1,10000,10000,(select confirmed_source_fingerprint from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1)),0,'No difference')$$, 'P0001', null, 'matched day cannot be acknowledged');

select set_config('request.jwt.claims', json_build_object('sub', '71000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
select ok((select count(*) = 1 from public.acknowledge_cash_expense_difference('78000000-0000-0000-0000-000000000004','73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 2,'76000000-0000-0000-0000-000000000003',1,5000,4000,(select confirmed_source_fingerprint from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 2)),1000,'Manager reviewed')), 'assigned manager may acknowledge assigned-location difference');
select set_config('request.jwt.claims', json_build_object('sub', '71000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);
select throws_ok($$select * from public.acknowledge_cash_expense_difference('78000000-0000-0000-0000-000000000005','73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'76000000-0000-0000-0000-000000000001',1,40000,37000,repeat('0',64),3000,'Employee')$$, 'P0001', null, 'employee cannot acknowledge');

select set_config('request.jwt.claims', json_build_object('sub', '71000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select ok((select count(*) = 1 from public.correct_cash_expense('77000000-0000-0000-0000-000000000002',1,((now() at time zone 'Europe/Prague') - interval '5 hours')::date,7000,'Confirmed B','Re-save same amount to prove fingerprint staleness')), 'confirmed evidence can be corrected without changing amount');
select ok((select count(*) = 1 from public.confirm_cash_expense('77000000-0000-0000-0000-000000000002',2)), 'corrected evidence can be re-confirmed at new version');
select is((select difference_czk_minor from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '3000', 'numeric difference remains the same after same-amount correction');
select is((select acknowledgment_id from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), null::uuid, 'confirmed-evidence fingerprint change makes old acknowledgment stale even when total is unchanged');

select ok((select count(*) = 1 from public.acknowledge_cash_expense_difference('78000000-0000-0000-0000-000000000006','73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date,'76000000-0000-0000-0000-000000000001',1,40000,37000,(select confirmed_source_fingerprint from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)),3000,'Acknowledged after evidence review')), 'owner can acknowledge the new exact evidence fingerprint');
select ok((select count(*) = 1 from public.correct_revenue_entry('76000000-0000-0000-0000-000000000001',100000,60000,40000,40000,0,0,'M4B2 difference','Version-only correction for test')), 'existing M1 audited correction increments Revenue version');
select is((select difference_czk_minor from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), '3000', 'same Revenue amount preserves numeric difference');
select is((select acknowledgment_id from public.get_cash_expense_reconciliation('73000000-0000-0000-0000-000000000001',((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), null::uuid, 'Revenue version change makes old acknowledgment stale even when amount is unchanged');
select is((select count(*)::int from public.cash_expense_reconciliation_acknowledgments where location_id='73000000-0000-0000-0000-000000000001' and business_date=((now() at time zone 'Europe/Prague') - interval '5 hours')::date), 2, 'stale acknowledgment history remains append-only');

reset role;
select * from finish();
rollback;
