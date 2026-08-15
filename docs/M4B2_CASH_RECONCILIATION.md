# M4B2 — Daily Cash Expense Reconciliation

## Status

M4B1 Cash Expense Evidence is production-deployed with real acceptance still open in Issue #17. M4B2 is the active draft implementation in Issue #24. M4C Closing remains later in Issue #25.

## Objective

For one location/service day, compare two independent sources without mutating either:

1. M1 `revenue_entries.cash_register_expenses_czk_minor` — the daily closing aggregate.
2. Sum of **confirmed** M4B1 `cash_expense_entries.amount_czk_minor` for the same location/business date.

Draft M4B1 evidence never contributes to the confirmed total.

## Exact result

The read model returns:

- whether Revenue exists;
- exact Revenue entry identity + version;
- exact closing aggregate;
- exact confirmed-evidence total;
- exact signed difference (`closing - confirmed`);
- confirmed/draft counts;
- deterministic SHA-256 fingerprint of the exact confirmed evidence set (`id:version:amount`, sorted by id);
- a current acknowledgment only when its entire stored snapshot still matches current truth.

Money crosses the PostgREST/client boundary as decimal strings and is handled with `BigInt` in the client.

Positive difference means the closing aggregate is larger than confirmed evidence. Negative difference means confirmed evidence is larger. Never clamp either case.

## Missing Revenue

A service day without a submitted M1 Revenue row is represented explicitly rather than fabricating a zero closing aggregate:

- `has_revenue = false`;
- closing value = null;
- difference = null;
- M4B1 confirmed/draft totals may still be shown.

A difference cannot be acknowledged until Revenue exists.

## Mismatch behavior

A mismatch is non-blocking.

The operator should resolve it through the real source that is wrong:

1. add missing M4B1 evidence;
2. correct M4B1 evidence through its audited correction path;
3. if M1 is wrong, use the existing audited owner Revenue correction path;
4. if a real residual difference remains, acknowledge it with a mandatory reason.

M4B2 never auto-balances, creates an expense, changes Revenue, changes M4B1 evidence, or invents a tolerance.

## Acknowledgment truth

An acknowledgment is append-only evidence, not a status flag on Revenue or cash expenses.

It stores the exact compared snapshot:

- location/service day/business date;
- Revenue entry id + version;
- Revenue cash-register-expense aggregate;
- confirmed M4B1 total;
- confirmed-source fingerprint;
- signed difference;
- normalized reason;
- authenticated actor;
- DB timestamp.

A prior acknowledgment is considered current only if **all** of those source identities/values still match.

Therefore:

- a Revenue correction invalidates the current acknowledgment even if the expense amount stays numerically identical because the Revenue version changed;
- a confirmed M4B1 correction/re-confirmation invalidates it even when the confirmed total happens to remain identical because the evidence fingerprint changed;
- old acknowledgment rows remain append-only history.

## Retry / stale-write safety

The browser creates one acknowledgment UUID and retains the exact compared snapshot + reason across an ambiguous retry.

The write RPC accepts expected Revenue/version/totals/fingerprint/difference and rejects a stale browser snapshot.

An exact retry using the same UUID/payload/actor returns the existing row without duplicating acknowledgment history. Conflicting UUID reuse is rejected.

No offline mutation queue is introduced.

## Authorization

Reuse M4B1's narrow domain authorization:

- owner: all restaurant locations;
- manager: only explicitly assigned locations;
- employee: denied;
- unassigned manager: denied;
- foreign tenant: denied.

The comparison and acknowledgment RPCs are authenticated entrypoints, but authorization is enforced in trusted DB code. Anonymous/public execution is denied.

The acknowledgment table exposes authenticated SELECT only through RLS; direct client INSERT/UPDATE/DELETE is not granted.

## UI

Inside **Costs → Cash expenses**, the selected service day gains a reconciliation card before the capture form.

Show:

- Closing register expenses;
- Confirmed cash evidence;
- Difference;
- Draft evidence count where useful;
- state:
  - Revenue not submitted
  - Matched
  - Difference needs review
  - Difference acknowledged

When an exact current acknowledgment exists, show its reason and timestamp/actor where available.

On an unacknowledged non-zero difference, owner/assigned manager can enter a reason and deliberately acknowledge the exact current snapshot.

M4B1 capture/confirm/correction remains usable even if the reconciliation read temporarily fails; reconciliation is supplementary and must not turn an existing cash-expense write path into an availability dependency.

## Non-interference

Executable tests must prove:

- reconciliation reads do not mutate M1 Revenue;
- reconciliation reads do not mutate M4B1 evidence;
- acknowledgment inserts only append to the acknowledgment table;
- M1 owner correction naturally changes the read result;
- M4B1 capture/confirm/correct/re-confirm naturally changes the read result;
- no invoice/payment/VAT/Storage records are created or changed.

## Explicitly excluded

- hard-blocking digital close;
- tolerance thresholds;
- automatic balancing/write-offs;
- auto-generated expenses;
- invoice linking in this slice;
- paid/unpaid/payment reconciliation;
- VAT/accounting treatment;
- supplier reconciliation;
- closing checklist/Today hub implementation;
- M5/M6 work.
