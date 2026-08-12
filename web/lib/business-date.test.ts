import { describe, expect, it } from "vitest";
import { businessDateForTimezone } from "./business-date";

describe("businessDateForTimezone", () => {
  it("uses the location timezone instead of the device timezone", () => {
    const instant = new Date("2026-08-12T03:30:00.000Z");
    expect(businessDateForTimezone(instant, "Europe/Prague")).toBe("2026-08-12");
    expect(businessDateForTimezone(instant, "America/New_York")).toBe("2026-08-11");
  });

  it("assigns the local pre-05:00 window to the previous service day", () => {
    expect(businessDateForTimezone(new Date("2026-08-12T23:30:00.000Z"), "Europe/Prague")).toBe("2026-08-12");
    expect(businessDateForTimezone(new Date("2026-08-13T03:00:00.000Z"), "Europe/Prague")).toBe("2026-08-13");
    expect(businessDateForTimezone(new Date("2026-08-13T03:00:01.000Z"), "Europe/Prague")).toBe("2026-08-13");
  });

  it("applies the same cutoff using another location timezone", () => {
    expect(businessDateForTimezone(new Date("2026-08-13T08:59:59.000Z"), "America/New_York")).toBe("2026-08-12");
    expect(businessDateForTimezone(new Date("2026-08-13T09:00:00.000Z"), "America/New_York")).toBe("2026-08-13");
  });
});
