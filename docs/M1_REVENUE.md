# M1 — Revenue Tracker

## Objective
Replace the current paper -> manual Excel revenue workflow with a phone-first shared system while laying the permanent foundation for later restaurant modules.

## Real daily inputs
- total revenue (CZK)
- card (CZK)
- cash (CZK)
- cash-register expenses / daily costs (CZK)
- euros (EUR)
- physical cash handed to owner (CZK)
- optional note

Do not invent automatic reconciliation rules yet. Capture the restaurant's current truth first; add validation/reconciliation only after observing real entries.

## Roles
- About 10 employees total.
- About 3–4 authorized people may enter/submit revenue.
- Only owner can correct submitted revenue.
- The authorization model must support adding/removing revenue-submission capability without code changes.

## User flow
1. Sign in.
2. Open Today.
3. See current service day.
4. Tap `Enter revenue`.
5. Enter the six real fields using numeric keyboards.
6. Review a clean summary.
7. Submit.
8. Record becomes read-only to submitter.
9. Owner sees history/summary and may initiate `Correct entry`.
10. Owner correction requires a reason and leaves prior values recoverable/auditable.

## Acceptance criteria
- Works comfortably at ~375px phone width.
- Can be installed as PWA on current iOS/Android browsers over HTTPS.
- No secrets in repository or browser bundle beyond client-safe publishable configuration.
- RLS enabled on every exposed production table.
- Unauthorized employee cannot submit/read revenue merely by calling API directly.
- Normal revenue submitter cannot update/delete a submitted entry via API.
- Owner correction is auditable with who/when/reason/previous values.
- Money parsing is integer-minor-unit safe.
- Service-day business date is explicit and timezone-aware.
- History is queryable by location/date.
- Basic owner summary derives from stored records rather than duplicated manual totals.
- Offline state does not pretend a financial submission succeeded.
- Lint/typecheck/tests pass in CI.

## Out of scope for M1
- shift clock
- invoice OCR
- VAT calculations
- FANY scraping/order submission
- inventory
- POS
- complex analytics
- line-item cash expenses

These are intentionally deferred, not forgotten.
