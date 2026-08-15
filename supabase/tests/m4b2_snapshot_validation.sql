begin;

select plan(1);
create extension if not exists pgtap;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
values ('79000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'm4b2-snapshot@test.local', 'not-used', now());

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '79000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

select throws_ok(
  $$select * from public.acknowledge_cash_expense_difference(
    '79000000-0000-0000-0000-000000000010',
    '79000000-0000-0000-0000-000000000020',
    current_date,
    null,
    null,
    null,
    null,
    null,
    null,
    'Incomplete snapshot'
  )$$,
  'P0001',
  'A complete expected reconciliation snapshot is required',
  'direct caller cannot omit expected reconciliation fields'
);

reset role;
select * from finish();
rollback;
