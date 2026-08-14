import type { Currency } from "./money";

export type ApprovedInvoiceCost = {
  invoice_id: string;
  storage_path: string;
  original_filename: string;
  approved_draft_version: number;
  supplier_name: string;
  invoice_number: string;
  issue_date: string;
  due_date: string | null;
  currency: Currency;
  net_minor: string;
  vat_minor: string;
  gross_minor: string;
};

export type CurrencyCostTotal = {
  currency: Currency;
  count: number;
  netMinor: string;
  vatMinor: string;
  grossMinor: string;
};

export function currentMonthForTimezone(now: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat("en", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit"
  }).formatToParts(now);
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  if (!year || !month) throw new Error("Could not resolve the reporting month");
  return `${year}-${month}`;
}

export function totalsByCurrency(rows: ApprovedInvoiceCost[]): CurrencyCostTotal[] {
  const totals: Record<Currency, { count: number; net: bigint; vat: bigint; gross: bigint }> = {
    CZK: { count: 0, net: 0n, vat: 0n, gross: 0n },
    EUR: { count: 0, net: 0n, vat: 0n, gross: 0n }
  };
  for (const row of rows) {
    const total = totals[row.currency];
    total.count += 1;
    total.net += BigInt(row.net_minor);
    total.vat += BigInt(row.vat_minor);
    total.gross += BigInt(row.gross_minor);
  }
  return (Object.keys(totals) as Currency[]).map((currency) => ({
    currency,
    count: totals[currency].count,
    netMinor: totals[currency].net.toString(),
    vatMinor: totals[currency].vat.toString(),
    grossMinor: totals[currency].gross.toString()
  }));
}
