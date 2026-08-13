import { describe, expect, it } from "vitest";
import { noProviderInvoiceAdapter } from "./invoice-extraction";

describe("invoice extraction adapter boundary", () => {
  it("returns an explicit untrusted empty draft without calling a vendor", async () => {
    const draft = await noProviderInvoiceAdapter.extract({ fileName: "invoice.pdf", mimeType: "application/pdf" });
    expect(noProviderInvoiceAdapter.key).toBe("none");
    expect(draft.supplierName).toBe("");
    expect(draft.validationErrors[0]).toContain("No OCR provider configured");
  });
});
