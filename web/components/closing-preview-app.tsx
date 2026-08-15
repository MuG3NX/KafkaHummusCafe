"use client";

import { useEffect, useMemo, useState } from "react";
import { ClosingPanel } from "./closing-panel";
import { getSupabaseBrowserClient } from "../lib/supabase";
import type { Location, RevenueEntry } from "../lib/types";

export function ClosingPreviewApp() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [userId, setUserId] = useState<string | null>(null);
  const [role, setRole] = useState("");
  const [locations, setLocations] = useState<Location[]>([]);
  const [location, setLocation] = useState<Location | null>(null);
  const [businessDate, setBusinessDate] = useState("");
  const [revenueSignal, setRevenueSignal] = useState("none");
  const [error, setError] = useState("");

  async function load(targetLocationId?: string) {
    if (!supabase) return;
    setError("");
    const session = await supabase.auth.getSession();
    const currentUser = session.data.session?.user;
    if (!currentUser) {
      setUserId(null);
      return;
    }
    setUserId(currentUser.id);

    const membership = await supabase
      .from("restaurant_memberships")
      .select("restaurant_id, role")
      .eq("user_id", currentUser.id)
      .limit(1)
      .maybeSingle();
    if (membership.error || !membership.data) throw membership.error ?? new Error("No restaurant membership found.");
    setRole(String(membership.data.role));

    const locationResult = await supabase
      .from("locations")
      .select("id, name, timezone")
      .eq("restaurant_id", membership.data.restaurant_id)
      .order("name");
    if (locationResult.error || !locationResult.data?.length) throw locationResult.error ?? new Error("No location found.");
    const available = locationResult.data as Location[];
    setLocations(available);
    const selected = available.find((item) => item.id === targetLocationId) ?? available[0];
    setLocation(selected);

    const dateResult = await supabase.rpc("get_current_business_date", { target_location_id: selected.id });
    if (dateResult.error || !dateResult.data) throw dateResult.error ?? new Error("Current service day could not be resolved.");
    const date = String(dateResult.data);
    setBusinessDate(date);

    const revenue = await supabase
      .from("revenue_entries")
      .select("id, version")
      .eq("location_id", selected.id)
      .eq("business_date", date)
      .limit(1)
      .maybeSingle();
    if (revenue.error) throw revenue.error;
    const entry = revenue.data as Pick<RevenueEntry, "id" | "version"> | null;
    setRevenueSignal(entry ? `${entry.id}:${entry.version}` : "none");
  }

  useEffect(() => {
    void load().catch((caught) => setError(caught instanceof Error ? caught.message : "Preview could not load."));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [supabase]);

  if (!userId) {
    return <main className="app-shell"><section className="card auth-card"><div className="kicker">M4C PREVIEW</div><h1>Digital closing</h1><p className="sub">Sign in through the production app first, then reload this preview route.</p></section></main>;
  }

  return <main className="app-shell">
    <header className="top"><div><div className="kicker">M4C PREVIEW</div><h1>Digital closing</h1></div></header>
    <p className="fine">Branch-only validation harness. Final M4C ships inside Revenue/Today, not as a fifth platform module.</p>
    {locations.length > 1 && <section className="card compact-card"><label className="field"><span>Location</span><div className="input-wrap"><select value={location?.id ?? ""} onChange={(event) => { void load(event.target.value).catch((caught) => setError(caught instanceof Error ? caught.message : "Location could not load.")); }}>{locations.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></div></label></section>}
    {error && <p className="error" role="alert">{error}</p>}
    {location && businessDate && <ClosingPanel location={location} businessDate={businessDate} owner={role === "owner"} revenueSignal={revenueSignal} />}
  </main>;
}
