# M4A — Approved Invoice Cost Register

## Status

M4A is the active parallel draft implementation. M2 remains open only for one
genuine employee Start → End acceptance test. M3 is merged and deployed, while
its production acceptance remains open until Issue #10 and the parked upload
maintenance PR #12 are completed. M4A must not change those modules or deploy
before review.

## Objective

Give the owner a calm mobile monthly register of costs derived only from
human-approved invoice data. This is an operational view, not an accounting or
VAT return.

## Included

- owner-only Costs module;
- month selector;
- approved invoice count;
- net, VAT, and gross totals grouped separately by currency;
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
- CZK and EUR totals remain independent. M4A performs no exchange-rate
  conversion and never adds currencies together.
- Money remains Postgres `bigint` internally and crosses the API boundary as
  exact decimal strings.
- The UI states: “Based only on human-approved invoice records. Operational
  view—not an accounting or VAT return.”

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
