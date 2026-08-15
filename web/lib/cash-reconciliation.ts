export type CashExpenseReconciliation = {
  location_id: string;
  service_day_id: string | null;
  business_date: string;
  has_revenue: boolean;
  revenue_entry_id: string | null;
  revenue_entry_version: number | null;
  closing_expenses_czk_minor: string | null;
  confirmed_cash_expenses_czk_minor: string;
  confirmed_source_fingerprint: string;
  difference_czk_minor: string | null;
  confirmed_count: number;
  draft_count: number;
  acknowledgment_id: string | null;
  acknowledgment_reason: string | null;
  acknowledged_by: string | null;
  acknowledged_at: string | null;
};

export type ReconciliationState = "no_revenue" | "matched" | "needs_review" | "acknowledged";

export type ReconciliationAcknowledgmentAttempt = {
  id: string;
  locationId: string;
  businessDate: string;
  revenueEntryId: string;
  revenueEntryVersion: number;
  closingMinor: string;
  confirmedMinor: string;
  confirmedFingerprint: string;
  differenceMinor: string;
  reason: string;
};

export function reconciliationState(row: CashExpenseReconciliation): ReconciliationState {
  if (!row.has_revenue || row.difference_czk_minor === null) return "no_revenue";
  if (BigInt(row.difference_czk_minor) === 0n) return "matched";
  if (row.acknowledgment_id) return "acknowledged";
  return "needs_review";
}

export function reconciliationStateLabel(state: ReconciliationState): string {
  if (state === "matched") return "Matched";
  if (state === "acknowledged") return "Difference acknowledged";
  if (state === "needs_review") return "Difference needs review";
  return "Revenue not submitted";
}

export function validateReconciliationAcknowledgment(
  row: CashExpenseReconciliation,
  reasonInput: string
): { reason: string } {
  if (!row.has_revenue
      || !row.revenue_entry_id
      || row.revenue_entry_version === null
      || row.closing_expenses_czk_minor === null
      || row.difference_czk_minor === null) {
    throw new Error("Revenue must be submitted before a difference can be acknowledged.");
  }
  if (BigInt(row.difference_czk_minor) === 0n) {
    throw new Error("Matched cash expenses do not need acknowledgment.");
  }
  if (!/^[0-9a-f]{64}$/.test(row.confirmed_source_fingerprint)) {
    throw new Error("The reconciliation evidence fingerprint is invalid. Reload before acknowledging.");
  }
  const reason = reasonInput.trim();
  if (!reason) throw new Error("Enter an acknowledgment reason.");
  return { reason };
}

export function createOrReuseReconciliationAcknowledgmentAttempt(
  existing: ReconciliationAcknowledgmentAttempt | null,
  row: CashExpenseReconciliation,
  reasonInput: string,
  makeId: () => string
): ReconciliationAcknowledgmentAttempt {
  if (existing) return existing;
  const { reason } = validateReconciliationAcknowledgment(row, reasonInput);
  return {
    id: makeId(),
    locationId: row.location_id,
    businessDate: row.business_date,
    revenueEntryId: row.revenue_entry_id!,
    revenueEntryVersion: row.revenue_entry_version!,
    closingMinor: row.closing_expenses_czk_minor!,
    confirmedMinor: row.confirmed_cash_expenses_czk_minor,
    confirmedFingerprint: row.confirmed_source_fingerprint,
    differenceMinor: row.difference_czk_minor!,
    reason
  };
}
