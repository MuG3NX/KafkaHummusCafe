# M2 — Shifts & Hours

## Objective

Replace the paper clock with a phone-first start/end shift flow while keeping the database authoritative for timestamps and service-day identity.

## Rules

- Employees clock in and out from their own authenticated phones.
- There are no breaks, split shifts, schedules, wages, tips, GPS checks, or onboarding automation in M2.
- A membership can have at most one shift per service day and one open shift at a time.
- `start_shift` and `end_shift` use PostgreSQL `now()`. The client sends only the location or shift identifier.
- The shift's service day is resolved at clock-in using the location timezone and the 05:00 cutoff. Ending after midnight or after 05:00 never reassigns it.
- Open shifts are visible as working now but do not count in finalized totals.

## Data and authorization

`shifts` stores the location, service day, employee membership, explicit business date, and exact start/end instants. Duration is always derived from `ended_at - started_at`; it is not stored as accounting truth. Composite foreign keys keep the service-day identity and employee-location assignment coherent.

Employees can select only their own shifts and can mutate state only through their own start/end RPCs. Owners can select all shifts in their location. Direct insert/update/delete is denied through the exposed client path.

Owner corrections use `correct_shift`, require a non-empty reason, validate the timestamps, append the previous values to `shift_revisions`, and increment the live row version in one transaction. Audit history is append-only and owner-readable only.

## UI slice

The existing PWA has a simple Revenue / Shifts module switch. Employees see their current state, a large Start/End action, recent own completed shifts, and weekly/monthly finalized totals. Owners additionally see who is working, all location shifts, per-employee totals, and an audited correction form. Offline clock actions remain unavailable and never claim success.

## Verification

Executable pgTAP scenarios cover assignment and owner permissions, database timestamps, one-shift rules, cross-midnight/service-day retention, direct mutation denial, correction audit, invalid corrections, and corrected duration totals. Client tests cover duration, time/date display, and totals.
