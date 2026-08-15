"use client";

import { useEffect, useMemo, useState } from "react";
import { businessDateForTimezone } from "../lib/business-date";
import { formatMinorUnits, parseMoneyToMinorUnits } from "../lib/money";
import { getSupabaseBrowserClient } from "../lib/supabase";
import type { Draft, Location, RevenueEntry } from "../lib/types";
import { EMPTY_DRAFT } from "../lib/types";

const FIELDS = [
  ["total", "Total revenue", "CZK"],
  ["card", "Card", "CZK"],
  ["cash", "Cash", "CZK"],
  ["expenses", "Cash-register expenses", "CZK"],
  ["euros", "Euros", "EUR"],
  ["handover", "Physical cash handed to owner", "CZK"]
] as const;

function draftFromEntry(entry: RevenueEntry): Draft {
  return {
    total: formatMinorUnits(entry.total_revenue_czk_minor, "CZK").replace(/[^\d,.-]/g, ""),
    card: formatMinorUnits(entry.card_czk_minor, "CZK").replace(/[^\d,.-]/g, ""),
    cash: formatMinorUnits(entry.cash_czk_minor, "CZK").replace(/[^\d,.-]/g, ""),
    expenses: formatMinorUnits(entry.cash_register_expenses_czk_minor, "CZK").replace(/[^\d,.-]/g, ""),
    euros: formatMinorUnits(entry.euros_minor, "EUR").replace(/[^\d,.-]/g, ""),
    handover: formatMinorUnits(entry.physical_cash_handed_over_czk_minor, "CZK").replace(/[^\d,.-]/g, ""),
    note: entry.note ?? ""
  };
}

function entryTotal(entry: RevenueEntry): string { return formatMinorUnits(entry.total_revenue_czk_minor, "CZK"); }

type AuthMode = "signin" | "signup" | "reset";

function AuthCard({ onReady }: { onReady: () => void }) {
  const supabase = getSupabaseBrowserClient();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [mode, setMode] = useState<AuthMode>("signin");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  if (!supabase) return <main className="app-shell"><section className="card auth-card"><div className="kicker">KAFKA</div><h1>Revenue</h1><p className="sub">Supabase is not configured yet. Add the two public environment variables from <code>web/.env.example</code> before signing in.</p></section></main>;
  const client = supabase;
  async function submit(event: React.FormEvent) {
    event.preventDefault(); setBusy(true); setMessage("");
    if (mode === "signin") {
      const result = await client.auth.signInWithPassword({ email, password });
      setBusy(false);
      if (result.error) setMessage(result.error.message); else onReady();
      return;
    }
    if (mode === "signup") {
      const result = await client.auth.signUp({ email, password });
      setBusy(false);
      if (result.error) setMessage(result.error.message);
      else if (result.data.session) onReady();
      else setMessage("Account setup started. Confirm your email if requested, then sign in. If this email already has an account, use Forgot password to set a password.");
      return;
    }
    const result = await client.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/` });
    setBusy(false);
    if (result.error) setMessage(result.error.message);
    else setMessage("If an account exists for this email, a password reset email was sent. Check your inbox and spam folder.");
  }
  const title = mode === "reset" ? "Set your password" : "Revenue";
  const subtitle = mode === "reset" ? "Get a secure link to choose a new password." : "Sign in to the shared service-day ledger.";
  return <main className="app-shell"><section className="card auth-card"><div className="kicker">KAFKA</div><h1>{title}</h1><p className="sub">{subtitle}</p><form onSubmit={submit}>
    <label className="field"><span>Email</span><div className="input-wrap"><input required type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} /></div></label>
    {mode !== "reset" && <label className="field"><span>Password</span><div className="input-wrap"><input required minLength={6} type="password" autoComplete={mode === "signin" ? "current-password" : "new-password"} value={password} onChange={(event) => setPassword(event.target.value)} /></div></label>}
    {message && <p className="error" role="alert">{message}</p>}
    <button className="btn" disabled={busy}>{busy ? "Working…" : mode === "signin" ? "Sign in" : mode === "signup" ? "Create account" : "Send reset email"}</button>
  </form>{mode === "signin" && <button className="btn secondary" onClick={() => { setMode("reset"); setMessage(""); }}>Forgot password?</button>}{mode !== "signin" && <button className="btn secondary" onClick={() => { setMode("signin"); setMessage(""); }}>{mode === "signup" ? "Back to sign in" : "Back to sign in"}</button>}{mode === "signin" && <button className="btn secondary" onClick={() => { setMode("signup"); setMessage(""); }}>Create an account</button>}</section></main>;
}

function PasswordRecoveryCard({ onReady }: { onReady: () => void }) {
  const supabase = getSupabaseBrowserClient();
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  if (!supabase) return null;
  const client = supabase;
  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (password.length < 6) { setMessage("Use at least 6 characters."); return; }
    if (password !== confirmation) { setMessage("Passwords do not match."); return; }
    setBusy(true); setMessage("");
    const result = await client.auth.updateUser({ password });
    setBusy(false);
    if (result.error) setMessage(result.error.message);
    else { window.history.replaceState({}, document.title, window.location.pathname); onReady(); }
  }
  return <main className="app-shell"><section className="card auth-card"><div className="kicker">KAFKA</div><h1>Choose a password</h1><p className="sub">This account is ready. Choose the password you will use to sign in.</p><form onSubmit={submit}>
    <label className="field"><span>New password</span><div className="input-wrap"><input required minLength={6} type="password" autoComplete="new-password" value={password} onChange={(event) => setPassword(event.target.value)} /></div></label>
    <label className="field"><span>Confirm password</span><div className="input-wrap"><input required minLength={6} type="password" autoComplete="new-password" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} /></div></label>
    {message && <p className="error" role="alert">{message}</p>}
    <button className="btn" disabled={busy}>{busy ? "Saving…" : "Save password"}</button>
  </form></section></main>;
}

function MoneyField({ field, value, onChange }: { field: typeof FIELDS[number]; value: string; onChange: (value: string) => void }) {
  const [key, label, currency] = field;
  return <label className="field"><span>{label}</span><div className="input-wrap"><input required={key !== "euros"} inputMode="decimal" type="text" placeholder="0" value={value} onChange={(event) => onChange(event.target.value)} /><b>{currency}</b></div></label>;
}

function Summary({ draft }: { draft: Draft }) {
  return <div className="sum">{FIELDS.map(([key, label, currency]) => <><span key={`${key}-label`}>{label}</span><strong key={`${key}-value`}>{draft[key] ? formatMinorUnits(parseMoneyToMinorUnits(draft[key], currency), currency) : "—"}</strong></>)}</div>;
}

export function RevenueApp({ onOpenShifts, onOpenInvoices, onOpenCosts }: { onOpenShifts?: () => void; onOpenInvoices?: () => void; onOpenCosts?: () => void }) {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [userId, setUserId] = useState<string | null>(null);
  const [location, setLocation] = useState<Location | null>(null);
  const [businessDate, setBusinessDate] = useState("");
  const [entry, setEntry] = useState<RevenueEntry | null>(null);
  const [history, setHistory] = useState<RevenueEntry[]>([]);
  const [draft, setDraft] = useState<Draft>(EMPTY_DRAFT);
  const [view, setView] = useState<"today" | "history">("today");
  const [owner, setOwner] = useState(false);
  const [costsAccess, setCostsAccess] = useState(false);
  const [canSubmit, setCanSubmit] = useState(false);
  const [reviewing, setReviewing] = useState(false);
  const [editing, setEditing] = useState<RevenueEntry | null>(null);
  const [correctionReason, setCorrectionReason] = useState("");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [passwordRecovery, setPasswordRecovery] = useState(() => typeof window !== "undefined" && window.location.hash.includes("type=recovery"));

  async function loadWorkspace() {
    if (!supabase) { setLoading(false); return; }
    setLoading(true); setError("");
    const { data: sessionData } = await supabase.auth.getSession();
    const currentUser = sessionData.session?.user;
    if (!currentUser) { setUserId(null); setLoading(false); return; }
    setUserId(currentUser.id);
    const membershipResult = await supabase.from("restaurant_memberships").select("restaurant_id, role").eq("user_id", currentUser.id).limit(1).maybeSingle();
    if (membershipResult.error || !membershipResult.data) { setError(membershipResult.error?.message ?? "Your account is not connected to a restaurant yet."); setLoading(false); return; }
    setOwner(membershipResult.data.role === "owner");
    setCostsAccess(membershipResult.data.role === "owner" || membershipResult.data.role === "manager");
    const locationResult = await supabase.from("locations").select("id, name, timezone").eq("restaurant_id", membershipResult.data.restaurant_id).limit(1).single();
    if (locationResult.error || !locationResult.data) { setError(locationResult.error?.message ?? "No restaurant location is configured."); setLoading(false); return; }
    const currentLocation = locationResult.data as Location; setLocation(currentLocation);
    const permissionResult = await supabase.rpc("can_submit_revenue", { target_location_id: currentLocation.id });
    if (permissionResult.error) { setError(permissionResult.error.message); setLoading(false); return; }
    setCanSubmit(Boolean(permissionResult.data));
    const dateResult = await supabase.rpc("get_current_business_date", { target_location_id: currentLocation.id });
    if (dateResult.error || !dateResult.data) { setError(dateResult.error?.message ?? "Could not resolve the service day."); setLoading(false); return; }
    const currentDate = String(dateResult.data); setBusinessDate(currentDate);
    const entryResult = await supabase.from("revenue_entries").select("*").eq("location_id", currentLocation.id).eq("business_date", currentDate).maybeSingle();
    if (entryResult.error) setError(entryResult.error.message); else { setEntry(entryResult.data as RevenueEntry | null); if (entryResult.data) setDraft(draftFromEntry(entryResult.data as RevenueEntry)); }
    if (membershipResult.data.role === "owner") {
      const historyResult = await supabase.from("revenue_entries").select("*").eq("location_id", currentLocation.id).order("business_date", { ascending: false });
      if (historyResult.error) setError(historyResult.error.message); else setHistory((historyResult.data ?? []) as RevenueEntry[]);
    }
    setLoading(false);
  }

  // loadWorkspace is intentionally recreated only with the Supabase client; auth events refresh the same workspace.
  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    void loadWorkspace();
    if (!supabase) return;
    const { data } = supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY") { setPasswordRecovery(true); setLoading(false); return; }
      void loadWorkspace();
    });
    return () => data.subscription.unsubscribe();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [supabase]);
  /* eslint-enable react-hooks/set-state-in-effect */

  function updateDraft(key: keyof Draft, value: string) { setDraft((current) => ({ ...current, [key]: value })); }
  function parsedDraft() {
    return { total: parseMoneyToMinorUnits(draft.total, "CZK").toString(), card: parseMoneyToMinorUnits(draft.card, "CZK").toString(), cash: parseMoneyToMinorUnits(draft.cash, "CZK").toString(), expenses: parseMoneyToMinorUnits(draft.expenses, "CZK").toString(), euros: parseMoneyToMinorUnits(draft.euros || "0", "EUR").toString(), handover: parseMoneyToMinorUnits(draft.handover, "CZK").toString() };
  }
  async function submitRevenue() {
    if (!supabase || !location || !canSubmit || !navigator.onLine) { setError(!navigator.onLine ? "You are offline. Revenue was not submitted." : "You do not have permission to submit revenue."); return; }
    setBusy(true); setError("");
    try { const values = parsedDraft(); const result = await supabase.rpc("submit_revenue_entry", { p_location_id: location.id, p_business_date: businessDate, p_total_revenue_czk_minor: values.total, p_card_czk_minor: values.card, p_cash_czk_minor: values.cash, p_cash_register_expenses_czk_minor: values.expenses, p_euros_minor: values.euros, p_physical_cash_handed_over_czk_minor: values.handover, p_note: draft.note }); if (result.error) throw result.error; const saved = (Array.isArray(result.data) ? result.data[0] : result.data) as RevenueEntry; setEntry(saved); setDraft(draftFromEntry(saved)); setReviewing(false); if (owner) setHistory((current) => [saved, ...current.filter((item) => item.id !== saved.id)]); } catch (caught) { setError(caught instanceof Error ? caught.message : "Revenue could not be submitted."); } finally { setBusy(false); }
  }
  async function correctRevenue() {
    if (!supabase || !editing) return; setBusy(true); setError("");
    try { const values = parsedDraft(); const result = await supabase.rpc("correct_revenue_entry", { p_revenue_entry_id: editing.id, p_total_revenue_czk_minor: values.total, p_card_czk_minor: values.card, p_cash_czk_minor: values.cash, p_cash_register_expenses_czk_minor: values.expenses, p_euros_minor: values.euros, p_physical_cash_handed_over_czk_minor: values.handover, p_note: draft.note, p_reason: correctionReason }); if (result.error) throw result.error; const corrected = (Array.isArray(result.data) ? result.data[0] : result.data) as RevenueEntry; setHistory((current) => current.map((item) => item.id === corrected.id ? corrected : item)); if (entry?.id === corrected.id) setEntry(corrected); setEditing(null); setCorrectionReason(""); } catch (caught) { setError(caught instanceof Error ? caught.message : "Correction could not be saved."); } finally { setBusy(false); }
  }
  if (passwordRecovery) return <PasswordRecoveryCard onReady={() => { setPasswordRecovery(false); void loadWorkspace(); }} />;
  if (!userId) return <AuthCard onReady={() => { void loadWorkspace(); }} />;
  if (loading) return <main className="app-shell"><div className="kicker">KAFKA</div><h1>Today</h1><p className="muted">Loading the service day…</p></main>;
  const submitted = Boolean(entry);
  return <main className="app-shell">{onOpenShifts && <div className={`module-nav ${costsAccess && onOpenCosts ? "module-nav-four" : onOpenInvoices ? "module-nav-three" : ""}`}><button className="active">Revenue</button>{onOpenInvoices && <button onClick={onOpenInvoices}>Invoices</button>}{costsAccess && onOpenCosts && <button onClick={onOpenCosts}>Costs</button>}<button onClick={onOpenShifts}>Shifts</button></div>}<header className="top"><div><div className="kicker">KAFKA</div><h1>{view === "today" ? "Today" : "History"}</h1></div><button className="avatar" aria-label="Sign out" onClick={() => { void supabase?.auth.signOut(); }}>K</button></header>
    {location && <p className="muted">{location.name} · {businessDate || businessDateForTimezone(new Date(), location.timezone)}</p>}
    <div className={`banner ${typeof navigator !== "undefined" && !navigator.onLine ? "offline" : ""}`}>{typeof navigator !== "undefined" && !navigator.onLine ? "● Offline · financial submission unavailable" : "● Connected · saved to the shared database"}</div>
    {error && <p className="error" role="alert">{error}</p>}
    {view === "today" ? <>{submitted ? <section className="card"><div className="ok">✓</div><div className="kicker">REVENUE SUBMITTED</div><h2 className="big">{entryTotal(entry!)}</h2><div className="sum"><span>Service day</span><strong>{entry!.business_date}</strong><span>Submitted</span><strong>{new Date(entry!.submitted_at).toLocaleString()}</strong></div><p className="fine">Locked for normal submitters. The owner can correct this entry from History with an explicit reason.</p></section> : canSubmit ? <section className="card">{reviewing ? <><div className="kicker">CHECK BEFORE SUBMITTING</div><h2>Everything correct?</h2><Summary draft={draft} /><button className="btn" disabled={busy} onClick={() => void submitRevenue()}>{busy ? "Submitting…" : "Submit day"}</button><button className="btn secondary" disabled={busy} onClick={() => setReviewing(false)}>Change values</button></> : <><div className="kicker">END OF DAY</div><h2>Revenue</h2><p className="sub">Enter the numbers from today’s closing sheet.</p>{FIELDS.map((field) => <MoneyField key={field[0]} field={field} value={draft[field[0]]} onChange={(value) => updateDraft(field[0], value)} />)}<label className="field"><span>Optional note</span><textarea value={draft.note} onChange={(event) => updateDraft("note", event.target.value)} /></label><button className="btn" onClick={() => { try { parsedDraft(); setError(""); setReviewing(true); } catch (caught) { setError(caught instanceof Error ? caught.message : "Check the amounts."); } }}>Review revenue</button></>}</section> : <section className="card"><h2>No submission permission</h2><p className="sub">Your account can view its own submissions, but an owner must grant revenue-submission permission.</p></section>}</> : <section className="card"><div className="row"><div><div className="kicker">OWNER VIEW</div><h2>Submitted days</h2></div><strong>{history.length}</strong></div>{history.length === 0 ? <p className="muted">No submitted service days yet.</p> : history.map((item) => <div className="entry" key={item.id}><div className="row"><div><div className="entry-date">{item.business_date}</div><div className="muted">Version {item.version}</div></div><div className="entry-total">{entryTotal(item)}</div></div><button className="btn secondary small" onClick={() => { setEditing(item); setDraft(draftFromEntry(item)); setCorrectionReason(""); }}>Correct entry</button></div>)}</section>}
    {editing && <section className="card"><div className="kicker">OWNER CORRECTION</div><h2>Correct {editing.business_date}</h2><p className="sub">Previous values remain in the append-only audit history.</p>{FIELDS.map((field) => <MoneyField key={field[0]} field={field} value={draft[field[0]]} onChange={(value) => updateDraft(field[0], value)} />)}<label className="field"><span>Correction reason (required)</span><textarea required value={correctionReason} onChange={(event) => setCorrectionReason(event.target.value)} /></label><button className="btn" disabled={busy || !correctionReason.trim()} onClick={() => void correctRevenue()}>{busy ? "Saving…" : "Save audited correction"}</button><button className="btn secondary" disabled={busy} onClick={() => setEditing(null)}>Cancel</button></section>}
    <nav className="nav"><button className={view === "today" ? "active" : ""} onClick={() => { setView("today"); setEditing(null); }}>Today</button><button className={view === "history" ? "active" : ""} onClick={() => { setView("history"); setEditing(null); }}>History</button></nav>
  </main>;
}
