import { describe, expect, it } from "vitest";
import { elapsedMinutesSince, formatDuration, instantToLocalDateTime, isDateInPeriod, localDateTimeToInstant, shiftDurationMinutes, totalForBusinessDate, totalForPeriod, type Shift } from "./shifts";

const closedShift = (business_date: string, started_at: string, ended_at: string): Shift => ({
  id: business_date,
  location_id: "location",
  service_day_id: "service-day",
  membership_id: "membership",
  business_date,
  started_at,
  ended_at,
  version: 1,
  created_at: started_at,
  updated_at: ended_at
});

describe("shift calculations", () => {
  it("derives duration from timestamps and formats it", () => {
    const shift = closedShift("2026-08-12", "2026-08-12T21:00:00.000Z", "2026-08-13T00:15:00.000Z");
    expect(shiftDurationMinutes(shift)).toBe(195);
    expect(formatDuration(195)).toBe("3 h 15 min");
  });

  it("derives display-only elapsed time from the authoritative start", () => {
    expect(elapsedMinutesSince("2026-08-12T23:00:00.000Z", Date.parse("2026-08-12T23:02:30.000Z"))).toBe(2);
  });

  it("groups totals by explicit business date", () => {
    const shifts = [
      closedShift("2026-07-31", "2026-07-31T08:00:00.000Z", "2026-07-31T10:00:00.000Z"),
      closedShift("2026-08-12", "2026-08-12T08:00:00.000Z", "2026-08-12T11:30:00.000Z"),
      closedShift("2026-08-12", "2026-08-12T12:00:00.000Z", "2026-08-12T13:00:00.000Z"),
      closedShift("2026-08-12", "2026-08-12T14:00:00.000Z", "2026-08-12T15:00:00.000Z")
    ];
    expect(isDateInPeriod("2026-08-10", "2026-08-12", "week")).toBe(true);
    expect(totalForPeriod(shifts, "2026-08-12", "week")).toEqual({ minutes: 330, count: 3 });
    expect(totalForPeriod(shifts, "2026-08-12", "month")).toEqual({ minutes: 330, count: 3 });
    expect(totalForBusinessDate(shifts, "2026-08-12")).toEqual({ minutes: 330, count: 3 });
  });

  it("round-trips Prague correction input without using device time", () => {
    const instant = localDateTimeToInstant("2026-08-13T01:30", "Europe/Prague");
    expect(instant).toBe("2026-08-12T23:30:00.000Z");
    expect(instantToLocalDateTime(instant, "Europe/Prague")).toBe("2026-08-13T01:30");
  });
});
