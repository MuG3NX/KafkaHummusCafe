begin;

select plan(2);
create extension if not exists pgtap;

set role authenticated;

select throws_ok(
  $$update public.cash_expense_reconciliation_acknowledgments set reason = reason$$,
  '42501',
  null,
  'authenticated client cannot directly update reconciliation acknowledgments'
);

select throws_ok(
  $$delete from public.cash_expense_reconciliation_acknowledgments$$,
  '42501',
  null,
  'authenticated client cannot directly delete reconciliation acknowledgments'
);

reset role;
select * from finish();
rollback;
