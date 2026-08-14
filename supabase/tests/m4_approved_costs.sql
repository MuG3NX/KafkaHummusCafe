begin;

select plan(32);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values
  ('43000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'cost-owner@test.local', 'not-used', now()),
  ('43000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'cost-employee@test.local', 'not-used', now()),
  ('43000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'foreign-owner@test.local', 'not-used', now());

insert into public.restaurants (id, name)
values
  ('41000000-0000-0000-0000-000000000001', 'Cost Test KAFKA'),
  ('41000000-0000-0000-0000-000000000002', 'Foreign Restaurant');

insert into public.locations (id, restaurant_id, name, timezone)
values
  ('42000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', 'Main cost location', 'Europe/Prague'),
  ('42000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000001', 'Second cost location', 'Europe/Prague'),
  ('42000000-0000-0000-0000-000000000003', '41000000-0000-0000-0000-000000000002', 'Foreign cost location', 'Europe/Prague');

insert into public.restaurant_memberships (id, restaurant_id, user_id, role)
values
  ('44000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', 'owner'),
  ('44000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000002', 'employee'),
  ('44000000-0000-0000-0000-000000000003', '41000000-0000-0000-0000-000000000002', '43000000-0000-0000-0000-000000000003', 'owner');

insert into public.membership_location_assignments (membership_id, location_id, can_submit_revenue)
values ('44000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000001', false);

insert into public.invoice_records (
  id, restaurant_id, location_id, uploaded_by, storage_path,
  original_filename, original_mime_type, original_size_bytes, status, version, created_at
)
values
  ('45000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001/45000000-0000-0000-0000-000000000001/big-czk.pdf', 'big-czk.pdf', 'application/pdf', 1000, 'needs_review', 4, '2026-09-15 12:00:00+00'),
  ('45000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001/45000000-0000-0000-0000-000000000002/eur.pdf', 'eur.pdf', 'application/pdf', 1000, 'needs_review', 3, '2026-08-01 12:00:00+00'),
  ('45000000-0000-0000-0000-000000000003', '41000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001/45000000-0000-0000-0000-000000000003/september.pdf', 'september.pdf', 'application/pdf', 1000, 'needs_review', 3, '2026-08-01 12:00:00+00'),
  ('45000000-0000-0000-0000-000000000004', '41000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001/45000000-0000-0000-0000-000000000004/july.pdf', 'july.pdf', 'application/pdf', 1000, 'needs_review', 3, '2026-08-01 12:00:00+00'),
  ('45000000-0000-0000-0000-000000000005', '41000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000002', '43000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000002/45000000-0000-0000-0000-000000000005/second-location.pdf', 'second-location.pdf', 'application/pdf', 1000, 'needs_review', 3, '2026-08-01 12:00:00+00'),
  ('45000000-0000-0000-0000-000000000006', '41000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000003', '43000000-0000-0000-0000-000000000003', '42000000-0000-0000-0000-000000000003/45000000-0000-0000-0000-000000000006/foreign.pdf', 'foreign.pdf', 'application/pdf', 1000, 'needs_review', 3, '2026-08-01 12:00:00+00'),
  ('45000000-0000-0000-0000-000000000007', '41000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001/45000000-0000-0000-0000-000000000007/uploading.pdf', 'uploading.pdf', 'application/pdf', 1000, 'uploading', 1, '2026-08-01 12:00:00+00'),
  ('45000000-0000-0000-0000-000000000008', '41000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001/45000000-0000-0000-0000-000000000008/review.pdf', 'review.pdf', 'application/pdf', 1000, 'needs_review', 2, '2026-08-01 12:00:00+00'),
  ('45000000-0000-0000-0000-000000000009', '41000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001/45000000-0000-0000-0000-000000000009/rejected.pdf', 'rejected.pdf', 'application/pdf', 1000, 'rejected', 3, '2026-08-01 12:00:00+00'),
  ('45000000-0000-0000-0000-000000000010', '41000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001/45000000-0000-0000-0000-000000000010/abandoned.pdf', 'abandoned.pdf', 'application/pdf', 1000, 'abandoned', 2, '2026-08-01 12:00:00+00');

insert into public.invoice_extraction_drafts (
  invoice_id, version, source, supplier_name, invoice_number, issue_date, due_date,
  currency, net_minor, vat_minor, gross_minor, created_by
)
values
  ('45000000-0000-0000-0000-000000000001', 2, 'manual', 'Approved Big Supplier', 'CZK-BIG', '2026-08-01', null, 'CZK', 9007199254740993, 2100, 9007199254743093, '43000000-0000-0000-0000-000000000001'),
  ('45000000-0000-0000-0000-000000000001', 4, 'manual', 'Later Unapproved Draft', 'CZK-LATEST', '2026-10-01', null, 'CZK', 1, 1, 2, '43000000-0000-0000-0000-000000000001'),
  ('45000000-0000-0000-0000-000000000002', 2, 'manual', 'Euro Supplier', 'EUR-EDGE', '2026-08-31', '2026-09-14', 'EUR', 10000, 2100, 12100, '43000000-0000-0000-0000-000000000001'),
  ('45000000-0000-0000-0000-000000000003', 2, 'manual', 'September Supplier', 'SEP-1', '2026-09-01', null, 'CZK', 20000, 4200, 24200, '43000000-0000-0000-0000-000000000001'),
  ('45000000-0000-0000-0000-000000000004', 2, 'manual', 'July Supplier', 'JUL-31', '2026-07-31', null, 'CZK', 30000, 6300, 36300, '43000000-0000-0000-0000-000000000001'),
  ('45000000-0000-0000-0000-000000000005', 2, 'manual', 'Second Location Supplier', 'LOC-2', '2026-08-15', null, 'CZK', 40000, 8400, 48400, '43000000-0000-0000-0000-000000000001'),
  ('45000000-0000-0000-0000-000000000006', 2, 'manual', 'Foreign Supplier', 'FOREIGN', '2026-08-20', null, 'CZK', 50000, 10500, 60500, '43000000-0000-0000-0000-000000000003'),
  ('45000000-0000-0000-0000-000000000008', 2, 'manual', 'Review Supplier', 'REVIEW', '2026-08-10', null, 'CZK', 60000, 12600, 72600, '43000000-0000-0000-0000-000000000001'),
  ('45000000-0000-0000-0000-000000000009', 2, 'manual', 'Rejected Supplier', 'REJECTED', '2026-08-11', null, 'CZK', 70000, 14700, 84700, '43000000-0000-0000-0000-000000000001');

update public.invoice_records
set status = 'approved', approved_draft_version = 2
where id in (
  '45000000-0000-0000-0000-000000000001',
  '45000000-0000-0000-0000-000000000002',
  '45000000-0000-0000-0000-000000000003',
  '45000000-0000-0000-0000-000000000004',
  '45000000-0000-0000-0000-000000000005',
  '45000000-0000-0000-0000-000000000006'
);

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '43000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select * from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01')$$,
  'P0001', null, 'employee cannot read approved invoice costs'
);

select set_config('request.jwt.claims', json_build_object('sub', '43000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select * from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01')$$,
  'P0001', null, 'owner from another restaurant cannot read this location costs'
);

select set_config('request.jwt.claims', json_build_object('sub', '43000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01')), 2, 'owner sees only approved August invoices for the selected location');
select is((select supplier_name from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000001'), 'Approved Big Supplier', 'register reads the exact approved draft instead of the latest draft');
select is((select approved_draft_version from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000001'), 2, 'register exposes the exact approved draft pointer');
select is((select net_minor from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000001'), '9007199254740993', 'bigint money crosses the RPC boundary as exact text');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000001'), 1, 'issue date includes an invoice even when its creation timestamp is in another month');
select is((select due_date from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000001'), null, 'optional due date remains nullable');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000002'), 1, 'last day of the selected month is included');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000003'), 0, 'first day of the next month is excluded');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000004'), 0, 'previous month invoice is excluded');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000005'), 0, 'another location invoice is excluded from the selected location');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000006'), 0, 'another restaurant invoice is excluded');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id in ('45000000-0000-0000-0000-000000000007', '45000000-0000-0000-0000-000000000008', '45000000-0000-0000-0000-000000000009', '45000000-0000-0000-0000-000000000010')), 0, 'uploading review rejected and abandoned invoices are excluded');
select results_eq(
  $$select currency from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') order by currency$$,
  $$values ('CZK'::text), ('EUR'::text)$$,
  'currencies are returned as separate invoice rows'
);
select is((select storage_path from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000002'), '42000000-0000-0000-0000-000000000001/45000000-0000-0000-0000-000000000002/eur.pdf', 'register returns the authorized private-original identity');
select is((select count(*)::int from public.invoice_audit_events), 0, 'reporting RPC performs no audit or financial mutation');
select is((select provolatile::text from pg_proc where oid = 'public.get_approved_invoice_costs(uuid,date)'::regprocedure), 's', 'reporting RPC is declared stable and read-only');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-14')), 2, 'a selected date is normalized to its calendar month');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000002', '2026-08-01')), 1, 'owner can read the separately scoped second location');
select throws_ok(
  $$select * from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000003', '2026-08-01')$$,
  'P0001', null, 'owner cannot cross into another restaurant location'
);

select set_config('request.jwt.claims', json_build_object('sub', '43000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000003', '2026-08-01')), 1, 'foreign owner can read only the owned restaurant location');
select throws_ok(
  $$select * from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01')$$,
  'P0001', null, 'foreign owner remains denied from the KAFKA location'
);

set role anon;
select throws_ok(
  $$select * from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01')$$,
  '42501', null, 'anonymous caller cannot execute the cost register RPC'
);

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '43000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select ok((select count(*) = 1 from public.save_invoice_manual_draft(
  '45000000-0000-0000-0000-000000000002', 'Corrected Euro Supplier', 'EUR-EDGE', '2026-08-31', '2026-09-14',
  'EUR', 10000, 2100, 12100, '{}'::jsonb, '[]'::jsonb, 'supplier corrected'
)), 'owner can save an audited correction to an approved invoice');
select ok((select status = 'needs_review' and approved_draft_version is null from public.invoice_records where id = '45000000-0000-0000-0000-000000000002'), 'correction clears approval and returns the invoice to review');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01')), 1, 'corrected invoice disappears from the approved register immediately');
select ok((select count(*) = 1 from public.approve_invoice('45000000-0000-0000-0000-000000000002', 4, 4, 'corrected invoice re-approved')), 'owner can re-approve the exact corrected version');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01')), 2, 're-approved corrected invoice returns to the register');
select is((select supplier_name from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-08-01') where invoice_id = '45000000-0000-0000-0000-000000000002'), 'Corrected Euro Supplier', 'register returns the exact corrected version after re-approval');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-09-01')), 1, 'September register starts at the first day boundary');
select is((select count(*)::int from public.get_approved_invoice_costs('42000000-0000-0000-0000-000000000001', '2026-07-01')), 1, 'July register includes the previous month fixture only');

select * from finish();
rollback;
