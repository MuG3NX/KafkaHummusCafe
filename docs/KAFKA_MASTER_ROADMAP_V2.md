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

The public `kafkahummus.cafe` website must move under owner control for registrar/DNS/source/hosting. This track is deliberately separate from KAFKA OS production data and can proceed in parallel.

---

# Locked real workflows

## Closing today

Trusted closers are currently Sofiya, Dima and Danya.

At the end of the day they write a paper close containing:

- total revenue;
- card;
- cash;
- cash-register expenses;
- EUR;
- USD;
- GBP;
- physical cash actually handed to the owner after register expenses, including physical CZK/EUR/USD/GBP.

A photo is sent to Alessandro through Telegram and then manually copied into Excel.

**Important invariant:** physical handover is a human-counted fact. It must not become an automatically derived amount merely because the system can calculate an expected number.

## Cash-register expenses

Real examples include:

- emergency supermarket purchases;
- flowers;
- pita;
- cleaner;
- occasional labor paid from the register;
- cash-paid supplier invoices.

The daily close aggregate may therefore contain both documented and undocumented movements.

## Labor

Non-owner staff are paid hourly. Alessandro and Mohammed are owners and may take owner extras/draws, but those should not be represented as employee hourly wages.

Near-term labor product value is:

`accepted shift hours × effective hourly rate history = estimated wage`

This is operational wage calculation, not payroll/tax processing.

## Purchasing / FANY

There are roughly six regular suppliers. FANY is the most important and is ordered through its e-shop.

Mohammed owns the kitchen judgment. He checks stock himself, decides quantities himself and currently writes the FANY order for the team to place. This is not a systematic par/inventory workflow and should not be forced into one yet.

Other suppliers may be old-school phone/friend relationships managed directly by Mohammed. Their first digital integration can simply be the financial document/invoice path; they do not need to enter a generic purchase-order workflow immediately.

## Inventory

Full inventory is not currently a meaningful owner pain point. The owners are physically present, stock/preparation moves through their hands, theft is not a major concern and margins remain healthy.

Therefore:

**supplier ordering before inventory.**

Inventory/par/waste moves forward only if ordering/costing needs make it genuinely useful.

## Accountant

Accounting workflow uses POHODA. The owner currently sends invoices, VAT material and bank statements.

Future exports/integration should target the real POHODA workflow rather than generic accounting abstraction.

## Public website

The trusted designer owns the Figma design source. The owner wants the website under direct control and eventually wants public menu content to be manageable from KAFKA OS.

Public website and internal OS may share deliberately publishable data later, but financial/employee/private records must never become part of the public data boundary.

---

# Execution roadmap

## W0 — Website takeover — urgent parallel track

Issue: #20

### Goal

Take full owner control of registrar/DNS/source/hosting and reproduce the trusted Figma design with a maintainable GitHub/Vercel deployment.

### First slice

1. Recover registrar ownership/access and inventory current DNS.
2. Preserve existing public pages/content/legal/menu/SEO/redirect evidence.
3. Obtain Figma desktop/mobile frames + assets + typography information.
4. Build the replacement public site in its own deploy root without refactoring KAFKA OS.
5. Preview/visual acceptance.
6. DNS/custom-domain cutover with rollback plan.
7. Later map `app.kafkahummus.cafe` to KAFKA OS if useful.

### Later website integration

Allow deliberately public data such as menu item name/description/price, availability and opening/holiday hours to publish from KAFKA OS.

### Excluded now

Guest accounts, online ordering, loyalty, payments, public CRM, complex CMS and POS.

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

### Goal

Compare the two independent truths for one location/service day:

A. `revenue_entries.cash_register_expenses_czk_minor`

B. sum of **confirmed** M4B1 cash-expense evidence.

### Initial product behavior

Show:

- entered closing aggregate;
- confirmed-evidence total;
- exact difference.

A mismatch should initially be non-blocking. The likely workflow is:

- add/correct missing evidence; or
- revise the daily close through the existing audited owner correction path when the aggregate itself is wrong; or
- acknowledge a residual difference with a required reason.

Do not silently rewrite either source.

### Later link

A cash expense may link to an approved supplier invoice as explanatory evidence. The link must not create another cost/expense and must not double count the same payment.

### Excluded

Automatic balancing, tolerance invention, accounting write-offs, payment reconciliation, auto-generated expenses from invoices.

---

## M4C — Digital closing + Service Day operating hub

### Goal

Replace paper → Telegram photo → owner Excel entry with one trusted close in KAFKA OS.

### Closing data

The close should represent the real paper workflow, including:

- total;
- card;
- cash;
- register expenses;
- EUR;
- USD;
- GBP;
- physical CZK handed over;
- physical EUR handed over;
- physical USD handed over;
- physical GBP handed over;
- closing note;
- closer identity;
- DB close timestamp.

Physical handover remains explicitly counted, never inferred.

### Readiness view

Closing should surface, but not necessarily hard-block on:

- Revenue submission;
- M4B2 expense difference;
- open shifts;
- draft cash-expense evidence;
- invoices needing review;
- manager note / follow-up item.

### Service Day home

This is the point where the UX should begin evolving from module tabs into an operating-day dashboard:

- Revenue status;
- team/working-now summary;
- cash-expense state;
- invoice review state;
- closing readiness;
- future ordering state;
- exceptions needing attention.

Do not build a generic BI dashboard. Show the few things the owner/closer needs to act on.

### Manager handoff

A very small manager log belongs naturally here:

- service-day note;
- supplier problem;
- maintenance/problem note;
- staff issue;
- item/action for tomorrow.

Searchable history later; no Slack clone.

---

## M2B — Labor rates + wages

### Goal

Replace monthly labor-hours Excel calculation.

### Model

Use effective-dated hourly rates rather than a mutable single salary field.

Example:

- membership/employee;
- hourly CZK rate;
- valid-from date;
- optional valid-to if useful.

Accepted closed shifts × applicable rate produce monthly estimated wages.

### Owner view

Per employee/month:

- total closed hours;
- applicable rate periods;
- estimated wage;
- corrections reflected automatically from audited shift timestamps.

### Excluded

Taxes, official payroll, payslips, owner draws, benefits, tips unless separately scoped later.

---

## M5A — FANY Order Draft + history

### Goal

Digitize the real Mohammed workflow without inventing full inventory.

### Real workflow

Mohammed decides both product and quantity. Therefore the MVP is not a generic `needs item` queue requiring someone else to decide quantity.

It should behave closer to:

**FANY Order — tonight**

- Tahini × 3
- Chickpeas × 6
- Olive oil × 2

Added/changed by Mohammed.

Then an authorized owner/manager places the order in the existing FANY e-shop and marks the draft ordered.

### Core behavior

- reusable FANY product list / usual items;
- quantity-first mobile entry;
- draft for current next order;
- actor/time history;
- mark ordered with actor/time;
- previous-order history;
- copy previous/usual order as a starting point if it proves useful;
- no automatic submission until a later FANY adapter is deliberately authorized.

### Other suppliers

Do not force Mohammed's phone/friend suppliers into M5A. They can remain handled directly while their receipts/invoices enter the financial document flow.

---

## M5B — Supplier/product/purchase/receiving foundation

Only after M5A proves useful.

Potential stable identities:

- supplier;
- product;
- supplier product/SKU/pack unit;
- purchase order;
- received quantities;
- price history.

Future high-value comparison:

`ordered → received → invoiced`

Do not build this merely because an ERP normally has it. Require real KAFKA value first.

---

## M3B — Invoice inbox / emailed document intake

### Goal

Reduce handling of emailed PDFs and large paper/receipt volume.

Potential inputs:

- mobile camera/photo;
- manual PDF upload;
- owner-controlled invoice email inbox/forwarding;
- later supplier-specific imports if useful.

All routes still feed the same M3 original-document + draft + human-approval model.

Do not create a second invoice truth model.

---

## M6A — POHODA/accountant package

### Goal

Reduce the monthly manual accountant handoff.

First define the exact POHODA/accountant import process using official documentation and the accountant's real requirements.

Potential package:

- approved invoice register;
- original invoice files;
- revenue period summary;
- VAT-supporting approved values;
- correction/audit evidence where needed;
- bank statement attachment/reference;
- CSV/XML/API format only after POHODA requirements are verified.

Do not claim official accounting correctness before accountant acceptance.

---

# High-value later capabilities

## Supplier price history

Approved invoice/product identity should eventually answer questions such as:

- Which supplier increased prices most?
- What did tahini cost 30/60/180 days ago?
- Which regular product changed sharply?

This is more valuable to KAFKA than comprehensive inventory today.

## Recipe/menu costing

Once supplier-product identity and price history are reliable:

recipe/BOM → current ingredient cost → plate cost → margin view.

Do not build recipe costing on guessed/untrusted OCR product lines.

## Scheduling

After shifts and wages are accepted, a visual weekly schedule can replace Excel. Keep it mobile/clear rather than building full HR software.

Possible later staff features: availability/time-off/shift swap only when current scheduling pain justifies them.

## Inventory / pars / waste

Deferred until ordering/costing creates a real reason. When it arrives, prioritize quick counts and key products over theoretical real-time stock precision.

## Public menu publishing

After W0 stabilizes the website, KAFKA OS may own a deliberately public menu/content model and publish prices/opening hours to the public site.

## POS / KDS / payments

Long-term ambition only.

A future native POS should consume the same product/menu/location/service-day identities rather than becoming a separate system. KDS, table management and payments come only after a POS product contract exists.

---

# External product inspiration

The project should learn patterns without inheriting other products' scope.

## Restaurant365

Useful lesson: restaurant finance, inventory, scheduling and operations become more valuable when they share one data model. KAFKA should preserve that connected-platform direction while remaining much smaller and more opinionated for one restaurant first.

## MarginEdge

Useful lessons: phone/email invoice intake, price movers, recipe costing, order management and daily controllable P&L all become possible after document/product identity is trustworthy.

## 7shifts

Useful lesson: a small manager log tied to the operating day/shift can replace scattered notes and improve handoff without creating a full messaging platform.

## URY (open source)

Useful lesson: one restaurant system can eventually cover POS, KDS, purchasing, recipes, opening/closing and P&L. Warning: that breadth is exactly why KAFKA must continue milestone-by-milestone rather than copying ERP scope.

## Grocy (open source)

Useful lesson for a later inventory phase: PWA-first quick counts, camera/barcode workflows and simple list interactions can make otherwise tedious stock entry usable.

---

# Operations / engineering roadmap

## Protect `main`

Current branch protection is not enabled. Before the repository becomes even more operationally critical, require PR + successful CI and prevent accidental direct main pushes.

## Staging Supabase

Move toward:

`Vercel Preview → staging Supabase`

`Vercel Production → production Supabase`

This will make migration/workflow acceptance safer and reduce reliance on production for preview behavior.

## Production migration workflow

Create a repeatable authenticated rollout process where DB migration occurs and is verified before a frontend requiring the schema is merged/deployed.

## Backup/PITR

Resolve Issue #15. As KAFKA OS accumulates financial, labor and operational evidence, backup/restore readiness becomes business continuity rather than an engineering nice-to-have.

---

# Current priority order

1. **W0 website takeover** in parallel — recover domain authority + build from Figma.
2. **M4B1 production rollout** when secure Supabase production access is available.
3. Close real acceptance gates #8/#10/#13 opportunistically.
4. **M4B2 cash-expense comparison/acknowledgment.**
5. **M4C digital closing + Service Day owner hub.**
6. **M2B labor hours/wages.**
7. **M5A FANY order draft/history.**
8. **M5B supplier/order/receiving** only where useful.
9. **M3B invoice inbox/document intake improvements.**
10. **M6A POHODA/accountant export.**
11. Supplier price history → recipe costing.
12. Scheduling.
13. Inventory/par/waste when real pain appears.
14. Public menu publishing from KAFKA OS.
15. Much later POS/KDS/payments.

---

# Non-goals for the foreseeable roadmap

- generic SaaS onboarding/multi-tenant productization;
- guest ordering/customer app;
- loyalty/CRM;
- reservation-platform product work;
- deep HR/payroll;
- comprehensive inventory before KAFKA needs it;
- AI chatbot over incomplete data;
- accounting engine replacing POHODA;
- automatic supplier ordering without human approval;
- POS/KDS before back-office foundations are accepted.
