"use client";

import { useEffect, useMemo, useState } from "react";
import {
  amountMinorToInput,
  canConfirmCashExpense,
  cashExpenseAuditLabel,
  cashExpenseTotals,
  costsSectionsForRole,
  formatCashExpenseServiceDay,
  validateCashExpenseDraft,
  type CashExpenseAuditEvent,
  type CashExpenseDraft,
  type CashExpenseEntry,
  type CostsSection
} from "../lib/cash-expenses";
import { currentMonthForTimezone, totalCzkCosts, type ApprovedInvoiceCost } from "../lib/costs";
import { formatMinorUnits } from "../lib/money";
import { getSupabaseBrowserClient } from "../lib/supabase";
import type { Location } from "../lib/types";

type CostsAppProps = {
  onOpenRevenue: () => void;
  onOpenInvoices: () => void;
  onOpenShifts: () => void;
};

type CorrectionDraft = CashExpenseDraft & { reason: string };

const EMPTY_CAPTURE: CashExpenseDraft = { amount: "", description: "", businessDate: "" };
const EMPTY_CORRECTION: CorrectionDraft = { ...EMPTY_CAPTURE, reason: "" };

function firstRpcRow<T>(value: T[] | T | null): T | null {
  return Array.isArray(value) ? value[0] ?? null : value;
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeZone: "UTC" })
    .format(new Date(`${value}T00:00:00Z`));
}

function formatInstant(value: string): string {
  return new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" })
    .format(new Date(value));
}

export function CostsApp({ onOpenRevenue, onOpenInvoices, onOpenShifts }: CostsAppProps) {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [userId, setUserId] = useState<string | null>(null);
  const [role, setRole] = useState("");
  const [locations, setLocations] = useState<Location[]>([]);
  const [location, setLocation] = useState<Location | null>(null);
  const [section, setSection] = useState<CostsSection>("approved");
  const [month, setMonth] = useState("");
  const [rows, setRows] = useState<ApprovedInvoiceCost[]>([]);
  const [currentBusinessDate, setCurrentBusinessDate] = useState("");
  const [selectedBusinessDate, setSelectedBusinessDate] = useState("");
  const [cashRows, setCashRows] = useState<CashExpenseEntry[]>([]);
  const [auditEvents, setAuditEvents] = useState<CashExpenseAuditEvent[]>([]);
  const [actorNames, setActorNames] = useState<Record<string, string>>({});
  const [capture, setCapture] = useState<CashExpenseDraft>(EMPTY_CAPTURE);
  const [editing, setEditing] = useState<CashExpenseEntry | null>(null);
  const [correction, setCorrection] = useState<CorrectionDraft>(EMPTY_CORRECTION);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [openingId, setOpeningId] = useState<string | null>(null);
  const [error, setError] = useState("");

  const owner = role === "owner";
  const manager = role === "manager";
  const sections = costsSectionsForRole(role);

  async function loadApprovedCosts(targetLocation: Location, targetMonth: string) {
    if (!supabase) return;
    const result = await supabase.rpc("get_approved_invoice_costs", {
      p_location_id: targetLocation.id,
      p_month: `${targetMonth}-01`
    });
    if (result.error) throw result.error;
    setRows((result.data ?? []) as ApprovedInvoiceCost[]);
  }

  async function loadCashExpenses(targetLocation: Location, businessDate: string) {
    if (!supabase) return;
    const entriesResult = await supabase
      .from("cash_expense_entries")
      .select("*")
      .eq("location_id", targetLocation.id)
      .eq("business_date", businessDate)
      .order("captured_at", { ascending: false });
    if (entriesResult.error) throw entriesResult.error;
    const entries = (entriesResult.data ?? []) as CashExpenseEntry[];
    setCashRows(entries);

    if (entries.length === 0) {
      setAuditEvents([]);
      setActorNames({});
      return;
    }

    const eventsResult = await supabase
      .from("cash_expense_audit_events")
      .select("id, cash_expense_id, event_type, expense_version, actor_id, reason, created_at")
      .in("cash_expense_id", entries.map((entry) => entry.id))
      .order("created_at", { ascending: true });
    if (eventsResult.error) throw eventsResult.error;
    const events = (eventsResult.data ?? []) as CashExpenseAuditEvent[];
    setAuditEvents(events);

    const actorIds = [...new Set([
      ...entries.flatMap((entry) => [entry.captured_by, entry.confirmed_by].filter(Boolean) as string[]),
      ...events.map((event) => event.actor_id)
    ])];
    const profilesResult = await supabase.from("profiles").select("id, display_name").in("id", actorIds);
    if (profilesResult.error) throw profilesResult.error;
    setActorNames(Object.fromEntries(
      ((profilesResult.data ?? []) as Array<{ id: string; display_name: string | null }>)
        .map((profile) => [profile.id, profile.display_name?.trim() || "Team member"])
    ));
  }

  async function currentDateFor(targetLocation: Location): Promise<string> {
    if (!supabase) throw new Error("Supabase is not configured.");
    const result = await supabase.rpc("get_current_business_date", { target_location_id: targetLocation.id });
    if (result.error || !result.data) throw result.error ?? new Error("Could not resolve the current service day.");
    return String(result.data);
  }

  async function loadWorkspace() {
    if (!supabase) { setLoading(false); return; }
    setLoading(true); setError("");
    const { data: sessionData } = await supabase.auth.getSession();
    const currentUser = sessionData.session?.user;
    if (!currentUser) { setUserId(null); setLoading(false); return; }
    setUserId(currentUser.id);

    const membershipResult = await supabase
      .from("restaurant_memberships")
      .select("restaurant_id, role")
      .eq("user_id", currentUser.id)
      .limit(1)
      .maybeSingle();
    if (membershipResult.error || !membershipResult.data) {
      setError(membershipResult.error?.message ?? "Your account is not connected to a restaurant yet.");
      setLoading(false);
      return;
    }

    const nextRole = String(membershipResult.data.role);
    const nextSections = costsSectionsForRole(nextRole);
    setRole(nextRole);
    if (nextSections.length === 0) { setLoading(false); return; }
    setSection(nextRole === "manager" ? "cash" : "approved");

    const locationResult = await supabase
      .from("locations")
      .select("id, name, timezone")
      .eq("restaurant_id", membershipResult.data.restaurant_id)
      .order("name");
    if (locationResult.error || !locationResult.data?.length) {
      setError(locationResult.error?.message ?? "No authorized restaurant location is configured.");
      setLoading(false);
      return;
    }
    const availableLocations = locationResult.data as Location[];
    const currentLocation = availableLocations[0];
    setLocations(availableLocations);
    setLocation(currentLocation);

    try {
      const businessDate = await currentDateFor(currentLocation);
      const selectedMonth = month || currentMonthForTimezone(new Date(), currentLocation.timezone);
      setCurrentBusinessDate(businessDate);
      setSelectedBusinessDate(businessDate);
      setCapture({ ...EMPTY_CAPTURE, businessDate });
      setMonth(selectedMonth);
      if (nextRole === "owner") await loadApprovedCosts(currentLocation, selectedMonth);
      await loadCashExpenses(currentLocation, businessDate);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Costs could not be loaded.");
    }
    setLoading(false);
  }

  // Auth changes refresh the role-scoped Costs workspace.
  // eslint-disable-next-line react-hooks/exhaustive-deps, react-hooks/set-state-in-effect
  useEffect(() => { void loadWorkspace(); if (!supabase) return; const { data } = supabase.auth.onAuthStateChange(() => { void loadWorkspace(); }); return () => data.subscription.unsubscribe(); }, [supabase]);

  async function changeLocation(locationId: string) {
    const target = locations.find((candidate) => candidate.id === locationId);
    if (!target) return;
    setLoading(true); setError(""); setLocation(target); setEditing(null);
    try {
      const businessDate = await currentDateFor(target);
      const selectedMonth = month || currentMonthForTimezone(new Date(), target.timezone);
      setCurrentBusinessDate(businessDate);
      setSelectedBusinessDate(businessDate);
      setCapture({ ...EMPTY_CAPTURE, businessDate });
      if (owner) await loadApprovedCosts(target, selectedMonth);
      await loadCashExpenses(target, businessDate);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "The location could not be loaded.");
    }
    setLoading(false);
  }

  async function changeMonth(nextMonth: string) {
    setMonth(nextMonth);
    if (!location || !nextMonth || !owner) return;
    setLoading(true); setError("");
    try { await loadApprovedCosts(location, nextMonth); }
    catch (caught) { setRows([]); setError(caught instanceof Error ? caught.message : "Approved invoice costs could not be loaded."); }
    setLoading(false);
  }

  async function changeBusinessDate(nextDate: string) {
    if (!location || !nextDate) return;
    if (nextDate > currentBusinessDate) { setError("Cash expenses cannot use a future service day."); return; }
    setSelectedBusinessDate(nextDate);
    setCapture((current) => ({ ...current, businessDate: nextDate }));
    setEditing(null); setLoading(true); setError("");
    try { await loadCashExpenses(location, nextDate); }
    catch (caught) { setCashRows([]); setError(caught instanceof Error ? caught.message : "Cash expenses could not be loaded."); }
    setLoading(false);
  }

  async function captureExpense() {
    if (!supabase || !location || !navigator.onLine) { setError("Cash-expense capture needs a live connection and was not saved."); return; }
    setBusy(true); setError("");
    try {
      const parsed = validateCashExpenseDraft(capture, currentBusinessDate);
      const result = await supabase.rpc("capture_cash_expense", {
        p_expense_id: crypto.randomUUID(),
        p_location_id: location.id,
        p_business_date: parsed.businessDate,
        p_amount_czk_minor: parsed.amountMinor.toString(),
        p_description: parsed.description
      });
      if (result.error) throw result.error;
      const saved = firstRpcRow(result.data as CashExpenseEntry[] | CashExpenseEntry | null);
      if (!saved) throw new Error("The captured expense was not returned.");
      setCapture({ amount: "", description: "", businessDate: selectedBusinessDate });
      await loadCashExpenses(location, selectedBusinessDate);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Cash expense could not be captured.");
    }
    setBusy(false);
  }

  async function confirmExpense(entry: CashExpenseEntry) {
    if (!supabase || !location || !navigator.onLine) { setError("Confirmation needs a live connection and was not saved."); return; }
    setBusy(true); setError("");
    const result = await supabase.rpc("confirm_cash_expense", {
      p_expense_id: entry.id,
      p_expected_version: entry.version
    });
    if (result.error) setError(result.error.message);
    else await loadCashExpenses(location, selectedBusinessDate);
    setBusy(false);
  }

  function startCorrection(entry: CashExpenseEntry) {
    setEditing(entry);
    setCorrection({
      amount: amountMinorToInput(entry.amount_czk_minor),
      description: entry.description,
      businessDate: entry.business_date,
      reason: ""
    });
  }

  async function saveCorrection() {
    if (!supabase || !location || !editing || !navigator.onLine) { setError("Correction needs a live connection and was not saved."); return; }
    setBusy(true); setError("");
    try {
      const parsed = validateCashExpenseDraft(correction, currentBusinessDate);
      if (!correction.reason.trim()) throw new Error("Enter a correction reason.");
      const result = await supabase.rpc("correct_cash_expense", {
        p_expense_id: editing.id,
        p_expected_version: editing.version,
        p_business_date: parsed.businessDate,
        p_amount_czk_minor: parsed.amountMinor.toString(),
        p_description: parsed.description,
        p_reason: correction.reason
      });
      if (result.error) throw result.error;
      const movedToAnotherDay = parsed.businessDate !== selectedBusinessDate;
      setEditing(null); setCorrection(EMPTY_CORRECTION);
      await loadCashExpenses(location, selectedBusinessDate);
      if (movedToAnotherDay) setError(`Correction saved as Draft on service day ${parsed.businessDate}.`);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Cash expense correction could not be saved.");
    }
    setBusy(false);
  }

  async function openOriginal(row: ApprovedInvoiceCost) {
    if (!supabase) return;
    setOpeningId(row.invoice_id); setError("");
    const result = await supabase.storage.from("invoice-originals").createSignedUrl(row.storage_path, 3600);
    setOpeningId(null);
    if (result.error || !result.data?.signedUrl) { setError(result.error?.message ?? "The private original could not be opened."); return; }
    window.open(result.data.signedUrl, "_blank", "noopener,noreferrer");
  }

  function actorName(actorId: string | null): string {
    if (!actorId) return "—";
    if (actorId === userId) return actorNames[actorId] || "You";
    return actorNames[actorId] || "Team member";
  }

  if (!userId) return <main className="app-shell"><section className="card auth-card"><div className="kicker">KAFKA</div><h1>Costs</h1><p className="sub">Open Revenue first to sign in.</p><button className="btn" onClick={onOpenRevenue}>Go to sign in</button></section></main>;
  if (loading && !location) return <main className="app-shell"><div className="kicker">KAFKA</div><h1>Costs</h1><p className="muted">Loading costs…</p></main>;
  if (!owner && !manager) return <main className="app-shell"><section className="card auth-card"><div className="kicker">RESTRICTED</div><h1>Costs</h1><p className="sub">Cash expenses are available only to an owner or assigned manager.</p><button className="btn" onClick={onOpenRevenue}>Back to Revenue</button></section></main>;

  const total = totalCzkCosts(rows);
  const capturedTotals = cashExpenseTotals(cashRows);

  return <main className="app-shell">
    <div className="module-nav module-nav-four"><button onClick={onOpenRevenue}>Revenue</button><button onClick={onOpenInvoices}>Invoices</button><button className="active">Costs</button><button onClick={onOpenShifts}>Shifts</button></div>
    <header className="top"><div><div className="kicker">KAFKA</div><h1>Costs</h1></div><button className="avatar" aria-label="Sign out" onClick={() => { void supabase?.auth.signOut(); }}>K</button></header>
    <p className="muted">{location?.name} · {owner ? "owner" : "assigned manager"}</p>
    {owner && sections.length > 1 && <div className="costs-section-nav" aria-label="Costs section"><button className={section === "approved" ? "active" : ""} onClick={() => setSection("approved")}>Approved invoices</button><button className={section === "cash" ? "active" : ""} onClick={() => setSection("cash")}>Cash expenses</button></div>}
    {locations.length > 1 && <section className="card compact-card"><label className="field"><span>Location</span><div className="input-wrap"><select value={location?.id ?? ""} onChange={(event) => void changeLocation(event.target.value)}>{locations.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></div></label></section>}
    {error && <p className="error" role="alert">{error}</p>}

    {owner && section === "approved" && <>
      <div className="banner">● Based only on human-approved CZK invoice records</div>
      <section className="card"><div className="kicker">REPORTING MONTH</div><label className="field"><span>Month</span><div className="input-wrap"><input aria-label="Reporting month" type="month" value={month} onChange={(event) => void changeMonth(event.target.value)} /></div></label><p className="fine">Operational view—not an accounting or VAT return.</p></section>
      <section className="card"><div className="row"><div><div className="kicker">APPROVED INVOICES</div><h2>{total.count} invoice{total.count === 1 ? "" : "s"}</h2></div>{loading && <span className="muted">Loading…</span>}</div><div className="cost-total"><div className="kicker">CZK TOTALS</div><div><span>Net</span><b>{formatMinorUnits(total.netMinor, "CZK")}</b><span>VAT</span><b>{formatMinorUnits(total.vatMinor, "CZK")}</b><span>Gross</span><b>{formatMinorUnits(total.grossMinor, "CZK")}</b></div></div></section>
      <section className="card"><div className="kicker">COST REGISTER</div><h2>{month || "Selected month"}</h2>{rows.length === 0 && !loading ? <p className="muted">No approved CZK invoices for this month.</p> : rows.map((row) => <article className="cost-row" key={row.invoice_id}><div className="cost-row-head"><div><strong>{row.supplier_name}</strong><small>{row.invoice_number} · {formatDate(row.issue_date)}</small>{row.due_date && <small>Due {formatDate(row.due_date)}</small>}</div><b>{formatMinorUnits(row.gross_minor, "CZK")}</b></div><div className="cost-row-money"><span>Net {formatMinorUnits(row.net_minor, "CZK")}</span><span>VAT {formatMinorUnits(row.vat_minor, "CZK")}</span><span>Gross {formatMinorUnits(row.gross_minor, "CZK")}</span></div><button className="btn secondary small" disabled={openingId === row.invoice_id} onClick={() => void openOriginal(row)}>{openingId === row.invoice_id ? "Opening…" : "Open private original"}</button></article>)}</section>
    </>}

    {section === "cash" && <>
      <div className="banner">● Each cash expense keeps an internal evidence record with the amount, service day, reason, actor and timestamp.</div>
      <section className="card"><div className="kicker">SERVICE DAY</div><h2>{selectedBusinessDate ? formatCashExpenseServiceDay(selectedBusinessDate) : "Choose a day"}</h2><label className="field"><span>When cash left the register</span><div className="input-wrap"><input aria-label="Cash expense service day" type="date" max={currentBusinessDate} value={selectedBusinessDate} onChange={(event) => void changeBusinessDate(event.target.value)} /></div></label><p className="fine">Current and historical service days are allowed. Future days are blocked by the database.</p></section>
      <section className="card"><div className="kicker">CAPTURE EVIDENCE</div><h2>Cash expense</h2><label className="field"><span>Amount</span><div className="input-wrap"><input inputMode="decimal" type="text" placeholder="0" value={capture.amount} onChange={(event) => setCapture((current) => ({ ...current, amount: event.target.value }))} /><b>CZK</b></div></label><label className="field"><span>Description / reason</span><textarea value={capture.description} onChange={(event) => setCapture((current) => ({ ...current, description: event.target.value }))} /></label><button className="btn" disabled={busy || !capture.amount.trim() || !capture.description.trim()} onClick={() => void captureExpense()}>{busy ? "Saving…" : "Capture expense"}</button><p className="fine">This creates Draft internal evidence. It does not change the daily Revenue total.</p></section>
      <section className="card"><div className="kicker">CAPTURED ITEMS ONLY</div><h2>{cashRows.length} item{cashRows.length === 1 ? "" : "s"}</h2><div className="total-grid"><div className="metric"><span>Confirmed captured total</span><strong>{formatMinorUnits(capturedTotals.confirmedMinor, "CZK")}</strong></div><div className="metric"><span>Draft captured total</span><strong>{formatMinorUnits(capturedTotals.draftMinor, "CZK")}</strong></div></div><p className="fine">These totals are individual captured records only. No reconciliation is performed.</p></section>
      <section className="card"><div className="kicker">CASH EXPENSES</div><h2>{selectedBusinessDate ? formatCashExpenseServiceDay(selectedBusinessDate) : "Selected day"}</h2>{cashRows.length === 0 && !loading ? <p className="muted">No cash expenses captured for this service day.</p> : cashRows.map((entry) => {
        const events = auditEvents.filter((event) => event.cash_expense_id === entry.id);
        return <article className="cash-expense-row" key={entry.id}>
          <div className="cost-row-head"><div><span className={`status-pill ${entry.status}`}>{entry.status === "confirmed" ? "Confirmed" : "Draft"}</span><strong>{entry.description}</strong><small>Service day {entry.business_date} · version {entry.version}</small></div><b>{formatMinorUnits(entry.amount_czk_minor, "CZK")}</b></div>
          <div className="cash-meta"><span>Captured by {actorName(entry.captured_by)}</span><span>{formatInstant(entry.captured_at)}</span>{entry.confirmed_at && <><span>Confirmed by {actorName(entry.confirmed_by)}</span><span>{formatInstant(entry.confirmed_at)}</span></>}</div>
          {canConfirmCashExpense(entry.status) && <button className="btn" disabled={busy} onClick={() => void confirmExpense(entry)}>{busy ? "Saving…" : "Confirm expense"}</button>}
          <button className="btn secondary small" disabled={busy} onClick={() => startCorrection(entry)}>Correct</button>
          <details className="audit-history"><summary>History · {events.length} event{events.length === 1 ? "" : "s"}</summary>{events.map((event) => <div className="audit-event" key={event.id}><strong>{cashExpenseAuditLabel(event)}</strong><span>{actorName(event.actor_id)} · {formatInstant(event.created_at)}</span>{event.reason && <small>Reason: {event.reason}</small>}</div>)}</details>
        </article>;
      })}</section>
      {editing && <section className="card"><div className="kicker">AUDITED CORRECTION</div><h2>Correct cash expense</h2><p className="sub">Saving returns this evidence to Draft and clears its prior confirmation.</p><label className="field"><span>Service day</span><div className="input-wrap"><input type="date" max={currentBusinessDate} value={correction.businessDate} onChange={(event) => setCorrection((current) => ({ ...current, businessDate: event.target.value }))} /></div></label><label className="field"><span>Amount</span><div className="input-wrap"><input inputMode="decimal" type="text" value={correction.amount} onChange={(event) => setCorrection((current) => ({ ...current, amount: event.target.value }))} /><b>CZK</b></div></label><label className="field"><span>Description / reason</span><textarea value={correction.description} onChange={(event) => setCorrection((current) => ({ ...current, description: event.target.value }))} /></label><label className="field"><span>Correction reason (required)</span><textarea value={correction.reason} onChange={(event) => setCorrection((current) => ({ ...current, reason: event.target.value }))} /></label><button className="btn" disabled={busy || !correction.reason.trim() || !correction.description.trim() || !correction.amount.trim()} onClick={() => void saveCorrection()}>{busy ? "Saving…" : "Save audited correction"}</button><button className="btn secondary" disabled={busy} onClick={() => { setEditing(null); setCorrection(EMPTY_CORRECTION); }}>Cancel</button></section>}
    </>}
  </main>;
}
