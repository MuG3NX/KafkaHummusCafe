begin;

select plan(24);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values
  ('8d000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'm4c-note-owner@test.local', 'not-used', now()),
  ('8d000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'm4c-note-closer@test.local', 'not-used', now()),
  ('8d000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'm4c-note-worker@test.local', 'not-used', now());

insert into public.restaurants (id, name)
values ('8d000000-0000-0000-0000-000000000010', 'M4C Notes Restaurant');

insert into public.locations (id, restaurant_id, name, timezone)
values ('8d000000-0000-0000-0000-000000000020', '8d000000-0000-0000-0000-000000000010', 'M4C Notes Location', 'Europe/Prague');

insert into public.restaurant_memberships (id, restaurant_id, user_id, role)
values
  ('8d000000-0000-0000-0000-000000000030', '8d000000-0000-0000-0000-000000000010', '8d000000-0000-0000-0000-000000000001', 'owner'),
  ('8d000000-0000-0000-0000-000000000031', '8d000000-0000-0000-0000-000000000010', '8d000000-0000-0000-0000-000000000002', 'employee'),
  ('8d000000-0000-0000-0000-000000000032', '8d000000-0000-0000-0000-000000000010', '8d000000-0000-0000-0000-000000000003', 'employee');

insert into public.membership_location_assignments (id, membership_id, location_id, can_submit_revenue, can_close_day)
values
  ('8d000000-0000-0000-0000-000000000040', '8d000000-0000-0000-0000-000000000031', '8d000000-0000-0000-0000-000000000020', false, true),
  ('8d000000-0000-0000-0000-000000000041', '8d000000-0000-0000-0000-000000000032', '8d000000-0000-0000-0000-000000000020', false, false);

insert into public.service_days (id, location_id, business_date)
values
  ('8d000000-0000-0000-0000-000000000050', '8d000000-0000-0000-0000-000000000020', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date),
  ('8d000000-0000-0000-0000-000000000051', '8d000000-0000-0000-0000-000000000020', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1);

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','8d000000-0000-0000-0000-000000000002','role','authenticated')::text, true);

select ok((select count(*) = 1 from public.add_service_day_handoff_note(
  '8d000000-0000-0000-0000-000000000060',
  '8d000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  '  Fridge 2 is making noise; check tomorrow.  '
)), 'authorized closer can add current-day handoff note');
select is((select note from public.service_day_handoff_notes where id='8d000000-0000-0000-0000-000000000060'), 'Fridge 2 is making noise; check tomorrow.', 'handoff note is normalized');
select is((select created_by from public.service_day_handoff_notes where id='8d000000-0000-0000-0000-000000000060'), '8d000000-0000-0000-0000-000000000002'::uuid, 'handoff note actor comes from auth');
select ok((select created_at <= now() and created_at >= now() - interval '5 seconds' from public.service_day_handoff_notes where id='8d000000-0000-0000-0000-000000000060'), 'handoff note timestamp comes from DB');
select ok((select count(*) = 1 from public.add_service_day_handoff_note(
  '8d000000-0000-0000-0000-000000000060',
  '8d000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  'Fridge 2 is making noise; check tomorrow.'
)), 'exact handoff retry is idempotent');
select is((select count(*)::integer from public.service_day_handoff_notes where id='8d000000-0000-0000-0000-000000000060'), 1, 'handoff retry does not duplicate note');
select throws_ok($$select * from public.add_service_day_handoff_note(
  '8d000000-0000-0000-0000-000000000060',
  '8d000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  'Different text'
)$$, 'P0001', 'Handoff note id is already used with a different payload', 'conflicting handoff UUID reuse rejected');
select throws_ok($$select * from public.add_service_day_handoff_note(
  '8d000000-0000-0000-0000-000000000061',
  '8d000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1,
  'Historical closer note'
)$$, 'P0001', 'Operational closers may add notes only to the current service day', 'non-owner closer cannot add historical handoff note');
select throws_ok($$select * from public.add_service_day_handoff_note(
  '8d000000-0000-0000-0000-000000000062',
  '8d000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date + 1,
  'Future note'
)$$, 'P0001', 'A future service day cannot receive a handoff note', 'future handoff note rejected');
select is((select handoff_note_count from public.get_service_day_close_state('8d000000-0000-0000-0000-000000000020', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 1, 'readiness counts handoff notes');
select is((select latest_handoff_note from public.get_service_day_close_state('8d000000-0000-0000-0000-000000000020', ((now() at time zone 'Europe/Prague') - interval '5 hours')::date)), 'Fridge 2 is making noise; check tomorrow.', 'readiness surfaces latest handoff note');

select set_config('request.jwt.claims', json_build_object('sub','8d000000-0000-0000-0000-000000000003','role','authenticated')::text, true);
select throws_ok($$select * from public.add_service_day_handoff_note(
  '8d000000-0000-0000-0000-000000000063',
  '8d000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  'Worker note'
)$$, 'P0001', 'Not authorized to add a handoff note', 'employee without close capability cannot add handoff note');

select set_config('request.jwt.claims', json_build_object('sub','8d000000-0000-0000-0000-000000000001','role','authenticated')::text, true);
select ok((select count(*) = 1 from public.add_service_day_handoff_note(
  '8d000000-0000-0000-0000-000000000064',
  '8d000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date - 1,
  'Owner historical handoff'
)), 'owner can add deliberate historical handoff note');

select throws_ok($$insert into public.service_day_handoff_notes (id,location_id,service_day_id,business_date,note,created_by) values (
  '8d000000-0000-0000-0000-000000000070','8d000000-0000-0000-0000-000000000020','8d000000-0000-0000-0000-000000000050',current_date,'Direct note','8d000000-0000-0000-0000-000000000001'
)$$, '42501', null, 'authenticated client cannot directly insert handoff note');
select throws_ok($$update public.service_day_handoff_notes set note=note$$, '42501', null, 'authenticated client cannot directly update handoff notes');
select throws_ok($$delete from public.service_day_handoff_notes$$, '42501', null, 'authenticated client cannot directly delete handoff notes');
select throws_ok($$insert into public.service_day_closures (
  id,location_id,service_day_id,business_date,revenue_entry_id,revenue_entry_version,usd_minor,gbp_minor,physical_eur_minor,physical_usd_minor,physical_gbp_minor,cash_expense_confirmed_minor_at_close,cash_expense_fingerprint_at_close,cash_expense_difference_minor_at_close,version,closed_by
) values (
  '8d000000-0000-0000-0000-000000000071','8d000000-0000-0000-0000-000000000020','8d000000-0000-0000-0000-000000000050',current_date,'8d000000-0000-0000-0000-000000000072',1,0,0,0,0,0,0,repeat('a',64),0,1,'8d000000-0000-0000-0000-000000000001'
)$$, '42501', null, 'authenticated client cannot directly insert close');
select throws_ok($$update public.service_day_closures set note=note$$, '42501', null, 'authenticated client cannot directly update completed close');
select throws_ok($$delete from public.service_day_closures$$, '42501', null, 'authenticated client cannot directly delete completed close');
select throws_ok($$insert into public.service_day_closure_revisions (closure_id,version,changed_by,reason,previous_values) values ('8d000000-0000-0000-0000-000000000071',1,'8d000000-0000-0000-0000-000000000001','Direct','{}')$$, '42501', null, 'authenticated client cannot directly insert closure revision');
select throws_ok($$update public.service_day_closure_revisions set reason=reason$$, '42501', null, 'authenticated client cannot directly update closure revisions');
select throws_ok($$delete from public.service_day_closure_revisions$$, '42501', null, 'authenticated client cannot directly delete closure revisions');

select ok(not has_function_privilege('anon','public.can_close_service_day(uuid)','EXECUTE'), 'anonymous cannot execute close capability helper');
select ok(not has_function_privilege('anon','public.add_service_day_handoff_note(uuid,uuid,date,text)','EXECUTE'), 'anonymous cannot add handoff note');

reset role;
select * from finish();
rollback;
