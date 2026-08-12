# KAFKA Restaurant Platform

A mobile-first restaurant operations platform built incrementally from real restaurant workflows.

The repository currently contains the original 2025 Swift experiment and the new web-platform direction. The Swift history is preserved; new platform work is governed by `AGENTS.md` and `docs/`.

## M1 production slice

The production web app lives in `web/`. It uses Next.js, Supabase Auth/Postgres, explicit service-day dates, integer minor-unit money, RLS, and database-side audited owner corrections. Supabase migrations are in `supabase/migrations/`.

```sh
npm install
cp web/.env.example web/.env.local
npm run dev
```

Configure `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, apply the migrations with `supabase db push`, and follow [`supabase/README.md`](supabase/README.md) to bootstrap the first owner/location. Financial submissions are intentionally unavailable while offline; this M1 app does not pretend that a local mutation reached the database.

The Vercel deployment should use the same two `NEXT_PUBLIC_` variables. Never add a service-role key to GitHub, Vercel browser-visible variables, or this repository.

## Start here
- `AGENTS.md` — rules for ChatGPT/Codex work
- `docs/ARCHITECTURE.md` — technical boundaries and non-negotiables
- `docs/M1_REVENUE.md` — first production milestone
- `docs/ROADMAP.md` — staged expansion

## Immediate preview
`preview/kafka-revenue-preview.html` is a touchable M0 visual/interaction preview of the real revenue flow. It uses only local browser storage and must never be treated as production financial persistence.

## Security
Never commit `.env*` secrets, private keys, production exports, invoice documents, personal employee data, or database dumps. GitHub protects source/history; production database/storage require separate backups.
