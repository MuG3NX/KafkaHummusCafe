# M4A — Approved Invoice Cost Register

## Status

M4A is architecture-approved, merged, and deployed. Its real owner acceptance
remains open in Issue #13 until one legitimate approved CZK invoice is verified
in the issue-date month with matching net, VAT, and gross values. M2 remains
open only for one genuine employee Start → End acceptance test in Issue #8. M3
and its upload maintenance fix are deployed, while real invoice acceptance
remains open in Issue #10. M4B implementation is not yet authorized.

## Objective

Give the owner a calm mobile monthly CZK register of costs derived only from
human-approved invoice data. This is an operational view, not an accounting or
VAT return.

## Included

- owner-only Costs module;
- month selector;
- approved invoice count;
- one CZK net, VAT, and gross summary;
- approved invoice list with supplier, invoice number, issue date, optional due
  date, net, VAT, and gross;
- authorized link to the private original;
- mobile-first layout with existing safe-area and touch-target rules.

## Authoritative source

Every cost row comes from an `invoice_records` row whose status is `approved`,
joined through `approved_draft_version` to the exact matching
`invoice_extraction_drafts` version. The register never infers accounting truth
from the latest draft, highest version, audit JSON, client state, or unapproved
OCR output.

No second mutable costs table is created. The register is a derived,
owner-authorized database read over the approved invoice snapshot.

## Reporting rules

- `issue_date` places an invoice into a month.
- The selected month is inclusive from its first day and exclusive of the first
  day of the next month.
- M4A is a CZK-only operational cost register. Only human-approved CZK invoice
  snapshots are included. Foreign-currency cost reporting and exchange-rate
  conversion are outside this milestone.
- Money remains Postgres `bigint` internally and crosses the API boundary as
  exact decimal strings.
- The UI states that the register is based only on human-approved CZK invoice
  records and is an operational view, not an accounting or VAT return.

## Correction behavior

Saving a correction to an approved invoice returns it to `needs_review` and
clears `approved_draft_version`. It disappears from the register immediately
and returns only after the exact corrected version is approved again.

## Authorization

- Only a restaurant owner may execute the reporting RPC for an owned location.
- Employees are denied in PostgreSQL even if they attempt the RPC directly.
- Results are scoped to the requested location and cannot cross restaurants.
- The reporting interface has no write path.
- Hiding the Costs module from employee navigation is presentation, not the
  authorization boundary.

## Excluded

- paid/unpaid and payment reconciliation;
- manual costs and cost categories;
- supplier master data;
- cash-register expense linking;
- closing checklist;
- VAT reporting or accountant exports;
- line items;
- OCR provider selection;
- currency conversion;
- FANY ordering;
- M5/M6 work.
