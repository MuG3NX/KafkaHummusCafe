# M3 — Invoice Capture / OCR Foundation

## Status

M2 remains the production acceptance gate until the first genuine employee
Start → End shift test is complete. This M3 branch is parallel foundation work;
it must not change M2 behavior, production data, or deployment configuration.

## Objective

Give the restaurant a durable mobile-first path to capture an invoice original,
hold extracted fields as an untrusted draft, and let an authorized human review
and approve the draft. The original document remains the evidence. No draft is
accounting truth until approval.

## First-slice boundaries

Included:

- mobile camera/file upload for invoice originals;
- private Supabase Storage for the original image or PDF;
- an invoice record tied to restaurant and location;
- lifecycle status for uploading, reviewable, approved, rejected, and terminal
  abandoned records;
- a versioned extracted-data draft containing supplier, invoice number, issue
  date, due date, currency, net, VAT, gross, and confidence/validation metadata;
- explicit human review and approval;
- append-only audit records for approval, rejection, and corrections;
- an internal OCR/extraction adapter boundary with a deterministic no-provider
  foundation path.

Excluded from this slice:

- supplier or cost reporting;
- VAT reporting or accounting exports;
- paid/unpaid workflow or payment reconciliation;
- choosing or deeply integrating an OCR vendor;
- automatic accounting decisions;
- offline upload queues;
- employee onboarding and every M2/M4/M5/M6 feature.

## Data and storage rules

The private Storage bucket contains the immutable original object. The database
stores its bucket/path and metadata, but never treats a client-provided filename
or extracted value as authoritative. Normal app paths do not overwrite or
hard-delete original objects.

The upload policy binds an object to the exact `uploading` invoice record,
uploader, path, MIME type, and byte size. The completion RPC refuses to advance
the record unless that exact private object exists. A failed pre-completion
upload remains recoverable online: the user can retry completion when the
object exists, or abandon it with a distinct audit event. Abandonment is
terminal; retrying after abandonment starts a new upload and does not delete
the original object.

Invoice draft money is stored as integer minor units with an explicit currency.
The browser may format values for display, but must not use JavaScript floating
point as the stored or authorization value.

The invoice record owns the lifecycle. A draft is versioned; an approval or
correction creates an append-only audit event and advances the live version.
Approval is an owner-authorized transition and is the only point at which a
future costs/reporting module may consume the extracted fields.

## Authorization

- RLS is enabled on every exposed invoice table.
- A user may create and read invoice records for locations they can access.
- Original Storage objects are readable only through authorized location access.
- Owners may approve, reject, and correct records for their locations.
- Employees may capture and read their location's invoices, while manual field
  editing and approval are owner-only.
- Direct client mutation of approved financial meaning is denied; privileged
  transitions use database-side authorization.
- OCR output is untrusted until an owner explicitly approves it.

Approval validates the stored draft fields in the database and records the exact
reviewed extraction version on the invoice row. The caller must submit the
loaded invoice version and draft version; stale approvals are rejected.
Client-provided validation errors are informational only. Corrections clear
that pointer until a new version is approved. The database enforces that an
approved invoice always has a pointer, and every other status has none.

## Adapter boundary

The domain depends on a server-only internal extraction interface, not on a
vendor SDK. The browser sends an invoice identity to a server route; the server
resolves the private original and owns the provider key/source fields. The first
implementation may return an empty or deterministic draft so upload, review,
authorization, and audit behavior can be tested without external OCR. A later
provider adapter must map into the same draft contract and must not gain
permission to approve invoices or write accounting truth.

## Definition of done for the foundation PR

- migration and private Storage policies are committed;
- executable database tests cover location permissions, private originals,
  draft visibility, owner approval/correction, audit append-only behavior, and
  direct mutation denial;
- the mobile UI can upload an original, show its review state, display/edit a
  draft, and submit owner approval without pretending OCR is complete;
- adapter and money parsing tests pass;
- full typecheck, lint, client tests, production build, migration reset, and
  pgTAP CI pass;
- PR remains draft and unmerged for architecture review.
