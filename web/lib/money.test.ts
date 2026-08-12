import { describe, expect, it } from "vitest";
import { formatMinorUnits, parseMoneyToMinorUnits } from "./money";

describe("money", () => {
  it("parses decimal and comma input without floating point", () => {
    expect(parseMoneyToMinorUnits("1 234,50", "CZK")).toBe(123450n);
    expect(parseMoneyToMinorUnits("12.05", "EUR")).toBe(1205n);
  });

  it("rejects more than two fractional digits and negatives", () => {
    expect(() => parseMoneyToMinorUnits("12.345", "CZK")).toThrow();
    expect(() => parseMoneyToMinorUnits("-1", "CZK")).toThrow();
  });

  it("formats exact minor units", () => {
    expect(formatMinorUnits(123450n, "CZK")).toContain("1 234,50");
    expect(formatMinorUnits("1205", "EUR")).toContain("12.05");
    expect(formatMinorUnits("900719925474099300", "CZK")).toContain("9 007 199 254 740 993");
  });
});
