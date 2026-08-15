import { describe, expect, it } from "vitest";
import {
  canFinalizeClose,
  closingWarnings,
  createOrReuseClosingAttempt,
  createOrReuseHandoffNoteAttempt,
  validateClosingDraft,
  type ServiceDayCloseState
} from "./closing";

const baseState: ServiceDayCloseState = {
  location_id: "location-1",
  service_day_id: "day-1",
  business_date: "2026-08-15",
  current_business_date: "2026-08-15",
  has_revenue: true,
  revenue_entry_id: "revenue-1",
  revenue_entry_version: 2,
  total_revenue_czk_minor: "1000000",
  card_czk_minor: "700000",
  cash_czk_minor: "300000",
  cash_register_expenses_czk_minor: "40000",
  euros_minor: "12500",
  physical_cash_handed_over_czk_minor: "260000",
  is_closed: false,
  closure_id: null,
  closure_version: null,
  closure_revenue_entry_id: null,
  closure_revenue_entry_version: null,
  revenue_binding_current: false,
  usd_minor: null,
  gbp_minor: null,
  physical_eur_minor: null,
  physical_usd_minor: null,
  physical_gbp_minor: null,
  closure_note: null,
  closed_by: null,
  closed_at: null,
  closing_snapshot_confirmed_minor: null,
  closing_snapshot_difference_minor: null,
  closing_snapshot_acknowledgment_id: null,
  current_confirmed_cash_expenses_minor: "35000",
  current_cash_expense_difference_minor: "5000",
  current_cash_expense_acknowledgment_id: null,
  current_cash_expense_acknowledgment_reason: null,
  draft_cash_expense_count: 1,
  open_shift_count: 2,
  invoices_needing_review_count: 3,
  handoff_note_count: 0,
  latest_handoff_note: null,
  latest_handoff_note_by: null,
  latest_handoff_note_at: null
};

describe("digital closing domain", () => {
  it("treats blank foreign-currency inputs as exact zero and trims the note", () => {
    expect(validateClosingDraft({ usd: "", gbp: "0", physicalEur: "125.50", physicalUsd: "", physicalGbp: "0", note: "  Normal close  " })).toEqual({
      usdMinor: 0n,
      gbpMinor: 0n,
      physicalEurMinor: 12550n,
      physicalUsdMinor: 0n,
      physicalGbpMinor: 0n,
      note: "Normal close"
    });
  });

  it("rejects negative closing money", () => {
    expect(() => validateClosingDraft({ usd: "-1", gbp: "0", physicalEur: "0", physicalUsd: "0", physicalGbp: "0", note: "" })).toThrow(/cannot be negative/);
  });

  it("retains exact values beyond the JavaScript safe integer range", () => {
    const parsed = validateClosingDraft({ usd: "90071992547409.95", gbp: "0", physicalEur: "0", physicalUsd: "0", physicalGbp: "0", note: "" });
    expect(parsed.usdMinor).toBe(9007199254740995n);
  });

  it("creates one exact close attempt from current Revenue identity", () => {
    const parsed = validateClosingDraft({ usd: "12.34", gbp: "5.00", physicalEur: "125", physicalUsd: "12.34", physicalGbp: "5", note: "Close" });
    expect(createOrReuseClosingAttempt(null, baseState, parsed, () => "close-id")).toEqual({
      id: "close-id",
      locationId: "location-1",
      businessDate: "2026-08-15",
      revenueEntryId: "revenue-1",
      revenueEntryVersion: 2,
      usdMinor: "1234",
      gbpMinor: "500",
      physicalEurMinor: "12500",
      physicalUsdMinor: "1234",
      physicalGbpMinor: "500",
      note: "Close"
    });
  });

  it("reuses the same close identity and payload across ambiguous retry", () => {
    const parsed = validateClosingDraft({ usd: "1", gbp: "2", physicalEur: "3", physicalUsd: "4", physicalGbp: "5", note: "First" });
    const first = createOrReuseClosingAttempt(null, baseState, parsed, () => "first-id");
    const reused = createOrReuseClosingAttempt(first, { ...baseState, revenue_entry_version: 99 }, validateClosingDraft({ usd: "99", gbp: "99", physicalEur: "99", physicalUsd: "99", physicalGbp: "99", note: "Changed" }), () => "second-id");
    expect(reused).toBe(first);
    expect(reused.id).toBe("first-id");
    expect(reused.revenueEntryVersion).toBe(2);
    expect(reused.usdMinor).toBe("100");
  });

  it("requires Revenue and an unclosed day before creating a close attempt", () => {
    const parsed = validateClosingDraft({ usd: "0", gbp: "0", physicalEur: "0", physicalUsd: "0", physicalGbp: "0", note: "" });
    expect(() => createOrReuseClosingAttempt(null, { ...baseState, has_revenue: false, revenue_entry_id: null, revenue_entry_version: null }, parsed, () => "id")).toThrow(/Revenue must be submitted/);
    expect(() => createOrReuseClosingAttempt(null, { ...baseState, is_closed: true }, parsed, () => "id")).toThrow(/already closed/);
  });

  it("derives non-blocking readiness warnings", () => {
    expect(closingWarnings(baseState).map((warning) => warning.key)).toEqual(["cash_difference", "draft_cash", "open_shifts", "invoice_review"]);
  });

  it("does not warn about an acknowledged cash difference", () => {
    expect(closingWarnings({ ...baseState, current_cash_expense_acknowledgment_id: "ack-1" }).map((warning) => warning.key)).not.toContain("cash_difference");
  });

  it("surfaces stale Revenue binding after a completed close", () => {
    expect(closingWarnings({ ...baseState, is_closed: true, revenue_binding_current: false }).map((warning) => warning.key)).toContain("stale_revenue");
  });

  it("only permits finalization when Revenue exists and the day is not already closed", () => {
    expect(canFinalizeClose(baseState)).toBe(true);
    expect(canFinalizeClose({ ...baseState, has_revenue: false })).toBe(false);
    expect(canFinalizeClose({ ...baseState, is_closed: true })).toBe(false);
  });

  it("creates and reuses one normalized handoff note attempt", () => {
    const first = createOrReuseHandoffNoteAttempt(null, "location-1", "2026-08-15", "  Call plumber tomorrow  ", () => "note-id");
    expect(first.note).toBe("Call plumber tomorrow");
    expect(createOrReuseHandoffNoteAttempt(first, "other-location", "2026-08-16", "Different", () => "other-id")).toBe(first);
  });

  it("rejects an empty handoff note", () => {
    expect(() => createOrReuseHandoffNoteAttempt(null, "location-1", "2026-08-15", "   ", () => "id")).toThrow(/Enter a handoff note/);
  });
});
