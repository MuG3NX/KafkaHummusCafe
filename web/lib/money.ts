export type Currency = "CZK" | "EUR";

const MINOR_UNITS_PER_MAJOR = 100n;

export function parseMoneyToMinorUnits(input: string, currency: Currency): bigint {
  const normalized = input.trim().replace(/\s/g, "").replace(",", ".");
  if (!normalized || !/^\d+(\.\d{1,2})?$/.test(normalized)) {
    throw new Error(`Enter a valid ${currency} amount`);
  }
  const [major, fraction = ""] = normalized.split(".");
  return BigInt(major) * MINOR_UNITS_PER_MAJOR + BigInt(fraction.padEnd(2, "0") || "0");
}

export function formatMinorUnits(value: bigint | string | number, currency: Currency): string {
  const amount = typeof value === "bigint" ? value : BigInt(value);
  const sign = amount < 0n ? "-" : "";
  const absolute = amount < 0n ? -amount : amount;
  const major = absolute / MINOR_UNITS_PER_MAJOR;
  const minor = (absolute % MINOR_UNITS_PER_MAJOR).toString().padStart(2, "0");
  const numeric = Number(`${major}.${minor}`);
  return new Intl.NumberFormat(currency === "CZK" ? "cs-CZ" : "en-IE", {
    style: "currency",
    currency,
    minimumFractionDigits: minor === "00" ? 0 : 2,
    maximumFractionDigits: 2
  }).format(sign === "-" ? -numeric : numeric);
}
