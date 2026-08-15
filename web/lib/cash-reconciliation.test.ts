import { describe, expect, it } from "vitest";
import {
  createOrReuseReconciliationAcknowledgmentAttempt,
  reconciliationState,
  reconciliationStateLabel,
  validateReconciliationAcknowledgment,
  type CashExpenseReconciliation
} from "./cash-reconciliation";

const baseRow: CashExpenseReconciliation = {
  location_id: "location-1",
  service_day_id: "day-1",
  business_date: "2026-08-15",
  has_revenue: true,
  revenue_entry_id: "revenue-1",
  revenue_entry_version: 3,
  closing_expenses_czk_minor: "9007199254740995",
  confirmed_cash_expenses_czk_minor: "9007199254740000",
  confirmed_source_fingerprint: "a".repeat(64),
  difference_czk_minor: "995",
  confirmed_count: 4,
  draft_count: 1,
  acknowledgment_id: null,
  acknowledgment_reason: null,
  acknowledged_by: null,
  acknowledged_at: null
};

describe("cash expense reconciliation domain", () => {
  it("distinguishes missing Revenue, matched, review, and acknowledged states", () => {
    expect(reconciliationState({ ...baseRow, has_revenue: false, revenue_entry_id: null, revenue_entry_version: null, closing_expenses_czk_minor: null, difference_czk_minor: null })).toBe("no_revenue");
    expect(reconciliationState({ ...baseRow, difference_czk_minor: "0" })).toBe("matched");
    expect(reconciliationState(baseRow)).toBe("needs_review");
    expect(reconciliationState({ ...baseRow, acknowledgment_id: "ack-1" })).toBe("acknowledged");
  });

  it("keeps over-explained signed differences rather than clamping them", () => {
    expect(reconciliationState({ ...baseRow, difference_czk_minor: "-2500" })).toBe("needs_review");
  });

  it("provides calm operational labels", () => {
    expect(reconciliationStateLabel("no_revenue")).toBe("Revenue not submitted");
    expect(reconciliationStateLabel("matched")).toBe("Matched");
    expect(reconciliationStateLabel("needs_review")).toBe("Difference needs review");
    expect(reconciliationStateLabel("acknowledged")).toBe("Difference acknowledged");
  });

  it("trims the acknowledgment reason", () => {
    expect(validateReconciliationAcknowledgment(baseRow, "  Reviewed with closer  ")).toEqual({ reason: "Reviewed with closer" });
  });

  it("rejects acknowledgment without Revenue, on a matched day, or with an invalid fingerprint", () => {
    expect(() => validateReconciliationAcknowledgment({ ...baseRow, has_revenue: false }, "Reason")).toThrow(/Revenue must be submitted/);
    expect(() => validateReconciliationAcknowledgment({ ...baseRow, difference_czk_minor: "0" }, "Reason")).toThrow(/do not need acknowledgment/);
    expect(() => validateReconciliationAcknowledgment({ ...baseRow, confirmed_source_fingerprint: "bad" }, "Reason")).toThrow(/fingerprint is invalid/);
  });

  it("retains exact values beyond Number safe range in the acknowledgment attempt", () => {
    const attempt = createOrReuseReconciliationAcknowledgmentAttempt(null, baseRow, "  Exact review  ", () => "ack-uuid");
    expect(attempt).toEqual({
      id: "ack-uuid",
      locationId: "location-1",
      businessDate: "2026-08-15",
      revenueEntryId: "revenue-1",
      revenueEntryVersion: 3,
      closingMinor: "9007199254740995",
      confirmedMinor: "9007199254740000",
      confirmedFingerprint: "a".repeat(64),
      differenceMinor: "995",
      reason: "Exact review"
    });
    expect(BigInt(attempt.closingMinor) - BigInt(attempt.confirmedMinor)).toBe(995n);
  });

  it("reuses one immutable acknowledgment attempt across an ambiguous retry", () => {
    const first = createOrReuseReconciliationAcknowledgmentAttempt(null, baseRow, "Reason", () => "first-id");
    const reused = createOrReuseReconciliationAcknowledgmentAttempt(first, { ...baseRow, difference_czk_minor: "123456" }, "Different typed reason", () => "second-id");
    expect(reused).toBe(first);
    expect(reused.id).toBe("first-id");
    expect(reused.differenceMinor).toBe("995");
    expect(reused.reason).toBe("Reason");
  });
});
