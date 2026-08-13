import { describe, expect, it } from "vitest";
import { canApproveInvoice } from "./invoice-review";

describe("invoice approval UI guard", () => {
  it("requires a persisted current draft and clean form", () => {
    expect(canApproveInvoice("needs_review", 4, 4, false, false)).toBe(true);
    expect(canApproveInvoice("needs_review", 4, 4, true, false)).toBe(false);
    expect(canApproveInvoice("needs_review", null, 4, false, false)).toBe(false);
    expect(canApproveInvoice("needs_review", 4, null, false, false)).toBe(false);
    expect(canApproveInvoice("uploading", null, 1, false, false)).toBe(false);
    expect(canApproveInvoice("abandoned", null, 2, false, false)).toBe(false);
  });
});
