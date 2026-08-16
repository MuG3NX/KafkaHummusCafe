export type Currency = "CZK" | "EUR" | "USD" | "GBP";

const MINOR_UNITS_PER_MAJOR = 100n;

const CURRENCY_LOCALE: Record<Currency, string> = {
  CZK: "cs-CZ",
  EUR: "en-IE",
  USD: "en-US",
  GBP: "en-GB"
};

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
  const locale = CURRENCY_LOCALE[currency];
  const wholeParts = new Intl.NumberFormat(locale, {
    style: "currency",
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
  }).formatToParts(major);
  if (minor === "00") return sign + wholeParts.map((part) => part.value).join("");

  const currencyIndex = wholeParts.findIndex((part) => part.type === "currency");
  const firstNumberIndex = wholeParts.findIndex((part) => part.type === "integer");
  const lastNumberIndex = wholeParts.reduce((last, part, index) => part.type === "integer" || part.type === "group" ? index : last, -1);
  let insertAt = currencyIndex >= 0 && currencyIndex < firstNumberIndex ? lastNumberIndex + 1 : currencyIndex >= 0 ? currencyIndex : wholeParts.length;
  if (currencyIndex > lastNumberIndex) {
    while (insertAt > 0 && wholeParts[insertAt - 1]?.type === "literal") insertAt -= 1;
  }
  const decimalSeparator = new Intl.NumberFormat(locale, { minimumFractionDigits: 1, maximumFractionDigits: 1 }).formatToParts(1.1).find((part) => part.type === "decimal")?.value ?? ".";
  const partsWithFraction = [...wholeParts.slice(0, insertAt), { type: "decimal", value: decimalSeparator }, { type: "fraction", value: minor }, ...wholeParts.slice(insertAt)];
  return sign + partsWithFraction.map((part) => part.value).join("");
}
