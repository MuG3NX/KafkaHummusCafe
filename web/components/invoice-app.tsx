"use client";

import { useEffect, useMemo, useState } from "react";
import { noProviderInvoiceAdapter, type InvoiceExtractionDraft } from "../lib/invoice-extraction";
import { parseMoneyToMinorUnits } from "../lib/money";
import { getSupabaseBrowserClient } from "../lib/supabase";
import type { Location } from "../lib/types";

type InvoiceRecord = {
  id: string;
  location_id: string;
  storage_path: string;
  original_filename: string;
  original_mime_type: string;
  original_size_bytes: number;
  status: "uploading" | "needs_review" | "approved" | "rejected";
  version: number;
  created_at: string;
  updated_at: string;
};

type InvoiceDraftRow = InvoiceExtractionDraft & {
  invoice_id: string;
  version: number;
  source: "manual" | "adapter";
  provider_key: string | null;
  supplier_name: string | null;
  invoice_number: string | null;
  issue_date: string | null;
  due_date: string | null;
  currency: "CZK" | "EUR";
  net_minor: string | null;
  vat_minor: string | null;
  gross_minor: string | null;
};

type DraftForm = {
  supplierName: string;
  invoiceNumber: string;
  issueDate: string;
  dueDate: string;
  currency: "CZK" | "EUR";
  net: string;
  vat: string;
  gross: string;
  reason: string;
};

const EMPTY_DRAFT: DraftForm = { supplierName: "", invoiceNumber: "", issueDate: "", dueDate: "", currency: "CZK", net: "", vat: "", gross: "", reason: "" };

function draftFromRow(row: InvoiceDraftRow | undefined): DraftForm {
  if (!row) return EMPTY_DRAFT;
  return {
    supplierName: row.supplier_name ?? "",
    invoiceNumber: row.invoice_number ?? "",
    issueDate: row.issue_date ?? "",
    dueDate: row.due_date ?? "",
    currency: row.currency,
    net: minorToInput(row.net_minor),
    vat: minorToInput(row.vat_minor),
    gross: minorToInput(row.gross_minor),
    reason: ""
  };
}

function minorToInput(value: string | null): string {
  if (value === null || value === "") return "";
  const amount = BigInt(value);
  const absolute = amount < 0n ? -amount : amount;
  return `${amount < 0n ? "-" : ""}${absolute / 100n}.${(absolute % 100n).toString().padStart(2, "0")}`;
}

function statusLabel(status: InvoiceRecord["status"]): string {
  return status === "needs_review" ? "Needs human review" : status.replace("_", " ");
}

function safeFileName(name: string): string {
  return name.replace(/[^a-zA-Z0-9._-]/g, "-").slice(-100) || "invoice";
}

function optionalMinor(value: string, currency: "CZK" | "EUR"): string | null {
  return value.trim() ? parseMoneyToMinorUnits(value, currency).toString() : null;
}

export function InvoiceApp({ onOpenRevenue, onOpenShifts }: { onOpenRevenue: () => void; onOpenShifts: () => void }) {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [userId, setUserId] = useState<string | null>(null);
  const [location, setLocation] = useState<Location | null>(null);
  const [owner, setOwner] = useState(false);
  const [invoices, setInvoices] = useState<InvoiceRecord[]>([]);
  const [drafts, setDrafts] = useState<InvoiceDraftRow[]>([]);
  const [selected, setSelected] = useState<InvoiceRecord | null>(null);
  const [selectedUrl, setSelectedUrl] = useState("");
  const [draft, setDraft] = useState<DraftForm>(EMPTY_DRAFT);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

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
    const locationResult = await supabase.from("locations").select("id, name, timezone").eq("restaurant_id", membershipResult.data.restaurant_id).limit(1).single();
    if (locationResult.error || !locationResult.data) { setError(locationResult.error?.message ?? "No restaurant location is configured."); setLoading(false); return; }
    const currentLocation = locationResult.data as Location;
    setLocation(currentLocation);
    const invoiceResult = await supabase.from("invoice_records").select("id, location_id, storage_path, original_filename, original_mime_type, original_size_bytes, status, version, created_at, updated_at").eq("location_id", currentLocation.id).order("created_at", { ascending: false });
    if (invoiceResult.error) { setError(invoiceResult.error.message); setLoading(false); return; }
    const invoiceRows = (invoiceResult.data ?? []) as InvoiceRecord[];
    setInvoices(invoiceRows);
    if (invoiceRows.length) {
      const draftResult = await supabase.from("invoice_extraction_drafts").select("*").in("invoice_id", invoiceRows.map((invoice) => invoice.id)).order("version", { ascending: false });
      if (draftResult.error) setError(draftResult.error.message);
      else setDrafts((draftResult.data ?? []) as InvoiceDraftRow[]);
    } else setDrafts([]);
    setLoading(false);
  }

  // Auth changes refresh this module without changing the shared session model.
  // eslint-disable-next-line react-hooks/exhaustive-deps, react-hooks/set-state-in-effect
  useEffect(() => { void loadWorkspace(); if (!supabase) return; const { data } = supabase.auth.onAuthStateChange(() => { void loadWorkspace(); }); return () => data.subscription.unsubscribe(); }, [supabase]);

  function latestDraft(invoiceId: string): InvoiceDraftRow | undefined {
    return drafts.find((row) => row.invoice_id === invoiceId);
  }

  async function openInvoice(invoice: InvoiceRecord) {
    setSelected(invoice);
    setDraft(draftFromRow(latestDraft(invoice.id)));
    setSelectedUrl("");
    if (!supabase) return;
    const signed = await supabase.storage.from("invoice-originals").createSignedUrl(invoice.storage_path, 3600);
    if (!signed.error && signed.data?.signedUrl) setSelectedUrl(signed.data.signedUrl);
  }

  async function uploadInvoice(file: File) {
    if (!supabase || !location || !userId || !navigator.onLine) { setError("Invoice uploads need a live connection."); return; }
    const allowed = ["application/pdf", "image/jpeg", "image/png", "image/webp"];
    if (!allowed.includes(file.type)) { setError("Use a PDF, JPEG, PNG, or WebP invoice."); return; }
    setBusy(true); setError("");
    const invoiceId = crypto.randomUUID();
    const path = `${location.id}/${invoiceId}/${safeFileName(file.name)}`;
    try {
      const created = await supabase.rpc("create_invoice_record", { p_invoice_id: invoiceId, p_location_id: location.id, p_storage_path: path, p_original_filename: file.name, p_original_mime_type: file.type, p_original_size_bytes: file.size });
      if (created.error) throw created.error;
      const uploaded = await supabase.storage.from("invoice-originals").upload(path, file, { upsert: false, contentType: file.type });
      if (uploaded.error) throw uploaded.error;
      const marked = await supabase.rpc("mark_invoice_uploaded", { p_invoice_id: invoiceId });
      if (marked.error) throw marked.error;
      const adapterDraft = await noProviderInvoiceAdapter.extract({ fileName: file.name, mimeType: file.type });
      const saved = await supabase.rpc("save_invoice_extraction_draft", {
        p_invoice_id: invoiceId, p_source: "adapter", p_provider_key: noProviderInvoiceAdapter.key,
        p_supplier_name: adapterDraft.supplierName || null, p_invoice_number: adapterDraft.invoiceNumber || null,
        p_issue_date: adapterDraft.issueDate || null, p_due_date: adapterDraft.dueDate || null,
        p_currency: adapterDraft.currency, p_net_minor: adapterDraft.netMinor || null, p_vat_minor: adapterDraft.vatMinor || null,
        p_gross_minor: adapterDraft.grossMinor || null, p_confidence: adapterDraft.confidence, p_validation_errors: adapterDraft.validationErrors, p_reason: null
      });
      if (saved.error) throw saved.error;
      await loadWorkspace();
      const freshInvoice = { id: invoiceId, location_id: location.id, storage_path: path, original_filename: file.name, original_mime_type: file.type, original_size_bytes: file.size, status: "needs_review" as const, version: 3, created_at: new Date().toISOString(), updated_at: new Date().toISOString() };
      await openInvoice(freshInvoice);
    } catch (caught) { setError(caught instanceof Error ? caught.message : "Invoice upload could not be saved."); }
    setBusy(false);
  }

  async function saveDraft() {
    if (!supabase || !selected) return;
    setBusy(true); setError("");
    try {
      const result = await supabase.rpc("save_invoice_extraction_draft", {
        p_invoice_id: selected.id, p_source: "manual", p_provider_key: null,
        p_supplier_name: draft.supplierName || null, p_invoice_number: draft.invoiceNumber || null,
        p_issue_date: draft.issueDate || null, p_due_date: draft.dueDate || null, p_currency: draft.currency,
        p_net_minor: optionalMinor(draft.net, draft.currency), p_vat_minor: optionalMinor(draft.vat, draft.currency), p_gross_minor: optionalMinor(draft.gross, draft.currency),
        p_confidence: {}, p_validation_errors: [], p_reason: draft.reason || null
      });
      if (result.error) throw result.error;
      await loadWorkspace();
      setSelected((current) => current ? { ...current, status: "needs_review", version: current.version + 1 } : current);
      setDraft((current) => ({ ...current, reason: "" }));
    } catch (caught) { setError(caught instanceof Error ? caught.message : "Invoice draft could not be saved."); }
    setBusy(false);
  }

  async function approveInvoice() {
    if (!supabase || !selected || !owner) return;
    setBusy(true); setError("");
    const result = await supabase.rpc("approve_invoice", { p_invoice_id: selected.id, p_reason: "Human review approved" });
    if (result.error) setError(result.error.message); else { setSelected((current) => current ? { ...current, status: "approved", version: current.version + 1 } : current); await loadWorkspace(); }
    setBusy(false);
  }

  async function rejectInvoice() {
    if (!supabase || !selected || !owner || !draft.reason.trim()) { setError("Enter a rejection reason first."); return; }
    setBusy(true); setError("");
    const result = await supabase.rpc("reject_invoice", { p_invoice_id: selected.id, p_reason: draft.reason });
    if (result.error) setError(result.error.message); else { setSelected((current) => current ? { ...current, status: "rejected", version: current.version + 1 } : current); setDraft((current) => ({ ...current, reason: "" })); await loadWorkspace(); }
    setBusy(false);
  }

  if (!userId) return <main className="app-shell"><section className="card auth-card"><div className="kicker">KAFKA</div><h1>Invoices</h1><p className="sub">Open Revenue first to sign in, then return here to capture an invoice.</p><button className="btn" onClick={onOpenRevenue}>Go to sign in</button></section></main>;
  if (loading || !location) return <main className="app-shell"><div className="kicker">KAFKA</div><h1>Invoices</h1><p className="muted">Loading invoices…</p></main>;

  return <main className="app-shell">
    <div className="module-nav module-nav-three"><button onClick={onOpenRevenue}>Revenue</button><button className="active">Invoices</button><button onClick={onOpenShifts}>Shifts</button></div>
    <header className="top"><div><div className="kicker">KAFKA</div><h1>Invoices</h1></div><button className="avatar" aria-label="Sign out" onClick={() => { void supabase?.auth.signOut(); }}>K</button></header>
    <p className="muted">{location.name} · originals stay private</p>
    <div className="banner">● Connected · OCR is a draft until human approval</div>
    {error && <p className="error" role="alert">{error}</p>}
    <section className="card"><div className="kicker">CAPTURE</div><h2>Original invoice</h2><p className="sub">Take a photo or choose a PDF. The original is stored separately from extracted fields.</p><label className="btn file-btn">{busy ? "Saving…" : "Choose invoice photo/PDF"}<input type="file" accept="image/jpeg,image/png,image/webp,application/pdf" disabled={busy} onChange={(event) => { const file = event.target.files?.[0]; event.currentTarget.value = ""; if (file) void uploadInvoice(file); }} /></label></section>
    <section className="card"><div className="kicker">INVOICE QUEUE</div><h2>{invoices.length} captured</h2>{invoices.length === 0 ? <p className="muted">No invoices captured yet.</p> : invoices.map((invoice) => <button className={`invoice-row ${selected?.id === invoice.id ? "selected" : ""}`} key={invoice.id} onClick={() => void openInvoice(invoice)}><span><strong>{invoice.original_filename}</strong><small>{new Date(invoice.created_at).toLocaleDateString()}</small></span><em>{statusLabel(invoice.status)}</em></button>)}</section>
    {selected && <section className="card"><div className="kicker">HUMAN REVIEW</div><h2>{selected.original_filename}</h2><p className="sub">Status: {statusLabel(selected.status)} · version {selected.version}</p>{selectedUrl && <a className="btn secondary" href={selectedUrl} target="_blank" rel="noreferrer">Open private original</a>}<p className="fine">No OCR provider is connected. Enter or correct the draft fields below; approval is owner-only.</p>
      <label className="field"><span>Supplier</span><div className="input-wrap"><input value={draft.supplierName} onChange={(event) => setDraft((current) => ({ ...current, supplierName: event.target.value }))} /></div></label>
      <label className="field"><span>Invoice number</span><div className="input-wrap"><input value={draft.invoiceNumber} onChange={(event) => setDraft((current) => ({ ...current, invoiceNumber: event.target.value }))} /></div></label>
      <label className="field"><span>Issue date</span><div className="input-wrap"><input type="date" value={draft.issueDate} onChange={(event) => setDraft((current) => ({ ...current, issueDate: event.target.value }))} /></div></label>
      <label className="field"><span>Due date</span><div className="input-wrap"><input type="date" value={draft.dueDate} onChange={(event) => setDraft((current) => ({ ...current, dueDate: event.target.value }))} /></div></label>
      <label className="field"><span>Currency</span><div className="input-wrap"><select value={draft.currency} onChange={(event) => setDraft((current) => ({ ...current, currency: event.target.value as "CZK" | "EUR" }))}><option value="CZK">CZK</option><option value="EUR">EUR</option></select></div></label>
      {(["net", "vat", "gross"] as const).map((key) => <label className="field" key={key}><span>{key === "net" ? "Net" : key === "vat" ? "VAT" : "Gross"}</span><div className="input-wrap"><input inputMode="decimal" placeholder="0" value={draft[key]} onChange={(event) => setDraft((current) => ({ ...current, [key]: event.target.value }))} /><b>{draft.currency}</b></div></label>)}
      {(owner || selected.status !== "approved") && <label className="field"><span>{selected.status === "approved" ? "Correction reason (required)" : "Review note"}</span><textarea value={draft.reason} onChange={(event) => setDraft((current) => ({ ...current, reason: event.target.value }))} /></label>}
      <button className="btn" disabled={busy || (selected.status === "approved" && !draft.reason.trim())} onClick={() => void saveDraft()}>{busy ? "Saving…" : selected.status === "approved" ? "Save audited correction" : "Save draft"}</button>
      {owner && selected.status === "needs_review" && <><button className="btn" disabled={busy} onClick={() => void approveInvoice()}>Approve for future reporting</button><button className="btn secondary" disabled={busy || !draft.reason.trim()} onClick={() => void rejectInvoice()}>Reject with reason</button></>}
    </section>}
  </main>;
}
