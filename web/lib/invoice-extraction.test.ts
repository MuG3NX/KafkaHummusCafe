import { describe, expect, it } from "vitest";
import { emptyInvoiceExtractionDraft } from "./invoice-extraction";

describe("invoice extraction draft shape", () => {
  it("starts empty and unapproved", () => {
    const draft = emptyInvoiceExtractionDraft();
    expect(draft.supplierName).toBe("");
    expect(draft.validationErrors).toEqual([]);
  });
});
