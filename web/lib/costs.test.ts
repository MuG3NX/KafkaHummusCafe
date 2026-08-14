import { describe, expect, it } from "vitest";
import { currentMonthForTimezone, totalsByCurrency, type ApprovedInvoiceCost } from "./costs";

function cost(overrides: Partial<ApprovedInvoiceCost>): ApprovedInvoiceCost {
  return {
    invoice_id: "invoice",
    storage_path: "location/invoice/original.pdf",
    original_filename: "original.pdf",
    approved_draft_version: 2,
    supplier_name: "Supplier",
    invoice_number: "INV-1",
    issue_date: "2026-08-01",
    due_date: null,
    currency: "CZK",
    net_minor: "0",
    vat_minor: "0",
    gross_minor: "0",
    ...overrides
  };
}

describe("approved invoice costs", () => {
  it("keeps CZK and EUR totals separate", () => {
    const totals = totalsByCurrency([
      cost({ currency: "CZK", net_minor: "10000", vat_minor: "2100", gross_minor: "12100" }),
      cost({ invoice_id: "eur", currency: "EUR", net_minor: "5000", vat_minor: "1000", gross_minor: "6000" })
    ]);
    expect(totals).toEqual([
      { currency: "CZK", count: 1, netMinor: "10000", vatMinor: "2100", grossMinor: "12100" },
      { currency: "EUR", count: 1, netMinor: "5000", vatMinor: "1000", grossMinor: "6000" }
    ]);
  });

  it("sums bigint strings without JavaScript Number precision loss", () => {
    const [czk] = totalsByCurrency([
      cost({ net_minor: "9007199254740993", vat_minor: "2100", gross_minor: "9007199254743093" }),
      cost({ invoice_id: "second", net_minor: "7", vat_minor: "1", gross_minor: "8" })
    ]);
    expect(czk.netMinor).toBe("9007199254741000");
    expect(czk.grossMinor).toBe("9007199254743101");
  });

  it("resolves the month in the location timezone", () => {
    expect(currentMonthForTimezone(new Date("2026-07-31T22:30:00Z"), "Europe/Prague")).toBe("2026-08");
  });
});
