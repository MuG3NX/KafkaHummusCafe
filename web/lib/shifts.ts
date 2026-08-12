export type Shift = {
  id: string;
  location_id: string;
  service_day_id: string;
  membership_id: string;
  business_date: string;
  started_at: string;
  ended_at: string | null;
  version: number;
  created_at: string;
  updated_at: string;
};

export type ShiftTotals = { minutes: number; count: number };

export function shiftDurationMinutes(shift: Pick<Shift, "started_at" | "ended_at">): number {
  if (!shift.ended_at) return 0;
  return Math.max(0, Math.round((Date.parse(shift.ended_at) - Date.parse(shift.started_at)) / 60000));
}

export function formatDuration(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  if (hours === 0) return `${remainder} min`;
  if (remainder === 0) return `${hours} h`;
  return `${hours} h ${remainder} min`;
}

export function formatShiftTime(instant: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: timezone,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  }).format(new Date(instant));
}

export function formatShiftDate(date: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    timeZone: "UTC"
  }).format(new Date(`${date}T12:00:00Z`));
}

function dateValue(date: string): number {
  return Date.parse(`${date}T12:00:00Z`);
}

function startOfIsoWeek(date: string): number {
  const value = new Date(dateValue(date));
  const day = value.getUTCDay() || 7;
  value.setUTCDate(value.getUTCDate() - day + 1);
  return Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate());
}

export function isDateInPeriod(date: string, currentBusinessDate: string, period: "week" | "month"): boolean {
  if (period === "month") return date.slice(0, 7) === currentBusinessDate.slice(0, 7);
  const start = startOfIsoWeek(currentBusinessDate);
  return dateValue(date) >= start && dateValue(date) < start + 7 * 24 * 60 * 60 * 1000;
}

export function totalForPeriod(shifts: Shift[], currentBusinessDate: string, period: "week" | "month"): ShiftTotals {
  const completed = shifts.filter((shift) => shift.ended_at && isDateInPeriod(shift.business_date, currentBusinessDate, period));
  return {
    minutes: completed.reduce((total, shift) => total + shiftDurationMinutes(shift), 0),
    count: completed.length
  };
}

export function totalForBusinessDate(shifts: Shift[], businessDate: string): ShiftTotals {
  const completed = shifts.filter((shift) => shift.ended_at && shift.business_date === businessDate);
  return {
    minutes: completed.reduce((total, shift) => total + shiftDurationMinutes(shift), 0),
    count: completed.length
  };
}

function wallClockMilliseconds(value: string): number {
  const [date, time] = value.split("T");
  const [year, month, day] = date.split("-").map(Number);
  const [hour, minute] = time.split(":").map(Number);
  return Date.UTC(year, month - 1, day, hour, minute);
}

function wallClockValue(instant: Date, timezone: string): number {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  }).formatToParts(instant);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return Date.UTC(Number(values.year), Number(values.month) - 1, Number(values.day), Number(values.hour), Number(values.minute));
}

export function instantToLocalDateTime(instant: string | null, timezone: string): string {
  if (!instant) return "";
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  }).formatToParts(new Date(instant));
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}T${values.hour}:${values.minute}`;
}

export function localDateTimeToInstant(value: string, timezone: string): string {
  let candidate = new Date(wallClockMilliseconds(value));
  const target = wallClockMilliseconds(value);
  for (let attempt = 0; attempt < 3; attempt += 1) {
    candidate = new Date(candidate.getTime() + target - wallClockValue(candidate, timezone));
  }
  return candidate.toISOString();
}
