# Roadmap

## Current state — M4A deployed, acceptance pending

M1 Revenue is production-deployed, accepted, and frozen except for genuine
bugs. M2 is merged and deployed with one genuine employee acceptance test still
pending in Issue #8. M3 and its upload maintenance fix are merged and deployed,
with real invoice acceptance still pending in Issue #10. M4A is
architecture-approved, merged, and deployed, with real owner acceptance still
pending in Issue #13. The restaurant workflow decisions are resolved and M4B1
Cash Expense Evidence Ledger is the active authorized draft implementation in
Issue #17. M4B2 daily cash-expense reconciliation remains later and
unimplemented. See [`M4B_CASH_EXPENSES.md`](M4B_CASH_EXPENSES.md).

## M0 — Foundation + Touchable Preview
Goal: establish the repository contract and a phone-first visual slice immediately.
- PWA shell and manifest
- mobile Today screen
- revenue form UI using the real fields
- preview-only browser persistence allowed, visibly marked as preview
- architecture/product docs

## M1 — Revenue Tracker (first production slice)
- Supabase project and versioned migrations
- login/session handling
- restaurant/location/membership model
- service day
- revenue submission
- role/capability enforcement via RLS
- submitted record lock for normal users
- owner correction flow with reason + audit revision
- history and basic owner summary
- production deployment + install on iPhone/Android

## M2 — Shifts
- employee accounts
- start/end shift and manual owner correction
- service-day association across midnight
- employee self-history; owner aggregate view
- weekly/monthly totals

## M3 — Invoice Capture / OCR
- camera/upload
- private original document storage
- OCR/extraction adapter
- supplier/invoice/date/net/VAT/gross extraction
- confidence/validation UI
- human review + approval
- append-only corrections/audit

## M4 — Costs + Closing
- M4A: approved invoice costs into operational monthly reporting
- M4B1: individual cash-expense internal evidence ledger
- M4B2: compare confirmed M4B1 expenses with the authoritative M1 daily cash-expense aggregate
- M4C: end-of-shift checklist and missing-item visibility

## M5 — Supplier Ordering / FANY
- canonical suppliers/products
- usual-order templates
- quantity-first mobile order sheet
- reminder workflow
- FANY connector only after internal order model is stable

## M6 — Reporting / VAT support
- revenue/cost/labour dashboards
- VAT inputs/outputs based on approved data
- exports/integration aligned with Czech accountant requirements
- do not claim official accounting correctness without validation

## Later
Paid/unpaid workflow, inventory, scheduling, product price history, deeper
analytics, accounting connectors, hardware/POS integrations, then potentially
native POS capabilities.
