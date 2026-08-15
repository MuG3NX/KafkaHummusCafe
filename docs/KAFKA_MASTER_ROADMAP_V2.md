# KAFKA OS — Master Roadmap v2

## Purpose

KAFKA OS is the owner-controlled operating system for the real Kafka Hummus Café in Prague. It is not being designed as generic SaaS first. The product should fit the restaurant's real workflows extremely well while keeping clean enough restaurant/location/role boundaries that a future different concept can reuse the architecture.

Long term, KAFKA OS may grow all the way into POS/KDS/payments and public website control. That ambition does not authorize skipping the current financial, operational, audit and service-day foundations.

GitHub remains the implementation source of truth. Each implementation slice still needs its own scoped Issue, focused branch, migration/RLS/tests where applicable, draft PR and architecture review.

## Product principles

1. Real restaurant workflow before generic software theory.
2. One modular restaurant platform, not disconnected apps.
3. One central Postgres/auth/role model.
4. Explicit service day is the operating spine.
5. Exact integer money and append-only financial audit.
6. Human-approved documents are accounting evidence; OCR is never truth by itself.
7. Mobile-first, calm, one-handed operating UI.
8. Exception-first owner visibility beats large generic dashboards.
9. Do not add permanent top-level navigation for every new capability.
10. Do not build inventory, AI, POS or other large surfaces until the restaurant has a real reason to use them.
11. Reservations are the deliberate near-term guest-facing exception because the current website booking flow is operationally unreliable.

---

# Current state

## M1 — Revenue / Daily financial input

**Production: accepted and frozen except genuine bugs.**

Current durable capabilities include restaurant/location/membership, 05:00 Europe/Prague business-day cutoff, exact money, revenue submission, immutable normal-user submission, owner correction with reason/revision, history and RLS.

Current accepted M1 fields remain unchanged for now. The richer real closing workflow is handled later in M4C rather than reopening M1 casually.

## M2A — Shifts & hours

**Production: deployed. Acceptance pending Issue #8.**

One genuine assigned employee must perform a real Start → End shift from their own phone. M2 remains frozen except genuine bugs until that acceptance.

## M3A — Invoice capture foundation

**Production: deployed. Acceptance pending Issue #10.**

Private originals, versioned extraction/manual drafts, explicit human review, exact approved-draft pointer, append-only audit and safe upload recovery exist. One legitimate real invoice still needs to complete the owner acceptance workflow.

## M4A — Approved Invoice Cost Register

**Production: deployed. Acceptance pending Issue #13.**

Owner-only, CZK-only operational cost register derived from exact human-approved invoice snapshots. It is not an accounting or VAT return.

## M4B1 — Cash Expense Evidence Ledger

**Implementation: architecture-approved in PR #18 at exact head `868d12528b9dff9e492edd6ed7a5c2152b77ddcb`. Production rollout pending.**

Individual cash/register movements can be captured as draft evidence, confirmed, audited, corrected and re-confirmed by owner or assigned manager. The authoritative M1 daily aggregate remains independent and untouched.

## W0 — Public website takeover

**Urgent parallel infrastructure track: Issue #20.**

Owner-side Webglobe access to `kafkahummus.cafe` is confirmed. Domain registration is active through 2027-05-05 and DNS is currently served by Webglobe nameservers. The initial takeover keeps registrar and DNS authority at Webglobe, builds and accepts the owner-controlled replacement first, then changes only the required apex/`www` DNS records with rollback values documented. No DNS change is authorized merely by this roadmap.

## W0R — Reservations

**Launch-critical website product slice: Issue #23. V1 policy is fully locked.**

A valid public reservation submission auto-confirms in V1. The durable database record is authoritative; email is notification. Booking window is 09:00–17:00, every 30 minutes, with at least 1 hour same-day lead time. Online auto-confirmation supports parties up to 6; larger groups are directed to contact the restaurant. Guest confirmation and later change/cancellation emails are part of V1.

---

# Locked real workflows

## Ownership / access

Alessandro and Mohammed are both owners. Mohammed may see the full KAFKA financial and operational system. Do not invent a restricted kitchen-owner role.

Narrow employee/manager capabilities remain appropriate for specific workflows.

## Closing today

Trusted current closers are Sofiya, Dima and Danya, but application authorization must not hard-code their identities. Use a narrow capability such as `can_close_day`; owners can always use trusted owner paths.

At the end of the day the closer writes a paper close containing:

- total revenue;
- card;
- cash;
- cash-register expenses;
- EUR;
- USD;
- GBP;
- physical cash actually handed to the owner after register expenses, including physical CZK/EUR/USD/GBP.

A photo is sent to Alessandro through Telegram and then manually copied into Excel.

**Important invariant:** the physical handover values remain explicitly entered/count facts. Even if the system can later calculate an expected reference from cash/expenses/currency rates, that calculation must not silently become authoritative because operational FX practice can change.

## Cash-register expenses

Real examples include emergency supermarket purchases, flowers, pita, cleaner, occasional labor paid from the register, and cash-paid supplier invoices. The daily close aggregate may therefore contain both documented and undocumented movements.

A later cash-expense record may link to an approved invoice as explanatory evidence. Linking must not create a second expense or double count the same payment.

## Labor

Non-owner staff are paid hourly. Alessandro and Mohammed are owners and may take owner extras/draws, but those should not be represented as employee hourly wages.

Near-term labor product value is:

`accepted shift hours × effective hourly rate history = estimated wage`

This is operational wage calculation, not payroll/tax processing.

## Purchasing / FANY

There are roughly six regular suppliers. FANY is the important structured workflow and uses its e-shop.

The exact current workflow is:

1. Mohammed checks kitchen/stock himself.
2. Mohammed decides both products and quantities for the next FANY order.
3. Mohammed writes the FANY order to the bar/management side.
4. Bar/management places that order through the FANY e-shop.

M5A digitizes this exact FANY order sheet + placement/history workflow. It is not a generic `needs ordering` board and should not force bar staff to decide quantities Mohammed already decided.

Other suppliers may be old-school phone/friend relationships handled directly by Mohammed without advance reporting to Alessandro. Do not force them into M5A. Their first reliable digital trace may simply be the invoice/receipt when it arrives.

## Inventory

Full inventory is not currently a meaningful owner pain point. The owners are physically present, stock/preparation moves through their hands, theft is not a major concern and margins remain healthy.

Therefore **FANY ordering before inventory**. Inventory/par/waste moves forward only if ordering/costing needs make it genuinely useful.

## Accountant

Accounting workflow uses POHODA. The owner currently sends invoices, VAT material and bank statements. Future exports/integration should target the real POHODA workflow rather than generic accounting abstraction.

## Public website

The trusted designer owns the Figma design source and can provide desktop/mobile frames, assets and typography information.

The owner controls the Webglobe domain/DNS account. The replacement public site should be implemented from the trusted Figma source with independent hosting/deployment from KAFKA OS. Later, KAFKA OS may deliberately publish safe public menu/opening-hour content, while financial/employee/private records remain completely outside the public boundary.

## Reservations — V1

Reservations are launch-critical alongside the website rebuild.

V1 rules:

- valid public submission is automatically confirmed;
- required: name, email, phone, date, time, party size;
- optional note;
- booking times from 09:00 through 17:00 inclusive;
- slots every 30 minutes;
- same-day bookings require at least 1 hour lead time;
- no simultaneous-capacity or table-allocation engine in V1;
- parties up to 6 auto-confirm online;
- parties over 6 are directed to contact the restaurant;
- every authenticated KAFKA staff member may read reservations;
- owners and users with narrow `can_manage_reservations` capability may change/cancel;
- guest receives confirmation email after durable booking;
- guest receives update/cancellation email when staff changes/cancels the booking;
- owner receives an initial new-booking email notification;
- database is authoritative; email is notification;
- no guest account, deposit, waitlist, CRM or table optimizer in V1.

Reservation clock time uses Europe/Prague restaurant-local time and is not the financial 05:00 service-day accounting rule.

---

# Execution roadmap

## W0 + W0R — Website takeover + Reservations — urgent parallel track

Issues: #20 and #23

### Goal

Take full owner control of the public site while keeping the now-owner-controlled Webglobe domain/DNS stable, reproduce the trusted Figma design with maintainable GitHub hosting, and replace the unreliable reservation flow with owner-controlled durable bookings and email.

### First slice

1. Keep current Webglobe domain and nameservers unchanged.
2. Inventory/export the complete DNS zone and existing hosting targets; document rollback values.
3. Preserve current public pages/content/legal/menu/SEO/redirect/reservation evidence.
4. Obtain Figma desktop/mobile frames + assets + typography information.
5. Build the replacement public site in its own deploy root without refactoring KAFKA OS.
6. Implement the narrow reservation server path and internal staff list from Issue #23.
7. Verify real guest confirmation/update/cancellation email and owner notification.
8. Preview/visual acceptance by owner + designer.
9. Only then update required Webglobe apex/`www` DNS records.
10. Verify HTTPS, apex/`www`, Czech/English routes, menus, legal links, reservation flow, email, SEO/redirects.
11. Stabilize with documented rollback values.
12. Cancel obsolete agency hosting only after stable cutover and dependency audit.
13. Later map `app.kafkahummus.cafe` to KAFKA OS if useful.

### Later website integration

Allow deliberately public data such as menu item name/description/price, availability and opening/holiday hours to publish from KAFKA OS.

### Excluded now

Guest accounts, online ordering, loyalty, payments, public CRM/marketing automation, complex CMS, table allocation, reservation marketplace and POS.

---

## M4B1 — Production rollout

### Goal

Ship the architecture-approved Cash Expense Evidence Ledger without changing its model.

### Sequence

1. Production migration preflight.
2. Apply only the reviewed M4B1 migration before frontend merge.
3. Verify RLS/RPC/non-interference.
4. Merge exact approved PR #18 head.
5. Verify Vercel Production.
6. One legitimate owner/manager cash-expense capture → confirm → optional genuine correction only if needed.
7. Keep Issue #17 open until persisted production evidence passes.

---

## M4B2 — Daily cash-expense reconciliation

Compare two independent truths for one location/service day: the M1 `cash_register_expenses_czk_minor` aggregate and the sum of confirmed M4B1 evidence. A mismatch is non-blocking initially: add/correct evidence, revise the audited daily aggregate when it is wrong, or acknowledge a residual difference with reason. Do not silently rewrite either source.

A later cash-expense→approved-invoice link may explain a payment, but must not create another expense or double-count it.

---

## M4C — Digital closing + Service Day operating hub

Replace paper → Telegram photo → owner Excel entry with one trusted close in KAFKA OS.

Closing data includes total/card/cash/register expenses, EUR/USD/GBP, physical CZK/EUR/USD/GBP handed over, closing note, closer identity and DB close timestamp. Physical handover remains explicit entered/count truth.

Authorization: owners have trusted close/correction authority; non-owner closers receive `can_close_day`; identities are not hard-coded.

The Service Day home should evolve toward an exception-first operating dashboard showing Revenue, working team, cash expenses, invoice review, reservations, closing readiness, FANY order state and follow-ups. Add a small manager handoff log, not a generic chat system.

---

## M2B — Labor rates + wages

Use effective-dated hourly rates. Accepted closed shifts × applicable rate produce estimated monthly wages. Exclude taxes/payroll/payslips and owner draws.

---

## M5A — FANY Order Draft + history

Digitize the real Mohammed→bar/management FANY workflow. Mohammed decides items and quantities; KAFKA stores the next FANY order sheet, actor/time history and ordered history; bar/management places it through the existing e-shop. Other phone/friend suppliers remain outside M5A for now.

---

## M5B — Supplier/product/purchase/receiving foundation

Only after M5A proves useful. Potential stable identities: supplier, product, supplier SKU/pack unit, purchase order, received quantities and price history. Future useful comparison: `ordered → received → invoiced`.

---

## M3B — Invoice inbox / emailed document intake

Add camera/manual PDF/owner-controlled email intake into the existing M3 original-document + draft + human-approval truth model. Do not create a second invoice model.

---

## M6A — POHODA/accountant package

Design around the accountant's real POHODA process. Potential package: approved invoice register/originals, revenue period summary, VAT-supporting approved values, correction evidence where needed, and bank-statement handoff. Verify official POHODA import requirements before choosing CSV/XML/API.

---

# High-value later capabilities

Supplier price history; recipe/menu costing once product identity is trustworthy; visual scheduling after shifts/wages; inventory/par/waste only when it becomes a real problem; public menu/opening-hour publishing from KAFKA OS after website stabilization; much later POS/KDS/payments/table management using the same core identities.

---

# External product inspiration

Learn patterns without inheriting scope: Restaurant365 for connected restaurant data, MarginEdge for invoice→cost insight, 7shifts for manager log/handoff, URY for eventual platform breadth and its ERP-scope warning, Grocy for later fast mobile stock interactions.

---

# Operations / engineering roadmap

- Protect `main` with PR + required CI before the repository becomes more operationally critical.
- Move toward `Vercel Preview → staging Supabase` and `Vercel Production → production Supabase`.
- Build a repeatable production migration workflow where DB migration/verification precedes frontend deployment.
- Resolve backup/PITR Issue #15.

---

# Current priority order

1. **W0 website takeover + W0R reservations** stay prominent but parked until the owner explicitly resumes the public-site build; no DNS changes before preview acceptance.
2. **M4B1 production rollout** when secure Supabase production access is available.
3. Close real acceptance gates #8/#10/#13 opportunistically.
4. **M4B2 cash-expense comparison/acknowledgment.**
5. **M4C digital closing + Service Day owner hub.**
6. **M2B labor hours/wages.**
7. **M5A FANY order sheet/history.**
8. **M5B supplier/product/order/receiving** only if real usage justifies it.
9. **M3B invoice inbox / emailed PDF intake.**
10. **M6A POHODA/accountant package.**
11. Supplier price history + recipe/menu costing.
12. Scheduling.
13. Inventory/par/waste only when it becomes a real problem.
14. Public menu/opening-hour publishing from KAFKA OS.
15. Much later POS/KDS/payments/table stack.

---

# Anti-drift rule

A roadmap item is not implementation authorization by itself. Every new code slice still needs exact GitHub verification, scoped Issue, focused branch, migration/RLS/tests where applicable, CI + preview, architecture review, controlled rollout and real workflow acceptance.
