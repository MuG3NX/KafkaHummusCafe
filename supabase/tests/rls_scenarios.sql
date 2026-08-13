begin;

select plan(99);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'employee@test.local', 'not-used', now()),
  ('44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'submitter-a@test.local', 'not-used', now()),
  ('55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated', 'submitter-b@test.local', 'not-used', now()),
  ('66666666-6666-6666-6666-666666666666', 'authenticated', 'authenticated', 'owner@test.local', 'not-used', now()),
  ('77777777-7777-7777-7777-777777777777', 'authenticated', 'authenticated', 'cross-midnight@test.local', 'not-used', now());

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
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', '66666666-6666-6666-6666-666666666666', 'owner'),
  ('ffffffff-ffff-ffff-ffff-ffffffffffff', '11111111-1111-1111-1111-111111111111', '77777777-7777-7777-7777-777777777777', 'employee');

insert into public.membership_location_assignments (membership_id, location_id, can_submit_revenue)
values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '88888888-8888-8888-8888-888888888888', true),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', true),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '88888888-8888-8888-8888-888888888888', true),
  ('ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', false);

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

do $$
declare
  current_service_date date;
  local_shift_date date;
  shift_start timestamptz;
  shift_end timestamptz;
begin
  current_service_date := (now() at time zone 'Europe/Prague')::date;
  if (now() at time zone 'Europe/Prague')::time < time '05:00:00' then
    current_service_date := current_service_date - 1;
  end if;
  current_service_date := current_service_date - 3;
  local_shift_date := current_service_date + 1;
  shift_start := (local_shift_date::timestamp + time '01:00:00') at time zone 'Europe/Prague';
  shift_end := (local_shift_date::timestamp + time '06:00:00') at time zone 'Europe/Prague';
  insert into public.service_days (id, location_id, business_date)
  values ('abababab-abab-abab-abab-abababababab', '22222222-2222-2222-2222-222222222222', current_service_date);
  insert into public.shifts (id, location_id, service_day_id, membership_id, business_date, started_at, ended_at)
  values ('cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd', '22222222-2222-2222-2222-222222222222', 'abababab-abab-abab-abab-abababababab', 'ffffffff-ffff-ffff-ffff-ffffffffffff', current_service_date, shift_start, shift_end);
end;
$$;

set role authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '44444444-4444-4444-4444-444444444444', 'role', 'authenticated')::text, true);
select is(public.get_business_date_for_instant('22222222-2222-2222-2222-222222222222', '2026-08-12 23:30:00+00'::timestamptz), '2026-08-12'::date, 'before 05:00 Europe/Prague belongs to the previous service day');
select is(public.get_business_date_for_instant('22222222-2222-2222-2222-222222222222', '2026-08-13 03:00:00+00'::timestamptz), '2026-08-13'::date, 'exactly 05:00 Europe/Prague starts the current service day');
select is(public.get_business_date_for_instant('22222222-2222-2222-2222-222222222222', '2026-08-13 03:00:01+00'::timestamptz), '2026-08-13'::date, 'after 05:00 Europe/Prague remains on the current service day');
select is(public.get_business_date_for_instant('22222222-2222-2222-2222-222222222222', '2026-08-13 09:00:00+00'::timestamptz), '2026-08-13'::date, 'database cutoff converts UTC using the location timezone');
select set_config('request.jwt.claims', json_build_object('sub', '33333333-3333-3333-3333-333333333333', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222'), 0, 'unauthorized employee cannot read revenue');
select set_config('request.jwt.claims', json_build_object('sub', '44444444-4444-4444-4444-444444444444', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.locations where restaurant_id = '11111111-1111-1111-1111-111111111111'), 2, 'assigned employee can list both assigned locations');
select set_config('request.jwt.claims', json_build_object('sub', '33333333-3333-3333-3333-333333333333', 'role', 'authenticated')::text, true);
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

select throws_ok(
  $$insert into public.invoice_records (id, restaurant_id, location_id, uploaded_by, storage_path, original_filename, original_mime_type, original_size_bytes)
    values ('12121212-1212-1212-1212-121212121212', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', auth.uid(),
      '22222222-2222-2222-2222-222222222222/12121212-1212-1212-1212-121212121212/invoice.pdf', 'invoice.pdf', 'application/pdf', 1000)$$,
  '42501', null, 'employee cannot insert invoice records directly'
);
select ok((select count(*) = 1 from public.create_invoice_record(
  '12121212-1212-1212-1212-121212121212',
  '22222222-2222-2222-2222-222222222222',
  '22222222-2222-2222-2222-222222222222/12121212-1212-1212-1212-121212121212/invoice.pdf',
  'invoice.pdf', 'application/pdf', 1000
)), 'authorized employee can create an invoice record');
select throws_ok(
  $$select * from public.mark_invoice_uploaded('12121212-1212-1212-1212-121212121212')$$,
  'P0001', null, 'invoice cannot be marked uploaded before its exact object exists'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('invoice-originals', '22222222-2222-2222-2222-222222222222/orphan/orphan.pdf', auth.uid(), jsonb_build_object('mimetype', 'application/pdf', 'size', 1000))$$,
  '42501', null, 'employee cannot insert an orphan invoice object'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('invoice-originals', '22222222-2222-2222-2222-222222222222/12121212-1212-1212-1212-121212121212/invoice.pdf', auth.uid(), jsonb_build_object('mimetype', 'application/pdf', 'size', 1000))$$,
  'uploader can insert the exact invoice object'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('invoice-originals', '22222222-2222-2222-2222-222222222222/12121212-1212-1212-1212-121212121212/invoice-wrong.pdf', auth.uid(), jsonb_build_object('mimetype', 'image/png', 'size', 1000))$$,
  '42501', null, 'uploader cannot insert an object with mismatched metadata'
);
select set_config('request.jwt.claims', json_build_object('sub', '33333333-3333-3333-3333-333333333333', 'role', 'authenticated')::text, true);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('invoice-originals', '22222222-2222-2222-2222-222222222222/12121212-1212-1212-1212-121212121212/invoice-employee.pdf', auth.uid(), jsonb_build_object('mimetype', 'application/pdf', 'size', 1000))$$,
  '42501', null, 'unassigned employee cannot insert an invoice object'
);
select set_config('request.jwt.claims', json_build_object('sub', '44444444-4444-4444-4444-444444444444', 'role', 'authenticated')::text, true);
select is((select count(*)::int from storage.objects where bucket_id = 'invoice-originals' and name = '22222222-2222-2222-2222-222222222222/12121212-1212-1212-1212-121212121212/invoice.pdf'), 1, 'uploader can read the exact private original');
select ok((select count(*) = 1 from public.mark_invoice_uploaded('12121212-1212-1212-1212-121212121212')), 'uploader can mark an invoice ready after exact object upload');
select throws_ok(
  $$select * from public.save_invoice_extraction_draft(
    '12121212-1212-1212-1212-121212121212', 'adapter', 'fake', 'Fake supplier', 'INV-FAKE', current_date, null,
    'CZK', 10000, 2100, 12100, '{}'::jsonb, '[]'::jsonb, null)$$,
  '42501', null, 'authenticated clients cannot invoke the legacy extraction writer'
);
select throws_ok(
  $$select * from public.save_invoice_adapter_draft(
    '12121212-1212-1212-1212-121212121212', auth.uid(), 'fake', null, null, null, null,
    'CZK', null, null, null, '{}'::jsonb, '[]'::jsonb)$$,
  '42501', null, 'authenticated clients cannot spoof provider output'
);
set role service_role;
select ok((select count(*) = 1 from public.save_invoice_adapter_draft(
  '12121212-1212-1212-1212-121212121212', '44444444-4444-4444-4444-444444444444', 'none', null, null, null, null,
  'CZK', null, null, null, '{}'::jsonb, '["No OCR provider configured"]'::jsonb
)), 'trusted server adapter can create an explicitly untrusted draft');
set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '44444444-4444-4444-4444-444444444444', 'role', 'authenticated')::text, true);
select is((select status from public.invoice_records where id = '12121212-1212-1212-1212-121212121212'), 'needs_review', 'invoice enters human review state');
select is((select supplier_name from public.invoice_extraction_drafts where invoice_id = '12121212-1212-1212-1212-121212121212' order by version desc limit 1), null, 'empty adapter draft remains empty until human review');
select is((select count(*)::int from public.invoice_records where id = '12121212-1212-1212-1212-121212121212'), 1, 'uploader can read own invoice record');
select is((select count(*)::int from public.invoice_extraction_drafts where invoice_id = '12121212-1212-1212-1212-121212121212'), 1, 'uploader can read own invoice draft');
select throws_ok(
  $$update storage.objects set metadata = jsonb_set(metadata, '{size}', '2000'::jsonb) where bucket_id = 'invoice-originals' and name = '22222222-2222-2222-2222-222222222222/12121212-1212-1212-1212-121212121212/invoice.pdf'$$,
  '42501', null, 'employee cannot update invoice storage objects'
);
select throws_ok(
  $$delete from storage.objects where bucket_id = 'invoice-originals' and name = '22222222-2222-2222-2222-222222222222/12121212-1212-1212-1212-121212121212/invoice.pdf'$$,
  '42501', null, 'employee cannot delete invoice storage objects'
);
select throws_ok(
  $$update public.invoice_records set original_filename = 'tampered.pdf' where id = '12121212-1212-1212-1212-121212121212'$$,
  '42501', null, 'employee cannot update invoice records directly'
);
select throws_ok(
  $$delete from public.invoice_records where id = '12121212-1212-1212-1212-121212121212'$$,
  '42501', null, 'employee cannot delete invoice records directly'
);
select throws_ok(
  $$select * from public.approve_invoice('12121212-1212-1212-1212-121212121212', 'employee approval attempt')$$,
  'P0001', null, 'employee cannot approve invoices'
);

select set_config('request.jwt.claims', json_build_object('sub', '55555555-5555-5555-5555-555555555555', 'role', 'authenticated')::text, true);
select ok(public.can_access_location('22222222-2222-2222-2222-222222222222') and public.can_access_location('88888888-8888-8888-8888-888888888888'), 'one membership can be assigned to multiple locations');
select is((select count(*)::int from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222' and business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222')), 1, 'authorized second submitter sees shared current-day status');
select is((select count(*)::int from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222' and business_date = current_date - 1), 0, 'authorized submitter cannot read arbitrary financial history');

select set_config('request.jwt.claims', json_build_object('sub', '66666666-6666-6666-6666-666666666666', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.invoice_audit_events where invoice_id = '12121212-1212-1212-1212-121212121212'), 3, 'owner can read invoice creation/upload/draft audit');
select throws_ok(
  $$select * from public.approve_invoice('12121212-1212-1212-1212-121212121212', 'blank draft')$$,
  'P0001', null, 'owner cannot approve a blank adapter draft'
);
select ok((select count(*) = 1 from public.save_invoice_manual_draft(
  '12121212-1212-1212-1212-121212121212', 'Test supplier', 'INV-001', current_date, current_date + 14,
  'CZK', 10000, 2100, 12100, '{}'::jsonb, '[]'::jsonb, null
)), 'owner can save the human-reviewed invoice draft');
select ok((select count(*) = 1 from public.approve_invoice('12121212-1212-1212-1212-121212121212', 'reviewed by owner')), 'owner can approve a valid invoice draft');
select is((select status from public.invoice_records where id = '12121212-1212-1212-1212-121212121212'), 'approved', 'approval changes invoice status');
select is((select approved_draft_version from public.invoice_records where id = '12121212-1212-1212-1212-121212121212'), (select max(version) from public.invoice_extraction_drafts where invoice_id = '12121212-1212-1212-1212-121212121212'), 'approval points to the exact approved draft version');
select ok((select count(*) = 1 from public.save_invoice_manual_draft(
  '12121212-1212-1212-1212-121212121212', 'Corrected supplier', 'INV-001', current_date, current_date + 14,
  'CZK', 10000, 2100, 12100, '{}'::jsonb, '[]'::jsonb, 'supplier name corrected'
)), 'owner can save an audited correction to an approved invoice');
select is((select status from public.invoice_records where id = '12121212-1212-1212-1212-121212121212'), 'needs_review', 'invoice correction returns it to review');
select ok((select count(*) = 1 from public.approve_invoice('12121212-1212-1212-1212-121212121212', 're-reviewed by owner')), 'owner can re-approve a corrected invoice');
select is((select count(*)::int from public.invoice_audit_events where invoice_id = '12121212-1212-1212-1212-121212121212'), 7, 'invoice audit remains append-only across approval and correction');
select is((select count(*)::int from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222'), 2, 'owner can read location history');
select ok((select count(*) = 1 from public.correct_revenue_entry((select id from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222' and business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222')), 126000, 80000, 46000, 1200, 350, 44800, 'corrected closing note', 'cash count corrected')), 'owner correction succeeds');
select is((select count(*)::int from public.revenue_revisions where revenue_entry_id = (select id from public.revenue_entries where location_id = '22222222-2222-2222-2222-222222222222' and business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222'))), 1, 'owner correction creates one revision');
select is((select previous_values->>'total_revenue_czk_minor' from public.revenue_revisions limit 1), '125000', 'revision preserves previous values');

select set_config('request.jwt.claims', json_build_object('sub', '44444444-4444-4444-4444-444444444444', 'role', 'authenticated')::text, true);
select ok((select count(*) = 1 from public.start_shift('22222222-2222-2222-2222-222222222222')), 'assigned employee can start a shift');
select ok((select started_at <= clock_timestamp() and started_at > clock_timestamp() - interval '1 minute'
  from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' and ended_at is null), 'shift start timestamp comes from the database clock');
select is((select count(*)::int from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'), 1, 'employee can read own shift');
select throws_ok(
  $$select * from public.start_shift('22222222-2222-2222-2222-222222222222')$$,
  'P0001', null, 'second open shift for the employee is rejected'
);
select ok((select count(*) = 1 from public.end_shift((select id from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' and ended_at is null))), 'employee can end own open shift');
select throws_ok(
  $$select * from public.start_shift('22222222-2222-2222-2222-222222222222')$$,
  'P0001', null, 'second shift for the same service day is rejected'
);

select set_config('request.jwt.claims', json_build_object('sub', '55555555-5555-5555-5555-555555555555', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.shifts where location_id = '22222222-2222-2222-2222-222222222222'), 0, 'employee cannot read another employee shift');
select ok((select count(*) = 1 from public.start_shift('22222222-2222-2222-2222-222222222222')), 'second assigned employee can start a shift');
select set_config('request.jwt.claims', json_build_object('sub', '44444444-4444-4444-4444-444444444444', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select * from public.end_shift((select id from public.shifts where membership_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and ended_at is null))$$,
  'P0001', null, 'employee cannot end another employee shift'
);
select set_config('request.jwt.claims', json_build_object('sub', '55555555-5555-5555-5555-555555555555', 'role', 'authenticated')::text, true);
select ok((select count(*) = 1 from public.end_shift((select id from public.shifts where membership_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and ended_at is null))), 'second employee can end own shift');

select set_config('request.jwt.claims', json_build_object('sub', '33333333-3333-3333-3333-333333333333', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.shifts where location_id = '22222222-2222-2222-2222-222222222222'), 0, 'unassigned employee cannot read shifts');
select throws_ok(
  $$select * from public.start_shift('22222222-2222-2222-2222-222222222222')$$,
  'P0001', null, 'unassigned employee cannot start a shift'
);

select set_config('request.jwt.claims', json_build_object('sub', '55555555-5555-5555-5555-555555555555', 'role', 'authenticated')::text, true);
select throws_ok(
  $$update public.shifts set ended_at = now() where membership_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'$$,
  '42501', null, 'employee cannot update shifts directly'
);
select throws_ok(
  $$delete from public.shifts where membership_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'$$,
  '42501', null, 'employee cannot delete shifts directly'
);
select throws_ok(
  $$insert into public.shifts (location_id, service_day_id, membership_id, business_date, started_at)
    values ('22222222-2222-2222-2222-222222222222',
      (select service_day_id from public.shifts where membership_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' limit 1),
      'cccccccc-cccc-cccc-cccc-cccccccccccc',
      public.get_current_business_date('22222222-2222-2222-2222-222222222222'), now())$$,
  '42501', null, 'employee cannot insert shifts directly'
);

select set_config('request.jwt.claims', json_build_object('sub', '66666666-6666-6666-6666-666666666666', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.shifts where location_id = '22222222-2222-2222-2222-222222222222'), 3, 'owner can read all location shifts');
select ok((select business_date = (select business_date from public.service_days where id = service_day_id)
  and ended_at > (((business_date + 1)::timestamp + time '05:00:00') at time zone 'Europe/Prague')
  from public.shifts where id = 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd'), 'cross-midnight shift retains its original service day after the cutoff');
select ok((select count(*) = 1 from public.correct_shift(
  (select id from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  (select started_at + interval '1 minute' from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  (select started_at + interval '2 hours 1 minute' from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  'forgotten clock-out corrected'
)), 'owner correction succeeds with a reason');
select throws_ok(
  $$select * from public.correct_shift(
    (select id from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    (((select business_date from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')::timestamp + time '04:00:00') at time zone 'Europe/Prague'),
    (((select business_date from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')::timestamp + time '05:00:00') at time zone 'Europe/Prague'),
    'cross-boundary correction'
  )$$,
  'P0001', null, 'owner correction cannot move a shift to another service day'
);
select throws_ok(
  $$select * from public.correct_shift(
    (select id from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    (select started_at from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    (select ended_at from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    '   '
  )$$,
  'P0001', null, 'owner correction requires a non-empty reason'
);
select throws_ok(
  $$select * from public.correct_shift(
    (select id from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    (select started_at from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    (select started_at - interval '1 second' from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    'invalid test correction'
  )$$,
  'P0001', null, 'owner correction rejects an end before the start'
);
select is((select count(*)::int from public.shift_revisions where shift_id = (select id from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')), 1, 'owner correction creates an append-only shift revision');
select is((select reason from public.shift_revisions where shift_id = (select id from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')), 'forgotten clock-out corrected', 'shift revision stores the correction reason');
select is((select extract(epoch from ended_at - started_at)::bigint from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'), 7200::bigint, 'totals derive two corrected hours from timestamps');
select ok((select business_date = public.get_current_business_date('22222222-2222-2222-2222-222222222222') from public.shifts where membership_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'), 'correction retains the original service day association');
select is((select count(*)::int from public.shifts where business_date = (public.get_current_business_date('22222222-2222-2222-2222-222222222222') - 1)), 0, 'shift totals group by explicit service-day date');
select set_config('request.jwt.claims', json_build_object('sub', '55555555-5555-5555-5555-555555555555', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.shift_revisions), 0, 'employee cannot read shift audit history');

select * from finish();
rollback;
