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
- **W0 Public Website Takeover:** owner Webglobe/domain/DNS access confirmed in Issue #20; build parked until owner explicitly resumes it.
- **W0R Reservations:** V1 workflow fully locked in Issue #23; launch-critical with the rebuilt public website.
- **M4B2 and later:** not implemented.

## Current priority order

1. W0 website + reservations stay prominent but parked until the owner explicitly resumes the public-site build; no DNS change before preview acceptance.
2. M4B1 controlled production rollout when secure Supabase production access is available.
3. Close Issues #8/#10/#13 opportunistically with genuine workflows.
4. M4B2 daily cash-expense comparison / acknowledgment.
5. M4C digital closing + Service Day owner/manager operating hub.
6. M2B effective hourly rates + monthly hours/wage estimation/export.
7. M5A FANY order sheet/history preserving Mohammed's real quantity-deciding workflow.
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
Future effective-dated hourly rates and operational monthly wage estimation from accepted closed shifts. No payroll/tax engine and no owner draws in employee wage rows.
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
Compare the M1 daily aggregate with confirmed M4B1 evidence. Initial mismatches support review/revision/acknowledgment rather than silent balancing or hard-blocking the close. A later invoice link may explain a cash expense without creating a duplicate cost.
### M4C Digital Closing / Service Day Hub
Replace paper → Telegram photo → owner Excel with one audited digital close. Physical CZK/EUR/USD/GBP handover remains explicit entered/count truth, not an automatically derived authority. Trusted closers use a capability such as `can_close_day`; identities are not hard-coded. Evolve the UX toward a service-day dashboard and small manager handoff log instead of endlessly adding top-level tabs.

## M5 — Purchasing
### M5A FANY Order Draft
FANY is the structured purchasing workflow. Mohammed checks the kitchen and decides both items and quantities; KAFKA records that FANY order sheet, actor/time history and ordered history; bar/management still places it through the existing FANY e-shop. Other phone/friend suppliers are not forced into M5A.
### M5B Supplier / Purchase / Receiving Foundation
Only after M5A proves useful: canonical supplier/product identity, purchase orders, receiving and later ordered → received → invoiced comparison.
Full inventory is deliberately deferred.

## M6 — Accountant / Reporting
### M6A POHODA Package
Design exports/integration around the accountant's real POHODA workflow: approved invoices/originals, revenue/VAT-supporting evidence and bank-statement handoff. No official-accounting correctness claim until accountant acceptance.
### Later Owner Insights
Supplier price history, recipe/menu costing and exception-first operating summaries once the underlying data is reliable.

## W0 — Public Website Ownership
Issue #20. Owner-side Webglobe access is confirmed; keep registration/DNS there initially, inventory current records, reproduce the trusted Figma website under GitHub/owner-controlled hosting, and change only required apex/`www` DNS after preview acceptance. No unnecessary registrar/nameserver migration.

## W0R — Reservations
Issue #23. V1 public bookings auto-confirm durably. Required fields: name, email, phone, date, time, party size; note optional. Slots run 09:00–17:00 every 30 minutes with at least 1 hour same-day lead time. Parties up to 6 auto-confirm online; larger parties contact the restaurant. All authenticated staff can read; owner/`can_manage_reservations` can change/cancel. Guest receives confirmation and later change/cancellation emails; owner receives new-booking notification. Database is authoritative; email is notification.

## Much later
Inventory/par/waste, deeper scheduling/HR, public customer features beyond reservations, and eventually native POS/KDS/payments/table management only after the back-office platform is proven.
