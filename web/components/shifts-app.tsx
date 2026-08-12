"use client";

import { useEffect, useMemo, useState } from "react";
import { formatDuration, formatShiftDate, formatShiftTime, instantToLocalDateTime, localDateTimeToInstant, totalForBusinessDate, totalForPeriod, type Shift } from "../lib/shifts";
import { getSupabaseBrowserClient } from "../lib/supabase";
import type { Location } from "../lib/types";

type ShiftsAppProps = { onOpenRevenue: () => void };
type Member = { id: string; user_id: string; role: string; display_name: string };
type CorrectionDraft = { startedAt: string; endedAt: string; reason: string };

function displayName(member: Member | undefined): string {
  return member?.display_name || (member?.role === "owner" ? "Owner" : "Employee");
}

function ShiftLine({ shift, location, member, onCorrect }: { shift: Shift; location: Location; member?: Member; onCorrect?: (shift: Shift) => void }) {
  return <div className="shift-row">
    <div><strong>{member ? displayName(member) : "Your shift"}</strong><div className="muted">{formatShiftDate(shift.business_date)} · {formatShiftTime(shift.started_at, location.timezone)}–{shift.ended_at ? formatShiftTime(shift.ended_at, location.timezone) : "working now"}</div></div>
    <div className="shift-duration">{shift.ended_at ? formatDuration(Math.round((Date.parse(shift.ended_at) - Date.parse(shift.started_at)) / 60000)) : "Open"}{onCorrect && <button className="btn secondary small" onClick={() => onCorrect(shift)}>Correct</button>}</div>
  </div>;
}

function PeriodTotals({ shifts, businessDate }: { shifts: Shift[]; businessDate: string }) {
  const week = totalForPeriod(shifts, businessDate, "week");
  const month = totalForPeriod(shifts, businessDate, "month");
  return <div className="total-grid"><div className="metric"><span>This week</span><strong>{formatDuration(week.minutes)}</strong><small>{week.count} completed shift{week.count === 1 ? "" : "s"}</small></div><div className="metric"><span>This month</span><strong>{formatDuration(month.minutes)}</strong><small>{month.count} completed shift{month.count === 1 ? "" : "s"}</small></div></div>;
}

export function ShiftsApp({ onOpenRevenue }: ShiftsAppProps) {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [userId, setUserId] = useState<string | null>(null);
  const [location, setLocation] = useState<Location | null>(null);
  const [businessDate, setBusinessDate] = useState("");
  const [membershipId, setMembershipId] = useState<string | null>(null);
  const [owner, setOwner] = useState(false);
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [editing, setEditing] = useState<Shift | null>(null);
  const [correction, setCorrection] = useState<CorrectionDraft>({ startedAt: "", endedAt: "", reason: "" });
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
    const membershipResult = await supabase.from("restaurant_memberships").select("id, restaurant_id, role").eq("user_id", currentUser.id).limit(1).maybeSingle();
    if (membershipResult.error || !membershipResult.data) { setError(membershipResult.error?.message ?? "Your account is not connected to a restaurant yet."); setLoading(false); return; }
    const membership = membershipResult.data as { id: string; restaurant_id: string; role: string };
    setMembershipId(membership.id); setOwner(membership.role === "owner");
    const locationResult = await supabase.from("locations").select("id, name, timezone").eq("restaurant_id", membership.restaurant_id).limit(1).single();
    if (locationResult.error || !locationResult.data) { setError(locationResult.error?.message ?? "No restaurant location is configured."); setLoading(false); return; }
    const currentLocation = locationResult.data as Location;
    setLocation(currentLocation);
    const dateResult = await supabase.rpc("get_current_business_date", { target_location_id: currentLocation.id });
    if (dateResult.error || !dateResult.data) { setError(dateResult.error?.message ?? "Could not resolve the service day."); setLoading(false); return; }
    const currentDate = String(dateResult.data); setBusinessDate(currentDate);
    const shiftsResult = await supabase.from("shifts").select("*").eq("location_id", currentLocation.id).order("business_date", { ascending: false }).order("started_at", { ascending: false });
    if (shiftsResult.error) { setError(shiftsResult.error.message); setLoading(false); return; }
    setShifts((shiftsResult.data ?? []) as Shift[]);
    const membershipRows = await supabase.from("restaurant_memberships").select("id, user_id, role").eq("restaurant_id", membership.restaurant_id);
    const memberRows = (membershipRows.data ?? []) as Array<{ id: string; user_id: string; role: string }>;
    const profileRows = memberRows.length ? await supabase.from("profiles").select("id, display_name").in("id", memberRows.map((row) => row.user_id)) : { data: [] };
    const names = new Map(((profileRows.data ?? []) as Array<{ id: string; display_name: string | null }>).map((row) => [row.id, row.display_name ?? ""]));
    setMembers(memberRows.map((row) => ({ ...row, display_name: names.get(row.user_id) ?? "" })));
    setLoading(false);
  }

  // The workspace reloads after auth events and after every database mutation.
  // eslint-disable-next-line react-hooks/exhaustive-deps, react-hooks/set-state-in-effect
  useEffect(() => { void loadWorkspace(); if (!supabase) return; const { data } = supabase.auth.onAuthStateChange(() => { void loadWorkspace(); }); return () => data.subscription.unsubscribe(); }, [supabase]);

  async function runClockAction(action: "start_shift" | "end_shift", shiftId?: string) {
    if (!supabase || !location || !navigator.onLine) { setError("You are offline. Clock actions need a live connection and were not saved."); return; }
    setBusy(true); setError("");
    const result = action === "start_shift" ? await supabase.rpc(action, { p_location_id: location.id }) : await supabase.rpc(action, { p_shift_id: shiftId });
    if (result.error) setError(result.error.message); else await loadWorkspace();
    setBusy(false);
  }

  async function saveCorrection() {
    if (!supabase || !location || !editing) return;
    setBusy(true); setError("");
    try {
      const startedAt = localDateTimeToInstant(correction.startedAt, location.timezone);
      const endedAt = correction.endedAt ? localDateTimeToInstant(correction.endedAt, location.timezone) : null;
      const result = await supabase.rpc("correct_shift", { p_shift_id: editing.id, p_started_at: startedAt, p_ended_at: endedAt, p_reason: correction.reason });
      if (result.error) throw result.error;
      setEditing(null); await loadWorkspace();
    } catch (caught) { setError(caught instanceof Error ? caught.message : "Shift correction could not be saved."); }
    setBusy(false);
  }

  if (!userId) return <main className="app-shell"><section className="card auth-card"><div className="kicker">KAFKA</div><h1>Shifts</h1><p className="sub">Open Revenue first to sign in, then return here to clock in and out.</p><button className="btn" onClick={onOpenRevenue}>Go to sign in</button></section></main>;
  if (loading || !location) return <main className="app-shell"><div className="kicker">KAFKA</div><h1>Shifts</h1><p className="muted">Loading the team…</p></main>;

  const ownShifts = shifts.filter((shift) => shift.membership_id === membershipId);
  const currentShift = ownShifts.find((shift) => !shift.ended_at) ?? ownShifts.find((shift) => shift.business_date === businessDate);
  const workingNow = shifts.filter((shift) => !shift.ended_at);
  const memberById = new Map(members.map((member) => [member.id, member]));
  const membersWithShifts = members.filter((member) => shifts.some((shift) => shift.membership_id === member.id));

  return <main className="app-shell">
    <div className="module-nav"><button onClick={onOpenRevenue}>Revenue</button><button className="active">Shifts</button></div>
    <header className="top"><div><div className="kicker">KAFKA</div><h1>Shifts</h1></div><button className="avatar" aria-label="Sign out" onClick={() => { void supabase?.auth.signOut(); }}>K</button></header>
    <p className="muted">{location.name} · service day {businessDate}</p>
    <div className="banner">● Connected · clock times come from the database</div>
    {error && <p className="error" role="alert">{error}</p>}
    <section className="card status-card"><div className="kicker">YOUR SHIFT</div>{currentShift && !currentShift.ended_at ? <><h2>Working since {formatShiftTime(currentShift.started_at, location.timezone)}</h2><p className="sub">Keep this shift open until you finish.</p><button className="btn" disabled={busy} onClick={() => void runClockAction("end_shift", currentShift.id)}>{busy ? "Saving…" : "End shift"}</button></> : currentShift ? <><h2>Shift complete</h2><p className="sub">You already have a shift for this service day.</p></> : <><h2>Not clocked in</h2><p className="sub">Start when you begin work. The database records the exact time.</p><button className="btn" disabled={busy} onClick={() => void runClockAction("start_shift")}>{busy ? "Saving…" : "Start shift"}</button></>}</section>
    <section className="card"><div className="kicker">YOUR HOURS</div><h2>Finalized totals</h2><p className="sub">Open shifts appear above but are not counted until ended.</p><PeriodTotals shifts={ownShifts} businessDate={businessDate} /></section>
    <section className="card"><div className="kicker">YOUR HISTORY</div><h2>Recent shifts</h2>{ownShifts.filter((shift) => shift.ended_at).slice(0, 8).map((shift) => <ShiftLine key={shift.id} shift={shift} location={location} />)}{ownShifts.filter((shift) => shift.ended_at).length === 0 && <p className="muted">No completed shifts yet.</p>}</section>
    {owner && <>
      <section className="card"><div className="kicker">WORKING NOW</div><h2>{workingNow.length === 0 ? "Nobody clocked in" : `${workingNow.length} working`}</h2>{workingNow.map((shift) => <ShiftLine key={shift.id} shift={shift} location={location} member={memberById.get(shift.membership_id)} />)}</section>
      <section className="card"><div className="kicker">TEAM TOTALS</div><h2>Hours by employee</h2>{membersWithShifts.map((member) => { const memberShifts = shifts.filter((shift) => shift.membership_id === member.id); const day = totalForBusinessDate(memberShifts, businessDate); const week = totalForPeriod(memberShifts, businessDate, "week"); const month = totalForPeriod(memberShifts, businessDate, "month"); return <div className="team-total" key={member.id}><div><strong>{displayName(member)}</strong><div className="muted">Today {formatDuration(day.minutes)} · week {formatDuration(week.minutes)}</div></div><strong>{formatDuration(month.minutes)}<small> this month</small></strong></div>; })}</section>
      <section className="card"><div className="kicker">SHIFT HISTORY</div><h2>All shifts</h2>{shifts.map((shift) => <ShiftLine key={shift.id} shift={shift} location={location} member={memberById.get(shift.membership_id)} onCorrect={(selected) => { setEditing(selected); setCorrection({ startedAt: instantToLocalDateTime(selected.started_at, location.timezone), endedAt: instantToLocalDateTime(selected.ended_at, location.timezone), reason: "" }); }} />)}</section>
      {editing && <section className="card"><div className="kicker">OWNER CORRECTION</div><h2>Correct {formatShiftDate(editing.business_date)}</h2><p className="sub">The previous timestamps will remain in the append-only audit history.</p><label className="field"><span>Start time ({location.timezone})</span><div className="input-wrap"><input type="datetime-local" value={correction.startedAt} onChange={(event) => setCorrection((current) => ({ ...current, startedAt: event.target.value }))} /></div></label><label className="field"><span>End time ({location.timezone})</span><div className="input-wrap"><input type="datetime-local" value={correction.endedAt} onChange={(event) => setCorrection((current) => ({ ...current, endedAt: event.target.value }))} /></div></label><label className="field"><span>Correction reason (required)</span><textarea required value={correction.reason} onChange={(event) => setCorrection((current) => ({ ...current, reason: event.target.value }))} /></label><button className="btn" disabled={busy || !correction.reason.trim() || !correction.startedAt} onClick={() => void saveCorrection()}>{busy ? "Saving…" : "Save audited correction"}</button><button className="btn secondary" disabled={busy} onClick={() => setEditing(null)}>Cancel</button></section>}
    </>}
  </main>;
}
