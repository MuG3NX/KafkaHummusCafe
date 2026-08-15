import { parseMoneyToMinorUnits } from "./money";

export type ServiceDayCloseState = {
  location_id: string;
  service_day_id: string | null;
  business_date: string;
  current_business_date: string;
  has_revenue: boolean;
  revenue_entry_id: string | null;
  revenue_entry_version: number | null;
  total_revenue_czk_minor: string | null;
  card_czk_minor: string | null;
  cash_czk_minor: string | null;
  cash_register_expenses_czk_minor: string | null;
  euros_minor: string | null;
  physical_cash_handed_over_czk_minor: string | null;
  is_closed: boolean;
  closure_id: string | null;
  closure_version: number | null;
  closure_revenue_entry_id: string | null;
  closure_revenue_entry_version: number | null;
  revenue_binding_current: boolean;
  usd_minor: string | null;
  gbp_minor: string | null;
  physical_eur_minor: string | null;
  physical_usd_minor: string | null;
  physical_gbp_minor: string | null;
  closure_note: string | null;
  closed_by: string | null;
  closed_at: string | null;
  closing_snapshot_confirmed_minor: string | null;
  closing_snapshot_difference_minor: string | null;
  closing_snapshot_acknowledgment_id: string | null;
  current_confirmed_cash_expenses_minor: string;
  current_cash_expense_difference_minor: string | null;
  current_cash_expense_acknowledgment_id: string | null;
  current_cash_expense_acknowledgment_reason: string | null;
  draft_cash_expense_count: number;
  open_shift_count: number;
  invoices_needing_review_count: number;
  handoff_note_count: number;
  latest_handoff_note: string | null;
  latest_handoff_note_by: string | null;
  latest_handoff_note_at: string | null;
};

export type ClosingDraft = {
  usd: string;
  gbp: string;
  physicalEur: string;
  physicalUsd: string;
  physicalGbp: string;
  note: string;
};

export type ParsedClosingDraft = {
  usdMinor: bigint;
  gbpMinor: bigint;
  physicalEurMinor: bigint;
  physicalUsdMinor: bigint;
  physicalGbpMinor: bigint;
  note: string | null;
};

export type ClosingAttempt = {
  id: string;
  locationId: string;
  businessDate: string;
  revenueEntryId: string;
  revenueEntryVersion: number;
  usdMinor: string;
  gbpMinor: string;
  physicalEurMinor: string;
  physicalUsdMinor: string;
  physicalGbpMinor: string;
  note: string | null;
};

export type HandoffNoteAttempt = {
  id: string;
  locationId: string;
  businessDate: string;
  note: string;
};

export type ClosingWarning = {
  key: "cash_difference" | "draft_cash" | "open_shifts" | "invoice_review" | "stale_revenue";
  message: string;
};

function nonNegativeMoney(value: string, currency: "EUR" | "USD" | "GBP"): bigint {
  const parsed = parseMoneyToMinorUnits(value.trim() || "0", currency);
  if (parsed < 0n) throw new Error("Closing money values cannot be negative.");
  return parsed;
}

export function validateClosingDraft(draft: ClosingDraft): ParsedClosingDraft {
  return {
    usdMinor: nonNegativeMoney(draft.usd, "USD"),
    gbpMinor: nonNegativeMoney(draft.gbp, "GBP"),
    physicalEurMinor: nonNegativeMoney(draft.physicalEur, "EUR"),
    physicalUsdMinor: nonNegativeMoney(draft.physicalUsd, "USD"),
    physicalGbpMinor: nonNegativeMoney(draft.physicalGbp, "GBP"),
    note: draft.note.trim() || null
  };
}

export function createOrReuseClosingAttempt(
  existing: ClosingAttempt | null,
  state: ServiceDayCloseState,
  parsed: ParsedClosingDraft,
  makeId: () => string
): ClosingAttempt {
  if (existing) return existing;
  if (!state.has_revenue || !state.revenue_entry_id || state.revenue_entry_version === null) {
    throw new Error("Revenue must be submitted before closing the service day.");
  }
  if (state.is_closed) throw new Error("This service day is already closed.");
  return {
    id: makeId(),
    locationId: state.location_id,
    businessDate: state.business_date,
    revenueEntryId: state.revenue_entry_id,
    revenueEntryVersion: state.revenue_entry_version,
    usdMinor: parsed.usdMinor.toString(),
    gbpMinor: parsed.gbpMinor.toString(),
    physicalEurMinor: parsed.physicalEurMinor.toString(),
    physicalUsdMinor: parsed.physicalUsdMinor.toString(),
    physicalGbpMinor: parsed.physicalGbpMinor.toString(),
    note: parsed.note
  };
}

export function validateHandoffNote(value: string): string {
  const note = value.trim();
  if (!note) throw new Error("Enter a handoff note.");
  return note;
}

export function createOrReuseHandoffNoteAttempt(
  existing: HandoffNoteAttempt | null,
  locationId: string,
  businessDate: string,
  noteInput: string,
  makeId: () => string
): HandoffNoteAttempt {
  if (existing) return existing;
  return { id: makeId(), locationId, businessDate, note: validateHandoffNote(noteInput) };
}

export function closingWarnings(state: ServiceDayCloseState): ClosingWarning[] {
  const warnings: ClosingWarning[] = [];
  if (state.is_closed && !state.revenue_binding_current) {
    warnings.push({ key: "stale_revenue", message: "Revenue changed after this day was closed. Owner review is required." });
  }
  if (state.current_cash_expense_difference_minor !== null
      && BigInt(state.current_cash_expense_difference_minor) !== 0n
      && !state.current_cash_expense_acknowledgment_id) {
    warnings.push({ key: "cash_difference", message: "Cash-register expenses are not fully reconciled." });
  }
  if (state.draft_cash_expense_count > 0) {
    warnings.push({ key: "draft_cash", message: `${state.draft_cash_expense_count} cash expense${state.draft_cash_expense_count === 1 ? " is" : "s are"} still Draft.` });
  }
  if (state.open_shift_count > 0) {
    warnings.push({ key: "open_shifts", message: `${state.open_shift_count} shift${state.open_shift_count === 1 ? " is" : "s are"} still open.` });
  }
  if (state.invoices_needing_review_count > 0) {
    warnings.push({ key: "invoice_review", message: `${state.invoices_needing_review_count} invoice${state.invoices_needing_review_count === 1 ? " needs" : "s need"} review.` });
  }
  return warnings;
}

export function canFinalizeClose(state: ServiceDayCloseState): boolean {
  return state.has_revenue && !state.is_closed;
}
