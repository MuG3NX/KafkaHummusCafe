"use client";

import { useEffect, useMemo, useState } from "react";
import {
  canFinalizeClose,
  closingWarnings,
  createOrReuseClosingAttempt,
  createOrReuseHandoffNoteAttempt,
  validateClosingDraft,
  type ClosingAttempt,
  type ClosingDraft,
  type HandoffNoteAttempt,
  type ServiceDayCloseState
} from "../lib/closing";
import { formatMinorUnits } from "../lib/money";
import { getSupabaseBrowserClient } from "../lib/supabase";
import type { Location } from "../lib/types";

type ClosingPanelProps = {
  location: Location;
  businessDate: string;
  owner: boolean;
  revenueSignal: string;
};

const EMPTY_DRAFT: ClosingDraft = {
  usd: "",
  gbp: "",
  physicalEur: "",
  physicalUsd: "",
  physicalGbp: "",
  note: ""
};

function firstRpcRow<T>(value: T[] | T | null): T | null {
  return Array.isArray(value) ? value[0] ?? null : value;
}

function minorToInput(value: string | null): string {
  if (value === null) return "";
  const minor = BigInt(value);
  const sign = minor < 0n ? "-" : "";
  const absolute = minor < 0n ? -minor : minor;
  const whole = absolute / 100n;
  const fraction = (absolute % 100n).toString().padStart(2, "0");
  return fraction === "00" ? `${sign}${whole}` : `${sign}${whole}.${fraction}`;
}

function formatInstant(value: string | null): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

function MoneyInput({ label, currency, value, disabled, onChange }: {
  label: string;
  currency: "EUR" | "USD" | "GBP";
  value: string;
  disabled?: boolean;
  onChange: (value: string) => void;
}) {
  return <label className="field"><span>{label}</span><div className="input-wrap"><input disabled={disabled} inputMode="decimal" type="text" placeholder="0" value={value} onChange={(event) => onChange(event.target.value)} /><b>{currency}</b></div></label>;
}

export function ClosingPanel({ location, businessDate, owner, revenueSignal }: ClosingPanelProps) {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [allowed, setAllowed] = useState<boolean | null>(null);
  const [state, setState] = useState<ServiceDayCloseState | null>(null);
  const [draft, setDraft] = useState<ClosingDraft>(EMPTY_DRAFT);
  const [reviewing, setReviewing] = useState(false);
  const [pendingClose, setPendingClose] = useState<ClosingAttempt | null>(null);
  const [editingClose, setEditingClose] = useState(false);
  const [correctionReason, setCorrectionReason] = useState("");
  const [handoffNote, setHandoffNote] = useState("");
  const [pendingHandoff, setPendingHandoff] = useState<HandoffNoteAttempt | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  async function loadState(): Promise<ServiceDayCloseState | null> {
    if (!supabase || !businessDate) return null;
    const access = await supabase.rpc("can_close_service_day", { target_location_id: location.id });
    if (access.error) throw access.error;
    if (!access.data) {
      setAllowed(false);
      setState(null);
      return null;
    }
    setAllowed(true);
    const result = await supabase.rpc("get_service_day_close_state", {
      p_location_id: location.id,
      p_business_date: businessDate
    });
    if (result.error) throw result.error;
    const next = firstRpcRow(result.data as ServiceDayCloseState[] | ServiceDayCloseState | null);
    if (!next) throw new Error("Closing state was not returned.");
    setState(next);
    return next;
  }

  useEffect(() => {
    let active = true;
    void (async () => {
      setError("");
      try {
        const next = await loadState();
        if (active && next && !next.is_closed && !pendingClose) setDraft(EMPTY_DRAFT);
      } catch (caught) {
        if (active) setError(caught instanceof Error ? caught.message : "Closing state could not be loaded.");
      }
    })();
    return () => { active = false; };
    // Revenue signal intentionally refreshes closing readiness after submit/correction.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [supabase, location.id, businessDate, revenueSignal]);

  function updateDraft<K extends keyof ClosingDraft>(key: K, value: ClosingDraft[K]) {
    if (pendingClose) return;
    setDraft((current) => ({ ...current, [key]: value }));
  }

  async function closeDay() {
    if (!supabase || !state || !navigator.onLine) {
      setError("Closing needs a live connection and was not saved.");
      return;
    }
    setBusy(true); setError(""); setNotice("");
    let attempt = pendingClose;
    try {
      const parsed = validateClosingDraft(draft);
      attempt = createOrReuseClosingAttempt(pendingClose, state, parsed, () => crypto.randomUUID());
      setPendingClose(attempt);
      const result = await supabase.rpc("close_service_day", {
        p_closure_id: attempt.id,
        p_location_id: attempt.locationId,
        p_business_date: attempt.businessDate,
        p_expected_revenue_entry_id: attempt.revenueEntryId,
        p_expected_revenue_entry_version: attempt.revenueEntryVersion,
        p_usd_minor: attempt.usdMinor,
        p_gbp_minor: attempt.gbpMinor,
        p_physical_eur_minor: attempt.physicalEurMinor,
        p_physical_usd_minor: attempt.physicalUsdMinor,
        p_physical_gbp_minor: attempt.physicalGbpMinor,
        p_note: attempt.note
      });
      if (result.error) throw result.error;
      const saved = firstRpcRow(result.data as unknown[] | unknown | null);
      if (!saved) throw new Error("The completed close was not returned.");
      setPendingClose(null);
      setReviewing(false);
      setDraft(EMPTY_DRAFT);
      await loadState();
      setNotice("Service day closed.");
    } catch (caught) {
      let authoritative: ServiceDayCloseState | null = null;
      try { authoritative = await loadState(); } catch { /* best effort */ }
      if (attempt && authoritative?.closure_id === attempt.id) {
        setPendingClose(null);
        setReviewing(false);
        setDraft(EMPTY_DRAFT);
        setNotice("Service day closed.");
      } else {
        if (attempt) setPendingClose(attempt);
        const detail = caught instanceof Error ? caught.message : "The close response was unavailable.";
        setError(`Closing could not be confirmed. Retry will reuse the same close identity and Revenue snapshot. ${detail}`);
      }
    } finally {
      setBusy(false);
    }
  }

  function beginCorrection() {
    if (!state?.is_closed) return;
    setDraft({
      usd: minorToInput(state.usd_minor),
      gbp: minorToInput(state.gbp_minor),
      physicalEur: minorToInput(state.physical_eur_minor),
      physicalUsd: minorToInput(state.physical_usd_minor),
      physicalGbp: minorToInput(state.physical_gbp_minor),
      note: state.closure_note ?? ""
    });
    setCorrectionReason("");
    setEditingClose(true);
    setError(""); setNotice("");
  }

  async function saveCorrection() {
    if (!supabase || !state?.closure_id || state.closure_version === null || !state.revenue_entry_id || state.revenue_entry_version === null || !navigator.onLine) {
      setError("Owner correction needs a live current closing/Revenue snapshot.");
      return;
    }
    const reason = correctionReason.trim();
    if (!reason) { setError("Enter a correction reason."); return; }
    setBusy(true); setError(""); setNotice("");
    const expectedVersion = state.closure_version;
    try {
      const parsed = validateClosingDraft(draft);
      const result = await supabase.rpc("correct_service_day_closure", {
        p_closure_id: state.closure_id,
        p_expected_version: expectedVersion,
        p_expected_revenue_entry_id: state.revenue_entry_id,
        p_expected_revenue_entry_version: state.revenue_entry_version,
        p_usd_minor: parsed.usdMinor.toString(),
        p_gbp_minor: parsed.gbpMinor.toString(),
        p_physical_eur_minor: parsed.physicalEurMinor.toString(),
        p_physical_usd_minor: parsed.physicalUsdMinor.toString(),
        p_physical_gbp_minor: parsed.physicalGbpMinor.toString(),
        p_note: parsed.note,
        p_reason: reason
      });
      if (result.error) throw result.error;
      setEditingClose(false);
      setCorrectionReason("");
      setDraft(EMPTY_DRAFT);
      await loadState();
      setNotice("Audited closing correction saved.");
    } catch (caught) {
      try { await loadState(); } catch { /* best effort */ }
      setEditingClose(false);
      setCorrectionReason("");
      setDraft(EMPTY_DRAFT);
      setError(caught instanceof Error ? `Correction could not be confirmed. Current state was reloaded; reopen before retrying. ${caught.message}` : "Correction could not be confirmed. Current state was reloaded; reopen before retrying.");
    } finally {
      setBusy(false);
    }
  }

  async function addHandoffNote() {
    if (!supabase || !state || !navigator.onLine) { setError("Handoff notes need a live connection."); return; }
    setBusy(true); setError(""); setNotice("");
    let attempt = pendingHandoff;
    try {
      attempt = createOrReuseHandoffNoteAttempt(pendingHandoff, location.id, businessDate, handoffNote, () => crypto.randomUUID());
      setPendingHandoff(attempt);
      const result = await supabase.rpc("add_service_day_handoff_note", {
        p_note_id: attempt.id,
        p_location_id: attempt.locationId,
        p_business_date: attempt.businessDate,
        p_note: attempt.note
      });
      if (result.error) throw result.error;
      setPendingHandoff(null);
      setHandoffNote("");
      await loadState();
      setNotice("Handoff note added.");
    } catch (caught) {
      if (attempt) {
        const persisted = await supabase.from("service_day_handoff_notes").select("id").eq("id", attempt.id).maybeSingle();
        if (!persisted.error && persisted.data?.id === attempt.id) {
          setPendingHandoff(null);
          setHandoffNote("");
          try { await loadState(); } catch { /* note itself is committed */ }
          setNotice("Handoff note added.");
          setBusy(false);
          return;
        }
        setPendingHandoff(attempt);
      }
      const detail = caught instanceof Error ? caught.message : "The note response was unavailable.";
      setError(`Handoff note could not be confirmed. Retry will reuse the same note identity. ${detail}`);
    } finally {
      setBusy(false);
    }
  }

  if (allowed === false || !state) return error ? <section className="card"><div className="kicker">CLOSING</div><p className="error" role="alert">{error}</p></section> : null;

  const warnings = closingWarnings(state);
  const canClose = canFinalizeClose(state);

  return <>
    {notice && <div className="banner">● {notice}</div>}
    {error && <p className="error" role="alert">{error}</p>}

    <section className="card">
      <div className="row"><div><div className="kicker">SERVICE DAY</div><h2>{state.is_closed ? "Closing complete" : state.has_revenue ? "Closing readiness" : "Closing not ready"}</h2></div>{state.is_closed && <span className="status-pill confirmed">Closed</span>}</div>
      {!state.has_revenue ? <p className="sub">Submit Revenue first. Closing never creates or guesses Revenue values.</p> : <>
        <div className="sum"><span>Total revenue</span><strong>{formatMinorUnits(state.total_revenue_czk_minor!, "CZK")}</strong><span>Card</span><strong>{formatMinorUnits(state.card_czk_minor!, "CZK")}</strong><span>Cash</span><strong>{formatMinorUnits(state.cash_czk_minor!, "CZK")}</strong><span>Register expenses</span><strong>{formatMinorUnits(state.cash_register_expenses_czk_minor!, "CZK")}</strong><span>EUR counted</span><strong>{formatMinorUnits(state.euros_minor!, "EUR")}</strong><span>Physical CZK handover</span><strong>{formatMinorUnits(state.physical_cash_handed_over_czk_minor!, "CZK")}</strong></div>
        <p className="fine">These values come from the exact current M1 Revenue entry/version. Closing does not duplicate or rewrite them.</p>
      </>}
      {warnings.length === 0 && state.has_revenue && <div className="banner">● No current closing warnings.</div>}
      {warnings.map((warning) => <p className="fine" key={warning.key}>⚠ {warning.message}</p>)}
      {state.current_cash_expense_difference_minor !== null && <p className="fine">Cash-expense difference: {formatMinorUnits(state.current_cash_expense_difference_minor, "CZK")}{state.current_cash_expense_acknowledgment_id ? ` · acknowledged${state.current_cash_expense_acknowledgment_reason ? `: ${state.current_cash_expense_acknowledgment_reason}` : ""}` : ""}.</p>}
    </section>

    <section className="card">
      <div className="kicker">MANAGER HANDOFF</div><h2>Note for the day</h2>
      {state.latest_handoff_note ? <><p className="sub">{state.latest_handoff_note}</p><p className="fine">Latest · {formatInstant(state.latest_handoff_note_at)} · {state.handoff_note_count} total</p></> : <p className="muted">No handoff note yet.</p>}
      <label className="field"><span>Add note</span><textarea disabled={Boolean(pendingHandoff)} value={handoffNote} onChange={(event) => { if (!pendingHandoff) setHandoffNote(event.target.value); }} /></label>
      <button className="btn secondary" disabled={busy || (!pendingHandoff && !handoffNote.trim())} onClick={() => void addHandoffNote()}>{busy ? "Saving…" : pendingHandoff ? "Retry same note" : "Add handoff note"}</button>
      {pendingHandoff && <p className="fine">Retry is locked to the same note identity and text.</p>}
    </section>

    {!state.is_closed && state.has_revenue && <section className="card">
      <div className="kicker">PHYSICAL CLOSE</div><h2>Foreign cash & handover</h2><p className="sub">Enter what was actually counted/handed over. No FX conversion becomes authoritative.</p>
      {!reviewing ? <>
        <MoneyInput label="USD counted" currency="USD" value={draft.usd} disabled={Boolean(pendingClose)} onChange={(value) => updateDraft("usd", value)} />
        <MoneyInput label="GBP counted" currency="GBP" value={draft.gbp} disabled={Boolean(pendingClose)} onChange={(value) => updateDraft("gbp", value)} />
        <MoneyInput label="Physical EUR handed over" currency="EUR" value={draft.physicalEur} disabled={Boolean(pendingClose)} onChange={(value) => updateDraft("physicalEur", value)} />
        <MoneyInput label="Physical USD handed over" currency="USD" value={draft.physicalUsd} disabled={Boolean(pendingClose)} onChange={(value) => updateDraft("physicalUsd", value)} />
        <MoneyInput label="Physical GBP handed over" currency="GBP" value={draft.physicalGbp} disabled={Boolean(pendingClose)} onChange={(value) => updateDraft("physicalGbp", value)} />
        <label className="field"><span>Optional closing note</span><textarea disabled={Boolean(pendingClose)} value={draft.note} onChange={(event) => updateDraft("note", event.target.value)} /></label>
        <button className="btn" disabled={busy || !canClose} onClick={() => { try { validateClosingDraft(draft); setError(""); setReviewing(true); } catch (caught) { setError(caught instanceof Error ? caught.message : "Check the closing values."); } }}>Review closing</button>
      </> : <>
        <div className="sum"><span>USD counted</span><strong>{formatMinorUnits(validateClosingDraft(draft).usdMinor, "USD")}</strong><span>GBP counted</span><strong>{formatMinorUnits(validateClosingDraft(draft).gbpMinor, "GBP")}</strong><span>Physical EUR</span><strong>{formatMinorUnits(validateClosingDraft(draft).physicalEurMinor, "EUR")}</strong><span>Physical USD</span><strong>{formatMinorUnits(validateClosingDraft(draft).physicalUsdMinor, "USD")}</strong><span>Physical GBP</span><strong>{formatMinorUnits(validateClosingDraft(draft).physicalGbpMinor, "GBP")}</strong></div>
        {draft.note.trim() && <p className="fine">Closing note: {draft.note.trim()}</p>}
        {warnings.length > 0 && <p className="fine">Warnings remain visible above and do not auto-block this close.</p>}
        <button className="btn" disabled={busy} onClick={() => void closeDay()}>{busy ? "Closing…" : pendingClose ? "Retry same close" : "Close day"}</button>
        <button className="btn secondary" disabled={busy || Boolean(pendingClose)} onClick={() => setReviewing(false)}>Change values</button>
        {pendingClose && <p className="fine">Retry is locked to the same closure UUID, Revenue version, and entered values.</p>}
      </>}
    </section>}

    {state.is_closed && <section className="card">
      <div className="kicker">CLOSING EVIDENCE</div><h2>{formatInstant(state.closed_at)}</h2>
      <div className="sum"><span>USD counted</span><strong>{formatMinorUnits(state.usd_minor!, "USD")}</strong><span>GBP counted</span><strong>{formatMinorUnits(state.gbp_minor!, "GBP")}</strong><span>Physical EUR</span><strong>{formatMinorUnits(state.physical_eur_minor!, "EUR")}</strong><span>Physical USD</span><strong>{formatMinorUnits(state.physical_usd_minor!, "USD")}</strong><span>Physical GBP</span><strong>{formatMinorUnits(state.physical_gbp_minor!, "GBP")}</strong></div>
      {state.closure_note && <p className="fine">Note: {state.closure_note}</p>}
      <p className="fine">Revenue binding: {state.revenue_binding_current ? "current" : "stale — owner review required"}. Close version {state.closure_version}.</p>
      {state.closing_snapshot_difference_minor !== null && <p className="fine">Cash-expense difference at close: {formatMinorUnits(state.closing_snapshot_difference_minor, "CZK")}{state.closing_snapshot_acknowledgment_id ? " · acknowledged at close" : " · not acknowledged at close"}.</p>}
      {owner && !editingClose && <button className="btn secondary" onClick={beginCorrection}>Correct / review close</button>}
    </section>}

    {owner && editingClose && state.is_closed && <section className="card">
      <div className="kicker">OWNER CORRECTION</div><h2>Correct closing evidence</h2><p className="sub">Previous close values remain in append-only revision history. Saving also rebinds the close to the exact current Revenue version.</p>
      <MoneyInput label="USD counted" currency="USD" value={draft.usd} onChange={(value) => updateDraft("usd", value)} />
      <MoneyInput label="GBP counted" currency="GBP" value={draft.gbp} onChange={(value) => updateDraft("gbp", value)} />
      <MoneyInput label="Physical EUR handed over" currency="EUR" value={draft.physicalEur} onChange={(value) => updateDraft("physicalEur", value)} />
      <MoneyInput label="Physical USD handed over" currency="USD" value={draft.physicalUsd} onChange={(value) => updateDraft("physicalUsd", value)} />
      <MoneyInput label="Physical GBP handed over" currency="GBP" value={draft.physicalGbp} onChange={(value) => updateDraft("physicalGbp", value)} />
      <label className="field"><span>Closing note</span><textarea value={draft.note} onChange={(event) => updateDraft("note", event.target.value)} /></label>
      <label className="field"><span>Correction reason (required)</span><textarea value={correctionReason} onChange={(event) => setCorrectionReason(event.target.value)} /></label>
      <button className="btn" disabled={busy || !correctionReason.trim()} onClick={() => void saveCorrection()}>{busy ? "Saving…" : "Save audited correction"}</button>
      <button className="btn secondary" disabled={busy} onClick={() => { setEditingClose(false); setCorrectionReason(""); setDraft(EMPTY_DRAFT); }}>Cancel</button>
    </section>}
  </>;
}
