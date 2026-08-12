# KAFKA Restaurant Platform

A mobile-first restaurant operations platform built incrementally from real restaurant workflows.

The repository currently contains the original 2025 Swift experiment and the new web-platform direction. The Swift history is preserved; new platform work is governed by `AGENTS.md` and `docs/`.

## Start here
- `AGENTS.md` — rules for ChatGPT/Codex work
- `docs/ARCHITECTURE.md` — technical boundaries and non-negotiables
- `docs/M1_REVENUE.md` — first production milestone
- `docs/ROADMAP.md` — staged expansion

## Immediate preview
`preview/kafka-revenue-preview.html` is a touchable M0 visual/interaction preview of the real revenue flow. It uses only local browser storage and must never be treated as production financial persistence.

## Security
Never commit `.env*` secrets, private keys, production exports, invoice documents, personal employee data, or database dumps. GitHub protects source/history; production database/storage require separate backups.
