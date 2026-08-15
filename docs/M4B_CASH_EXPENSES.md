# M4B1 — Cash Expense Evidence Ledger

## Status

M4B1 is the active authorized draft implementation in Issue #17. M1 Revenue is
accepted and frozen except for bugs. M2, M3, and M4A remain deployed with their
real acceptance gates open in Issues #8, #10, and #13. M4B2 reconciliation is a
later slice and is not implemented here.

## Objective

Capture individual CZK cash expenses and register movements as durable internal
evidence. These records will later help explain the daily cash-register expense
total, but they are not the closing total themselves.

## Authoritative daily total

`revenue_entries.cash_register_expenses_czk_minor` remains the authoritative
daily closing aggregate. It may contain documented and undocumented movements.
M4B1 never calculates, overwrites, updates, replaces, or reconciles it.

## Evidence identity

Every M4B1 expense records:

- exact positive CZK minor units;
- the explicit service day when cash physically left the register;
- a mandatory trimmed description/reason;
- capturing actor and database timestamp;
- confirming actor and database timestamp;
- current version and append-only audit history.

The internal record is the evidence baseline. A supplier invoice, receipt,
photo, Storage object, payment status, or invoice relationship is not required
or created in M4B1.

## Actors and location scope

- Owners may capture, read, confirm, and correct expenses for every location in
  their restaurant.
- Managers may perform those actions only where their manager membership has a
  matching `membership_location_assignments` row.
- Employees have no M4B1 access.

An authorized owner or manager may confirm their own captured expense. Capture
and confirmation actors/times remain explicit even when they are the same.
This permission is M4B-specific and does not broaden owner-only permissions in
Revenue, Shifts, Invoices, or M4A.

## Lifecycle

1. Select an authorized location.
2. Select the current or a historical service day; future days are rejected by
   the database.
3. Enter amount and description.
4. Capture creates version 1 in `draft` using database actor/time truth.
5. Confirm requires the exact current version and moves it to `confirmed`.
6. Correction requires the exact version and a mandatory reason.
7. Correction increments the version, preserves the previous state in audit,
   clears confirmation, and returns the entry to `draft`.
8. The corrected version must be explicitly confirmed again.

## Retry and recovery boundary

Capture accepts a client-generated UUID. The browser retains that UUID and the
normalized capture payload until the result is known. If transport fails after
an uncertain response, the retry uses the exact same capture identity and
payload; the database returns the existing version-1 record when the first
attempt already committed and rejects conflicting UUID reuse.

A known committed capture, confirmation, or correction remains successful even
if the following list/audit refresh fails. Refresh failure is reported
separately and never changes the verdict of the financial write. Confirmation
retries of the exact already-confirmed version do not append duplicate events.
After an uncertain correction result, the client reloads persisted state and
requires the user to reopen the evidence before another correction attempt.
Stale confirmations and corrections remain rejected. No offline mutation queue
is introduced.

## Database model

`cash_expense_entries` stores current state and uses the existing composite
service-day foreign-key pattern to keep location, service-day ID, and business
date coherent. Money is Postgres `bigint`; actors are authenticated user UUIDs;
timestamps come from the database.

`cash_expense_audit_events` is append-only evidence for `captured`, `confirmed`,
and `corrected` events. Clients receive no direct insert, update, or delete
privileges on either table. Trusted RPCs are the only write path.

## UI

The existing Costs module gains an internal Approved invoices / Cash expenses
switch for owners. Managers land directly on Cash expenses and never invoke the
owner-only approved-invoice reporting RPC. Employees do not receive cash-expense
access.

The service-day view shows draft and confirmed individual captured totals, the
capture form, deliberate confirmation, audited correction, and readable event
history. It does not show a Revenue discrepancy, reconciliation state,
"balanced", "matched", or accounting correctness.

## M4B2 boundary

Future M4B2 may compare two independent sources for the same location and
service day:

1. the authoritative M1 daily aggregate; and
2. the sum of confirmed M4B1 entries.

No tolerance, adjustment, acknowledgment, close-day, missing-receipt, or
write-off rule is defined in M4B1.

## Explicitly excluded

- reconciliation or modification of Revenue;
- invoice/receipt links or uploads;
- Storage changes;
- paid/unpaid and payment reconciliation;
- supplier master data, categories, line items, OCR, exchange rates;
- VAT reporting or accountant exports;
- closing checklist, FANY, M5/M6, payroll;
- offline mutation queues and hard deletes.
