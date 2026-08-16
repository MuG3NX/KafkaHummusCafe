# M4C — Digital Closing and Service Day Hub

## Status

M4B1 Cash Expense Evidence and M4B2 reconciliation are production-deployed, with genuine workflow acceptance still open in Issues #17 and #24. M4C is the active implementation in Issue #25 / PR #33.

**Architecture approved at exact semantic head `198b62431d67af2ebdb7193516a494c6c93cf6e8`.**

Validation at that head:

- typecheck: pass;
- lint: pass;
- client tests: 59/59;
- production build: pass;
- clean Supabase migration reset: pass;
- pgTAP/RLS: 381/381;
- Vercel Preview: success.

No production M4C migration had been applied at the time of this architecture approval. Any later semantic application/database change reopens delta review. A filename-only migration reconciliation required to match Supabase MCP production history does not reopen semantic architecture if the SQL blob remains byte-identical.

## Objective

Replace the real KAFKA paper → Telegram photo → owner Excel closing workflow with one auditable digital close tied to the explicit restaurant service day.

M4C also begins the shift from separate module screens toward a useful Service Day / Today operating home. It does not create a generic dashboard or checklist engine.

## Revenue truth remains M1

M4C does **not** create a second mutable copy of fields already owned by `revenue_entries`.

The close displays and binds to the exact current M1 Revenue row + version for:

- total revenue CZK;
- card CZK;
- cash CZK;
- cash-register expenses CZK;
- EUR counted;
- physical CZK handed to the owner.

If those values are wrong, use the existing audited M1 owner correction path.

A completed close stores the exact Revenue id/version it reviewed. If Revenue is corrected later, the old close remains historic evidence and the read model marks its Revenue binding stale until an owner explicitly reviews/rebinds it through the audited M4C correction path.

## Closing-only evidence

The real paper workflow contains foreign-currency facts not currently represented by M1. M4C adds only those new facts:

- USD counted;
- GBP counted;
- physical EUR handed over;
- physical USD handed over;
- physical GBP handed over;
- optional closing note;
- authenticated closer;
- DB close timestamp.

Physical CZK is not duplicated because M1 already owns it.

All currencies are exact integer minor units. No exchange-rate calculation becomes authoritative and no historic close is recalculated when operational FX practice changes.

## Capability

`membership_location_assignments.can_close_day` is the narrow operational capability.

- owner: always authorized for owned restaurant locations;
- non-owner: explicit location assignment + `can_close_day=true`;
- role/name alone does not grant close authority;
- Sofiya/Dima/Danya are not hard-coded.

The DB helper `can_close_service_day(location_id)` is the authority boundary.

## Lifecycle

There is no persisted editable closing Draft row.

1. UI loads current Service Day readiness.
2. Revenue must exist before final close.
3. Closer reviews M1 Revenue values and non-blocking warnings.
4. Closer enters M4C-only currency/handover fields + optional note.
5. UI shows deliberate review state.
6. `close_service_day(...)` atomically verifies capability, date, exact Revenue id/version and payload.
7. One completed close is created for the location/business date.
8. Normal closer cannot directly update/delete completed evidence.
9. Owner correction/rebind requires exact closure version, exact current Revenue snapshot and mandatory reason; previous closure evidence is appended to revision history.

A client-generated closure UUID is retained across ambiguous retry. Exact same UUID/payload/actor returns the existing completed close rather than creating a duplicate. Conflicting UUID reuse is rejected.

## Date rules

- future service days are always rejected;
- non-owner operational closer may close only the DB-resolved current service day;
- owner may perform deliberate historical recovery/close where Revenue exists;
- 05:00 Europe/Prague service-day identity remains the existing DB source of truth.

## Cash-expense reconciliation snapshot

At close, M4C records a historical snapshot of the current M4B2 state:

- confirmed M4B1 cash-expense total;
- deterministic confirmed-evidence fingerprint;
- signed cash-expense difference;
- current acknowledgment id when one exists.

This is historical closing evidence, not a new current cash-expense truth.

A non-zero or unacknowledged difference is a warning, not an automatic hard block.

## Readiness warnings

The Service Day read model surfaces:

- M1 Revenue presence/current values;
- current M4B2 confirmed total/difference/acknowledgment;
- Draft cash-expense count;
- open shift count;
- invoices in `needs_review` for the location;
- handoff note count/latest note;
- closed state and Revenue-binding current/stale state.

V1 blocking prerequisite:

- no Revenue → cannot finalize close.

V1 warnings only:

- cash-expense mismatch;
- Draft cash evidence;
- open shifts;
- invoices needing review;
- handoff notes/follow-ups.

M4C never auto-balances, auto-closes shifts, approves invoices or changes other modules from the readiness screen.

## Manager handoff notes

Handoff notes are intentionally tiny and append-only/auditable rather than a chat/task product.

An owner or `can_close_day` operator may add a note for an authorized service day, such as:

- maintenance problem;
- supplier issue;
- staff issue;
- guest/operational note;
- action for tomorrow.

Notes use client-generated UUID retry identity, DB actor/time and no normal edit/delete path.

## Owner correction / rebind

Only owner may correct completed M4C evidence.

Correction:

- requires exact expected closure version;
- requires exact current Revenue id/version;
- requires a non-empty reason;
- appends previous closure values to `service_day_closure_revisions`;
- increments close version;
- updates only M4C-owned evidence fields;
- refreshes the M4B2 snapshot;
- rebinds the close to the exact current M1 Revenue version;
- preserves original `closed_by` and `closed_at`.

M4C does not create a second Revenue correction mechanism.

## UI direction

Do not add a permanent fifth global module.

The Revenue/Today area gains an isolated closing panel that can render only for owner/`can_close_day` users.

V1 flow:

1. readiness card showing M1 values + warnings;
2. small manager-handoff note surface;
3. M4C foreign-currency/handover form;
4. deliberate review;
5. Close Day;
6. completed closing evidence;
7. owner-only audited correction/rebind.

The existing Revenue submission/history logic remains otherwise frozen.

## Retry / offline behavior

No fake offline success.

- close requires live connection;
- one closure UUID + exact Revenue version/payload is retained across ambiguous retry;
- authoritative reload recognizes a previously committed same UUID as success;
- handoff notes use the same client-UUID retry approach;
- owner correction uses stale-version protection and reload-before-retry after an uncertain response;
- no offline mutation queue.

## Security / RLS

New exposed tables use RLS.

Authenticated clients receive SELECT only through capability-scoped policies.
Direct INSERT/UPDATE/DELETE is denied; trusted RPCs are the write path.
Anonymous/public function execution is revoked.
Security-definer functions pin `search_path=public`.
The internal cash-reconciliation snapshot helper is not executable by authenticated clients.

## Explicitly excluded

- automatic FX accounting;
- auto-balancing cash;
- full checklist/task engine;
- payroll;
- supplier ordering implementation;
- inventory;
- POHODA export;
- POS/KDS;
- customer CRM;
- paper-photo attachment unless later explicitly justified;
- broad global navigation redesign.

## Production acceptance

No fake production close.

Issue #25 closes only after one genuine trusted closer uses M4C for a real service day and the owner verifies that the resulting digital evidence correctly replaces the paper → Telegram → Excel handoff.