import { describe, expect, it } from "vitest";
import { businessDateForTimezone } from "./business-date";

describe("businessDateForTimezone", () => {
  it("uses the location timezone instead of the device timezone", () => {
    expect(businessDateForTimezone(new Date("2026-08-11T22:30:00.000Z"), "Europe/Prague")).toBe("2026-08-12");
    expect(businessDateForTimezone(new Date("2026-08-11T22:30:00.000Z"), "America/New_York")).toBe("2026-08-11");
  });
});
