import { describe, expect, it } from "vitest";
import {
  canConfirmCashExpense,
  cashExpenseAuditLabel,
  cashExpenseTotals,
  costsSectionsForRole,
  formatCashExpenseServiceDay,
  statusAfterCashExpenseCorrection,
  validateCashExpenseDraft,
  type CashExpenseEntry
} from "./cash-expenses";

function entry(status: "draft" | "confirmed", amount: string): CashExpenseEntry {
  return {
    id: crypto.randomUUID(),
    location_id: "location",
    service_day_id: "service-day",
    business_date: "2026-08-14",
    amount_czk_minor: amount,
    description: "Register purchase",
    status,
    version: 1,
    captured_by: "owner",
    captured_at: "2026-08-14T12:00:00Z",
    confirmed_by: status === "confirmed" ? "owner" : null,
    confirmed_at: status === "confirmed" ? "2026-08-14T12:01:00Z" : null,
    confirmed_version: status === "confirmed" ? 1 : null,
    updated_at: "2026-08-14T12:01:00Z"
  };
}

describe("cash expense domain", () => {
  it("exposes approved invoices and cash expenses to owners", () => {
    expect(costsSectionsForRole("owner")).toEqual(["approved", "cash"]);
  });

  it("exposes only cash expenses to managers and nothing to employees", () => {
    expect(costsSectionsForRole("manager")).toEqual(["cash"]);
    expect(costsSectionsForRole("employee")).toEqual([]);
  });

  it("offers confirmation only for draft evidence", () => {
    expect(canConfirmCashExpense("draft")).toBe(true);
    expect(canConfirmCashExpense("confirmed")).toBe(false);
  });

  it("returns corrected evidence to draft", () => {
    expect(statusAfterCashExpenseCorrection()).toBe("draft");
  });

  it("parses exact CZK bigint values beyond Number safe range", () => {
    expect(validateCashExpenseDraft(
      { amount: "90071992547409.93", description: "  Exact purchase  ", businessDate: "2026-08-14" },
      "2026-08-14"
    )).toEqual({ amountMinor: 9007199254740993n, description: "Exact purchase", businessDate: "2026-08-14" });
  });

  it("surfaces future service-day errors", () => {
    expect(() => validateCashExpenseDraft(
      { amount: "10", description: "Purchase", businessDate: "2026-08-15" },
      "2026-08-14"
    )).toThrow("future service day");
  });

  it("surfaces empty descriptions", () => {
    expect(() => validateCashExpenseDraft(
      { amount: "10", description: "   ", businessDate: "2026-08-14" },
      "2026-08-14"
    )).toThrow("description or reason");
  });

  it("rejects zero cash expenses", () => {
    expect(() => validateCashExpenseDraft(
      { amount: "0", description: "Purchase", businessDate: "2026-08-14" },
      "2026-08-14"
    )).toThrow("greater than zero");
  });

  it("totals draft and confirmed items independently with BigInt", () => {
    expect(cashExpenseTotals([
      entry("draft", "9007199254740993"),
      entry("confirmed", "9007199254740995"),
      entry("confirmed", "5")
    ])).toEqual({ draftMinor: 9007199254740993n, confirmedMinor: 9007199254741000n });
  });

  it("displays the explicit business date without browser timezone drift", () => {
    expect(formatCashExpenseServiceDay("2026-08-14", "en-GB")).toBe("14 Aug 2026");
  });

  it("labels confirmation after a correction as re-confirmed", () => {
    expect(cashExpenseAuditLabel({
      id: "event",
      cash_expense_id: "expense",
      event_type: "confirmed",
      expense_version: 2,
      actor_id: "owner",
      reason: null,
      created_at: "2026-08-14T12:00:00Z"
    })).toBe("Re-confirmed");
  });
});
