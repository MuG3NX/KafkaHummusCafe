begin;

select plan(3);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values ('7a000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'm4b2-retry-owner@test.local', 'not-used', now());

insert into public.restaurants (id, name)
values ('7a000000-0000-0000-0000-000000000010', 'M4B2 Retry Restaurant');

insert into public.locations (id, restaurant_id, name, timezone)
values ('7a000000-0000-0000-0000-000000000020', '7a000000-0000-0000-0000-000000000010', 'M4B2 Retry Location', 'Europe/Prague');

insert into public.restaurant_memberships (id, restaurant_id, user_id, role)
values ('7a000000-0000-0000-0000-000000000030', '7a000000-0000-0000-0000-000000000010', '7a000000-0000-0000-0000-000000000001', 'owner');

insert into public.service_days (id, location_id, business_date)
values (
  '7a000000-0000-0000-0000-000000000040',
  '7a000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date
);

insert into public.revenue_entries (
  id, location_id, service_day_id, business_date, submitted_by,
  total_revenue_czk_minor, card_czk_minor, cash_czk_minor,
  cash_register_expenses_czk_minor, euros_minor,
  physical_cash_handed_over_czk_minor, note
) values (
  '7a000000-0000-0000-0000-000000000050',
  '7a000000-0000-0000-0000-000000000020',
  '7a000000-0000-0000-0000-000000000040',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  '7a000000-0000-0000-0000-000000000001',
  100000, 60000, 40000, 4000, 0, 0, 'Retry currentness fixture'
);

insert into public.cash_expense_entries (
  id, location_id, service_day_id, business_date, amount_czk_minor, description,
  status, version, captured_by, captured_at, confirmed_by, confirmed_at,
  confirmed_version, updated_at
) values (
  '7a000000-0000-0000-0000-000000000060',
  '7a000000-0000-0000-0000-000000000020',
  '7a000000-0000-0000-0000-000000000040',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  3000,
  'Retry evidence',
  'confirmed',
  1,
  '7a000000-0000-0000-0000-000000000001',
  now(),
  '7a000000-0000-0000-0000-000000000001',
  now(),
  1,
  now()
);

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '7a000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

create temp table retry_snapshot as
select *
from public.get_cash_expense_reconciliation(
  '7a000000-0000-0000-0000-000000000020',
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date
);
grant select on retry_snapshot to authenticated;

select ok(
  (select count(*) = 1
   from public.acknowledge_cash_expense_difference(
     '7a000000-0000-0000-0000-000000000070',
     '7a000000-0000-0000-0000-000000000020',
     ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
     (select revenue_entry_id from retry_snapshot),
     (select revenue_entry_version from retry_snapshot),
     (select closing_expenses_czk_minor::bigint from retry_snapshot),
     (select confirmed_cash_expenses_czk_minor::bigint from retry_snapshot),
     (select confirmed_source_fingerprint from retry_snapshot),
     (select difference_czk_minor::bigint from retry_snapshot),
     'Initial reviewed difference'
   )),
  'initial exact acknowledgment is stored'
);

select * from public.correct_cash_expense(
  '7a000000-0000-0000-0000-000000000060',
  1,
  ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
  3000,
  'Retry evidence',
  'Same amount, new evidence version'
);
select * from public.confirm_cash_expense('7a000000-0000-0000-0000-000000000060', 2);

select throws_ok(
  $$select * from public.acknowledge_cash_expense_difference(
    '7a000000-0000-0000-0000-000000000070',
    '7a000000-0000-0000-0000-000000000020',
    ((now() at time zone 'Europe/Prague') - interval '5 hours')::date,
    (select revenue_entry_id from retry_snapshot),
    (select revenue_entry_version from retry_snapshot),
    (select closing_expenses_czk_minor::bigint from retry_snapshot),
    (select confirmed_cash_expenses_czk_minor::bigint from retry_snapshot),
    (select confirmed_source_fingerprint from retry_snapshot),
    (select difference_czk_minor::bigint from retry_snapshot),
    'Initial reviewed difference'
  )$$,
  'P0001',
  'Cash expense reconciliation is stale; reload before acknowledging',
  'exact old acknowledgment UUID cannot be replayed after source truth changes'
);

select is(
  (select acknowledgment_id
   from public.get_cash_expense_reconciliation(
     '7a000000-0000-0000-0000-000000000020',
     ((now() at time zone 'Europe/Prague') - interval '5 hours')::date
   )),
  null::uuid,
  'old acknowledgment remains history but is not current after evidence changes'
);

reset role;
select * from finish();
rollback;
