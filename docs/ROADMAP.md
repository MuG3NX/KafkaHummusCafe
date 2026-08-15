# Roadmap

The controlling long-range product map is now
[`KAFKA_MASTER_ROADMAP_V2.md`](KAFKA_MASTER_ROADMAP_V2.md), tracked by Issue #21.
This file remains the compact milestone index.

## Current state

- **M1 Revenue:** production-deployed, accepted, frozen except genuine bugs.
- **M2A Shifts:** production-deployed; one genuine employee Start → End acceptance remains open in Issue #8.
- **M3A Invoice Capture:** production-deployed; legitimate real-invoice acceptance remains open in Issue #10.
- **M4A Approved Invoice Costs:** production-deployed; owner acceptance remains open in Issue #13.
- **M4B1 Cash Expense Evidence Ledger:** architecture-approved in draft PR #18 at exact head `868d12528b9dff9e492edd6ed7a5c2152b77ddcb`; production rollout pending.
- **W0 Public Website Takeover:** urgent parallel infrastructure track in Issue #20.
- **M4B2 and later:** not implemented.

## Current priority order

1. W0 website takeover in parallel: recover domain authority and build the owner-controlled public site from the trusted Figma design.
2. M4B1 controlled production rollout when secure Supabase production access is available.
3. Close Issues #8/#10/#13 opportunistically with genuine workflows.
4. M4B2 daily cash-expense comparison / acknowledgment.
5. M4C digital closing + Service Day owner/manager operating hub.
6. M2B effective hourly rates + monthly hours/wage estimation/export.
7. M5A FANY order draft/history preserving Mohammed's real quantity-deciding workflow.
8. M5B supplier/product/order/receiving only where actual usage justifies it.
9. M3B invoice inbox / emailed PDF intake improvements.
10. M6A POHODA/accountant export package.
11. Supplier price history and recipe/menu costing once approved product/invoice identity is trustworthy.
12. Scheduling.
13. Inventory/par/waste only when it becomes a real operating problem.
14. Public menu/opening-hours publishing from KAFKA OS after website takeover is stable.
15. Much later native POS/KDS/payments/table stack.

## M0 — Foundation + Touchable Preview

Established the repository contract, phone-first visual direction and initial PWA foundation.

## M1 — Revenue

Production source of truth for service-day revenue with exact money, 05:00 Europe/Prague cutoff, RLS, immutable normal submissions and owner audited corrections.

## M2 — Team

### M2A Shifts
Employee own-phone Start/End, owner corrections, explicit service-day identity and hour totals.

### M2B Labor & Wages
Future effective-dated hourly rates and operational monthly wage estimation from accepted closed shifts. No payroll/tax engine.

### Later Scheduling
Visual schedule only after shifts/wages are accepted and the workflow can remain simple.

## M3 — Documents / Invoices

### M3A Invoice Capture
Private originals, extraction/manual drafts, human approval and append-only audit.

### M3B Invoice Inbox
Later emailed PDF/forwarding intake feeding the same M3 document truth model.

## M4 — Costs + Closing

### M4A Approved Invoice Costs
Owner-only CZK operational reporting from exact approved invoice snapshots.

### M4B1 Cash Expense Evidence
Individual owner/assigned-manager cash/register-movement evidence; independent of the authoritative M1 daily aggregate.

### M4B2 Cash Expense Reconciliation
Compare the M1 daily aggregate with confirmed M4B1 evidence. Initial mismatches should support review/revision/acknowledgment rather than silent balancing.

### M4C Digital Closing / Service Day Hub
Replace paper → Telegram photo → owner Excel with one audited digital close. The physical cash handed over remains a human-counted fact. Evolve the UX toward a service-day dashboard and small manager handoff log instead of endlessly adding top-level tabs.

## M5 — Purchasing

### M5A FANY Order Draft
Mohammed decides items and quantities. KAFKA records the next FANY order draft, actor/time history and ordered history; an owner/manager still places it through the existing FANY e-shop.

### M5B Supplier / Purchase / Receiving Foundation
Only after M5A proves useful: canonical supplier/product identity, purchase orders, receiving and later ordered → received → invoiced comparison.

Full inventory is deliberately deferred.

## M6 — Accountant / Reporting

### M6A POHODA Package
Design exports/integration around the accountant's real POHODA workflow: approved invoices/originals, revenue/VAT-supporting evidence and bank-statement handoff. No official-accounting correctness claim until accountant acceptance.

### Later Owner Insights
Supplier price history, recipe/menu costing and exception-first operating summaries once the underlying data is reliable.

## W0 — Public Website Ownership

Issue #20. Recover registrar/DNS ownership, reproduce the trusted Figma website under GitHub/owner-controlled hosting, then later allow deliberately public menu/opening-hour data to publish from KAFKA OS. Public website and private back office remain separate deployment/security boundaries.

## Much later

Inventory/par/waste, deeper scheduling/HR, public customer features and eventually native POS/KDS/payments/table management only after the back-office platform is proven.
