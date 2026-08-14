"use client";

import { useEffect, useMemo, useState } from "react";
import { currentMonthForTimezone, totalsByCurrency, type ApprovedInvoiceCost } from "../lib/costs";
import { formatMinorUnits } from "../lib/money";
import { getSupabaseBrowserClient } from "../lib/supabase";
import type { Location } from "../lib/types";

type CostsAppProps = {
  onOpenRevenue: () => void;
  onOpenInvoices: () => void;
  onOpenShifts: () => void;
};

function formatDate(value: string): string {
  return new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(`${value}T00:00:00`));
}

export function CostsApp({ onOpenRevenue, onOpenInvoices, onOpenShifts }: CostsAppProps) {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [userId, setUserId] = useState<string | null>(null);
  const [location, setLocation] = useState<Location | null>(null);
  const [owner, setOwner] = useState(false);
  const [month, setMonth] = useState("");
  const [rows, setRows] = useState<ApprovedInvoiceCost[]>([]);
  const [loading, setLoading] = useState(true);
  const [openingId, setOpeningId] = useState<string | null>(null);
  const [error, setError] = useState("");

  async function loadCosts(targetLocation: Location, targetMonth: string) {
    if (!supabase) return;
    const result = await supabase.rpc("get_approved_invoice_costs", {
      p_location_id: targetLocation.id,
      p_month: `${targetMonth}-01`
    });
    if (result.error) throw result.error;
    setRows((result.data ?? []) as ApprovedInvoiceCost[]);
  }

  async function loadWorkspace() {
    if (!supabase) { setLoading(false); return; }
    setLoading(true); setError("");
    const { data: sessionData } = await supabase.auth.getSession();
    const currentUser = sessionData.session?.user;
    if (!currentUser) { setUserId(null); setLoading(false); return; }
    setUserId(currentUser.id);
    const membershipResult = await supabase.from("restaurant_memberships").select("restaurant_id, role").eq("user_id", currentUser.id).limit(1).maybeSingle();
    if (membershipResult.error || !membershipResult.data) { setError(membershipResult.error?.message ?? "Your account is not connected to a restaurant yet."); setLoading(false); return; }
    const isOwner = membershipResult.data.role === "owner";
    setOwner(isOwner);
    if (!isOwner) { setRows([]); setLoading(false); return; }
    const locationResult = await supabase.from("locations").select("id, name, timezone").eq("restaurant_id", membershipResult.data.restaurant_id).limit(1).single();
    if (locationResult.error || !locationResult.data) { setError(locationResult.error?.message ?? "No restaurant location is configured."); setLoading(false); return; }
    const currentLocation = locationResult.data as Location;
    const selectedMonth = month || currentMonthForTimezone(new Date(), currentLocation.timezone);
    setLocation(currentLocation); setMonth(selectedMonth);
    try { await loadCosts(currentLocation, selectedMonth); }
    catch (caught) { setError(caught instanceof Error ? caught.message : "Approved invoice costs could not be loaded."); }
    setLoading(false);
  }

  // Auth changes refresh the owner-authorized reporting view.
  // eslint-disable-next-line react-hooks/exhaustive-deps, react-hooks/set-state-in-effect
  useEffect(() => { void loadWorkspace(); if (!supabase) return; const { data } = supabase.auth.onAuthStateChange(() => { void loadWorkspace(); }); return () => data.subscription.unsubscribe(); }, [supabase]);

  async function changeMonth(nextMonth: string) {
    setMonth(nextMonth);
    if (!location || !nextMonth) return;
    setLoading(true); setError("");
    try { await loadCosts(location, nextMonth); }
    catch (caught) { setRows([]); setError(caught instanceof Error ? caught.message : "Approved invoice costs could not be loaded."); }
    setLoading(false);
  }

  async function openOriginal(row: ApprovedInvoiceCost) {
    if (!supabase) return;
    setOpeningId(row.invoice_id); setError("");
    const result = await supabase.storage.from("invoice-originals").createSignedUrl(row.storage_path, 3600);
    setOpeningId(null);
    if (result.error || !result.data?.signedUrl) { setError(result.error?.message ?? "The private original could not be opened."); return; }
    window.open(result.data.signedUrl, "_blank", "noopener,noreferrer");
  }

  if (!userId) return <main className="app-shell"><section className="card auth-card"><div className="kicker">KAFKA</div><h1>Costs</h1><p className="sub">Open Revenue first to sign in.</p><button className="btn" onClick={onOpenRevenue}>Go to sign in</button></section></main>;
  if (loading && !location) return <main className="app-shell"><div className="kicker">KAFKA</div><h1>Costs</h1><p className="muted">Loading approved costs…</p></main>;
  if (!owner) return <main className="app-shell"><section className="card auth-card"><div className="kicker">OWNER ONLY</div><h1>Costs</h1><p className="sub">Approved invoice costs are available only to the restaurant owner.</p><button className="btn" onClick={onOpenRevenue}>Back to Revenue</button></section></main>;

  const totals = totalsByCurrency(rows);
  return <main className="app-shell">
    <div className="module-nav module-nav-four"><button onClick={onOpenRevenue}>Revenue</button><button onClick={onOpenInvoices}>Invoices</button><button className="active">Costs</button><button onClick={onOpenShifts}>Shifts</button></div>
    <header className="top"><div><div className="kicker">KAFKA</div><h1>Costs</h1></div><button className="avatar" aria-label="Sign out" onClick={() => { void supabase?.auth.signOut(); }}>K</button></header>
    <p className="muted">{location?.name} · approved invoice register</p>
    <div className="banner">● Based only on human-approved invoice records</div>
    {error && <p className="error" role="alert">{error}</p>}
    <section className="card"><div className="kicker">REPORTING MONTH</div><label className="field"><span>Month</span><div className="input-wrap"><input aria-label="Reporting month" type="month" value={month} onChange={(event) => void changeMonth(event.target.value)} /></div></label><p className="fine">Operational view—not an accounting or VAT return.</p></section>
    <section className="card"><div className="row"><div><div className="kicker">APPROVED INVOICES</div><h2>{rows.length} invoice{rows.length === 1 ? "" : "s"}</h2></div>{loading && <span className="muted">Loading…</span>}</div><div className="cost-total-grid">{totals.map((total) => <div className="cost-total" key={total.currency}><div className="kicker">{total.currency}</div><strong>{formatMinorUnits(total.grossMinor, total.currency)}</strong><div><span>Net</span><b>{formatMinorUnits(total.netMinor, total.currency)}</b><span>VAT</span><b>{formatMinorUnits(total.vatMinor, total.currency)}</b><span>Gross</span><b>{formatMinorUnits(total.grossMinor, total.currency)}</b></div><small>{total.count} approved</small></div>)}</div></section>
    <section className="card"><div className="kicker">COST REGISTER</div><h2>{month || "Selected month"}</h2>{rows.length === 0 && !loading ? <p className="muted">No approved invoices for this month.</p> : rows.map((row) => <article className="cost-row" key={row.invoice_id}><div className="cost-row-head"><div><strong>{row.supplier_name}</strong><small>{row.invoice_number} · {formatDate(row.issue_date)}</small>{row.due_date && <small>Due {formatDate(row.due_date)}</small>}</div><b>{formatMinorUnits(row.gross_minor, row.currency)}</b></div><div className="cost-row-money"><span>Net {formatMinorUnits(row.net_minor, row.currency)}</span><span>VAT {formatMinorUnits(row.vat_minor, row.currency)}</span><span>Gross {formatMinorUnits(row.gross_minor, row.currency)}</span></div><button className="btn secondary small" disabled={openingId === row.invoice_id} onClick={() => void openOriginal(row)}>{openingId === row.invoice_id ? "Opening…" : "Open private original"}</button></article>)}</section>
  </main>;
}
