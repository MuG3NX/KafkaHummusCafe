# Roadmap

The controlling long-range product map is now [`KAFKA_MASTER_ROADMAP_V2.md`](KAFKA_MASTER_ROADMAP_V2.md), tracked by Issue #21.

## Current state
- M1 Revenue: production-deployed, accepted, frozen except genuine bugs.
- M2A Shifts: production-deployed; genuine employee acceptance remains open in Issue #8.
- M3A Invoice Capture: production-deployed; legitimate real-invoice acceptance remains open in Issue #10.
- M4A Approved Invoice Costs: production-deployed; owner acceptance remains open in Issue #13.
- M4B1 Cash Expense Evidence Ledger: architecture-approved in draft PR #18 at exact head `868d12528b9dff9e492edd6ed7a5c2152b77ddcb`; production rollout pending.
- W0 Website Takeover: owner Webglobe/domain/DNS access confirmed in Issue #20; build parked until owner explicitly resumes it.
- W0R Reservations: V1 workflow fully locked in Issue #23; launch-critical with the rebuilt public website.

## Priority order
1. W0 website + reservations remain parked but prominent; no DNS change before preview acceptance.
2. M4B1 production rollout when secure Supabase production access is available.
3. Close Issues #8/#10/#13 opportunistically with genuine workflows.
4. M4B2 daily cash-expense comparison / acknowledgment.
5. M4C digital closing + Service Day owner/manager hub.
6. M2B hourly rates + wage estimation/export.
7. M5A FANY order sheet/history preserving Mohammed's real workflow.
8. M5B generalized supplier/product/order/receiving only where real usage justifies it.
9. M3B invoice inbox / emailed PDF intake.
10. M6A POHODA/accountant package.
11. Supplier price history + recipe/menu costing.
12. Scheduling.
13. Inventory/par/waste only when it becomes a real operating problem.
14. Public menu/opening-hours publishing from KAFKA OS.
15. Much later POS/KDS/payments/table management.

## Locked reminders
- Physical handover is explicit entered/count truth, not auto-derived authority.
- Trusted non-owner closers use a capability such as `can_close_day`; identities are not hard-coded.
- FANY is the structured purchasing workflow: Mohammed decides products + quantities, bar/management places the e-shop order. Other old-school suppliers are not forced into M5A.
- Mohammed is an owner and may see the full KAFKA system.
- Reservations auto-confirm in V1, require name/email/phone/date/time/party size, optional note, 09:00–17:00 in 30-minute slots, at least 1-hour same-day lead time, max 6 online; all staff can read, owner/`can_manage_reservations` can change/cancel; guest gets confirmation/update/cancellation email; owner gets new-booking notification.
- Website takeover keeps Webglobe registrar/DNS initially; no nameserver migration unless later justified.

See the master roadmap for detailed scope, exclusions, acceptance rules and anti-drift boundaries.
