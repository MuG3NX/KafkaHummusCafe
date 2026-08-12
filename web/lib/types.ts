export type Location = { id: string; name: string; timezone: string };

export type RevenueEntry = {
  id: string;
  location_id: string;
  business_date: string;
  submitted_by: string;
  total_revenue_czk_minor: string;
  card_czk_minor: string;
  cash_czk_minor: string;
  cash_register_expenses_czk_minor: string;
  euros_minor: string;
  physical_cash_handed_over_czk_minor: string;
  note: string | null;
  status: "submitted";
  version: number;
  submitted_at: string;
  updated_at: string;
};

export type Draft = {
  total: string;
  card: string;
  cash: string;
  expenses: string;
  euros: string;
  handover: string;
  note: string;
};

export const EMPTY_DRAFT: Draft = { total: "", card: "", cash: "", expenses: "", euros: "", handover: "", note: "" };
