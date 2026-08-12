# KAFKA Restaurant Platform — Agent Contract

This repository is the source of truth for the KAFKA restaurant platform.

## Roles
- ChatGPT is the architecture/review lead ("head chef").
- Codex is the implementation lead ("executive chef").
- GitHub issues define scoped work; branches/commits/PRs capture implementation and review history.

## Product rule
Build one modular restaurant platform, not separate throwaway apps. The first useful module is Revenue; later modules include Shifts, Invoice Capture/OCR, Costs, End-of-Shift, FANY Gastroservis ordering, Reporting/VAT, Inventory/Scheduling, and eventually POS.

## Non-negotiables
1. Mobile-first PWA: iPhone and Android from one web app.
2. One central Postgres database and one auth/roles system.
3. Financial records are auditable. Do not silently overwrite or hard-delete financial history.
4. OCR output is never accounting truth until a human approves it.
5. External systems (OCR providers, FANY, future POS/accounting) are adapters behind internal interfaces.
6. Never commit secrets, production credentials, invoice documents, exports containing personal/financial data, or live database dumps.
7. Schema changes are migrations committed to Git.
8. Keep `main` deployable. Use focused branches and PRs.
9. Prefer boring, maintainable code over clever abstractions. Do not overbuild modules before their milestone.
10. UI must be visually calm, modern, extremely simple, large-touch-target, and usable one-handed during restaurant service.

## Current milestone
M1 Revenue is accepted and frozen except for genuine bugs. The current milestone is M2 Shifts & Hours. See `docs/M2_SHIFTS.md`.

## Current real workflow
Revenue is written on paper and later copied manually into Excel. Daily fields are total revenue, card, cash, cash-register expenses, euros, and physical cash handed to the owner. Roughly 3–4 authorized users may submit revenue. Only the owner may correct submitted revenue. There are about 10 employees; shifts are currently tracked in Excel.

## Engineering defaults
- TypeScript strict mode.
- Next.js App Router PWA frontend.
- Supabase: Postgres, Auth, Storage.
- Store money as integer minor units; never JS floating-point money.
- Use UUIDs, `timestamptz` for instants, and a location timezone plus explicit service-day business date.
- Database RLS is mandatory for exposed tables.
- Validate privileged actions server-side/database-side; hidden buttons are not authorization.
- No offline mutation queue for financial submissions until conflict/idempotency behavior is deliberately designed. Offline can be read-only/clearly unavailable in M1.
- Add tests around money parsing, permissions, service-day behavior, and correction/audit logic.
- Accessible labels, numeric input modes, minimum comfortable touch targets, safe-area handling.

## Definition of "fast"
Fast means a thin end-to-end slice users can touch. It does not mean bypassing migrations, authorization, auditability, or Git history.
