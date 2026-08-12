# Architecture

## Shape
Use a modular monolith: one deployable web application, one primary Postgres database, clearly separated product domains. Do not split into microservices at this stage.

```text
KAFKA Platform
├── Core: auth, restaurants, locations, memberships, service days, audit
├── Revenue
├── Shifts
├── Documents / Invoice OCR
├── Finance / Costs
├── Suppliers / Orders
├── Closing
├── Reporting
└── Integrations: OCR, FANY, notifications, future POS/accounting
```

## Frontend
- Next.js App Router + TypeScript.
- PWA installable from iOS/Android home screen.
- Mobile-first responsive layout.
- Server/client boundaries kept explicit.
- Business calculations belong in domain functions/server/database where appropriate, not duplicated across screens.

## Backend
Supabase is the initial backend platform:
- Postgres as source of structured truth.
- Auth for user identity.
- Storage for invoice originals later.
- RLS on exposed tables.
- SQL migrations under version control.

## Tenancy
Model `restaurants` and `locations` now even with one current restaurant/location. Every operational record must be attributable to the correct location/service day. This avoids a future multi-location rewrite.

## Money
Store monetary amounts as integer minor units (`bigint`). Format only at the UI boundary. Do not store or calculate money using JS floating-point numbers.

## Time
- Store actual instants as `timestamptz`.
- Store location IANA timezone, initially `Europe/Prague`.
- Store service-day `business_date` separately.

## Authorization
Authorization is enforced by Postgres RLS and privileged server/database functions, not only by UI visibility. Initial behavior:
- authorized operators can submit revenue;
- submitted revenue becomes immutable to normal operators;
- owner can correct through a deliberate correction flow;
- corrections require a reason and create append-only revision/audit records;
- deletes of financial records are not part of normal product behavior.

## Documents / OCR later
Keep original invoice image/PDF separately from extracted structured fields. OCR is an integration adapter. Parsed fields carry review state and must be human-approved before they affect official cost/VAT reporting.

## Supplier integrations later
Our internal suppliers/products/orders are canonical. FANY automation is an adapter. A supplier website redesign must require changing only its connector, not the Orders module.

## Reliability
- Migrations are forward-only and reviewed.
- Production secrets live in deployment/Supabase secret stores, never Git.
- Production DB/storage need separate backups; GitHub is not a data backup.
- Add idempotency and conflict handling before any offline financial mutation queue.
