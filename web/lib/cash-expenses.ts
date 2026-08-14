import { parseMoneyToMinorUnits } from "./money";

export type CashExpenseStatus = "draft" | "confirmed";

export type CashExpenseEntry = {
  id: string;
  location_id: string;
  service_day_id: string;
  business_date: string;
  amount_czk_minor: string;
  description: string;
  status: CashExpenseStatus;
  version: number;
  captured_by: string;
  captured_at: string;
  confirmed_by: string | null;
  confirmed_at: string | null;
  confirmed_version: number | null;
  updated_at: string;
};

export type CashExpenseAuditEvent = {
  id: string;
  cash_expense_id: string;
  event_type: "captured" | "confirmed" | "corrected";
  expense_version: number;
  actor_id: string;
  reason: string | null;
  created_at: string;
};

export type CashExpenseDraft = {
  amount: string;
  description: string;
  businessDate: string;
};

export type CostsSection = "approved" | "cash";

export function costsSectionsForRole(role: string): CostsSection[] {
  if (role === "owner") return ["approved", "cash"];
  if (role === "manager") return ["cash"];
  return [];
}

export function canConfirmCashExpense(status: CashExpenseStatus): boolean {
  return status === "draft";
}

export function statusAfterCashExpenseCorrection(): CashExpenseStatus {
  return "draft";
}

export function validateCashExpenseDraft(
  draft: CashExpenseDraft,
  currentBusinessDate: string
): { amountMinor: bigint; description: string; businessDate: string } {
  const description = draft.description.trim();
  if (!draft.businessDate) throw new Error("Choose a service day.");
  if (draft.businessDate > currentBusinessDate) {
    throw new Error("Cash expenses cannot use a future service day.");
  }
  if (!description) throw new Error("Enter a description or reason.");
  const amountMinor = parseMoneyToMinorUnits(draft.amount, "CZK");
  if (amountMinor <= 0n) throw new Error("Cash expense amount must be greater than zero.");
  return { amountMinor, description, businessDate: draft.businessDate };
}

export function cashExpenseTotals(entries: CashExpenseEntry[]): {
  draftMinor: bigint;
  confirmedMinor: bigint;
} {
  return entries.reduce(
    (total, entry) => {
      if (entry.status === "confirmed") total.confirmedMinor += BigInt(entry.amount_czk_minor);
      else total.draftMinor += BigInt(entry.amount_czk_minor);
      return total;
    },
    { draftMinor: 0n, confirmedMinor: 0n }
  );
}

export function formatCashExpenseServiceDay(value: string, locale = "en-GB"): string {
  return new Intl.DateTimeFormat(locale, {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC"
  }).format(new Date(`${value}T00:00:00Z`));
}

export function cashExpenseAuditLabel(event: CashExpenseAuditEvent): string {
  if (event.event_type === "confirmed" && event.expense_version > 1) return "Re-confirmed";
  if (event.event_type === "captured") return "Captured";
  if (event.event_type === "confirmed") return "Confirmed";
  return "Corrected";
}

export function amountMinorToInput(value: string): string {
  const amount = BigInt(value);
  const absolute = amount < 0n ? -amount : amount;
  return `${amount < 0n ? "-" : ""}${absolute / 100n}.${(absolute % 100n).toString().padStart(2, "0")}`;
}
