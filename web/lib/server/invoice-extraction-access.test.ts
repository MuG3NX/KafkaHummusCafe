import { describe, expect, it } from "vitest";
import { canRequestInitialExtraction } from "./invoice-extraction-access";

const base = {
  callerId: "uploader",
  uploadedBy: "uploader",
  status: "needs_review" as const,
  isLocationOwner: false,
  hasDraft: false
};

describe("initial invoice extraction access", () => {
  it("allows the original uploader for the first review draft", () => {
    expect(canRequestInitialExtraction(base)).toBe(true);
  });

  it("allows a location owner for the first review draft", () => {
    expect(canRequestInitialExtraction({ ...base, callerId: "owner", isLocationOwner: true })).toBe(true);
  });

  it("denies another location reader", () => {
    expect(canRequestInitialExtraction({ ...base, callerId: "employee" })).toBe(false);
  });

  it("denies a second extraction when a draft already exists", () => {
    expect(canRequestInitialExtraction({ ...base, hasDraft: true })).toBe(false);
  });

  it("denies every non-review lifecycle state", () => {
    for (const status of ["uploading", "approved", "rejected", "abandoned"] as const) {
      expect(canRequestInitialExtraction({ ...base, status })).toBe(false);
    }
  });
});
