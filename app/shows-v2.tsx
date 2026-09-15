"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { FormField } from "./form-field";

const supabase = createClient();
type Horse = { id: string; name: string; breed: string; career_points: number };
type Show = { id: string; name: string; discipline: string; tier: string; run_at: string; entry_fee: number; max_entries: number | null; entry_count: number; description: string; creator_name: string; creator_account: number; status: string };
type Ref = { id: string; name: string };

export function PlayerShows({ horses, notify, refreshAccount }: { horses: Horse[]; notify: (s: string) => void; refreshAccount: () => void }) {
  const [shows, setShows] = useState<Show[]>([]);
  const [disciplines, setDisciplines] = useState<Ref[]>([]);
  const [tiers, setTiers] = useState<Ref[]>([]);
  const [creating, setCreating] = useState(false);
  const [name, setName] = useState("");
  const [discipline, setDiscipline] = useState("racing");
  const [tier, setTier] = useState("novice");
  const [date, setDate] = useState("");
  const [fee, setFee] = useState(0);
  const [max, setMax] = useState("");
  const [description, setDescription] = useState("");
  const [choices, setChoices] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    const [{ data: s, error }, { data: d }, { data: t }] = await Promise.all([
      supabase.rpc("get_player_shows"),
      supabase.from("show_disciplines").select("id,name").eq("active", true),
      supabase.from("show_tiers").select("id,name").eq("active", true).order("sort_order"),
    ]);
    if (error) notify(error.message);
    setShows((s ?? []) as Show[]);
    setDisciplines((d ?? []) as Ref[]);
    setTiers((t ?? []) as Ref[]);
  }, [notify]);

  useEffect(() => {
    const timer = setTimeout(() => void load(), 0);
    return () => clearTimeout(timer);
  }, [load]);

  const valid = name.trim().length >= 3 && Boolean(date) && fee >= 0 && (!max || Number(max) >= 2);

  const create = async () => {
    if (!valid) return;
    const { error } = await supabase.rpc("create_player_show", {
      show_name: name,
      target_discipline: discipline,
      target_tier: tier,
      target_run_date: date,
      new_entry_fee: fee,
      new_max_entries: max ? Number(max) : null,
      new_description: description,
    });
    notify(error?.message ?? "Show created for midnight Eastern Time.");
    if (!error) {
      setCreating(false);
      await load();
      refreshAccount();
    }
  };

  const enter = async (showId: string) => {
    const horse = choices[showId];
    if (!horse) return;
    const { error } = await supabase.rpc("enter_player_show", { target_show: showId, target_horse: horse });
    notify(error?.message ?? "Show entry confirmed and tier eligibility snapshotted.");
    if (!error) {
      await load();
      refreshAccount();
    }
  };

  return <>
    <header className="title">
      <p className="eyebrow">PLAYER-HOSTED COMPETITION</p>
      <h2>Legacy Equine Shows</h2>
      <p>Deterministic, stat-based competition. Tack and active approved service effects count; random rolls do not.</p>
      <button className="primary" onClick={() => setCreating(!creating)}>{creating ? "Close Creator" : "Create Show"}</button>
    </header>
    {creating && <section className="panel showcreator">
      <h2>Create a Show</h2>
      <form className="show-form" onSubmit={(event) => { event.preventDefault(); void create(); }}>
        <div className="show-form-columns">
          <div className="show-form-column">
            <FormField id="show-name" label="Show Name">
              <input id="show-name" required minLength={3} value={name} onChange={(event) => setName(event.target.value)} />
            </FormField>
            <FormField id="show-tier" label="Career Point Tier">
              <select id="show-tier" value={tier} onChange={(event) => setTier(event.target.value)}>{tiers.map((item) => <option value={item.id} key={item.id}>{item.name}</option>)}</select>
            </FormField>
            <FormField id="show-fee" label="Entry Fee (LED)" helper="Optional — leave at 0 for a free show.">
              <input id="show-fee" type="number" min={0} required value={fee} onChange={(event) => setFee(Number(event.target.value))} />
            </FormField>
          </div>
          <div className="show-form-column">
            <FormField id="show-discipline" label="Discipline">
              <select id="show-discipline" value={discipline} onChange={(event) => setDiscipline(event.target.value)}>{disciplines.map((item) => <option value={item.id} key={item.id}>{item.name}</option>)}</select>
            </FormField>
            <FormField id="show-date" label="Run Date" helper="Runs at 12:00 AM Eastern Time.">
              <input id="show-date" type="date" required value={date} onChange={(event) => setDate(event.target.value)} />
            </FormField>
            <FormField id="show-maximum" label="Maximum Entries" helper="Optional — leave blank for no maximum.">
              <input id="show-maximum" type="number" min={2} placeholder="No maximum" value={max} onChange={(event) => setMax(event.target.value)} />
            </FormField>
          </div>
        </div>
        <FormField id="show-description" label="Description">
          <textarea id="show-description" rows={4} value={description} onChange={(event) => setDescription(event.target.value)} />
        </FormField>
        <div className="show-form-actions">
          {!valid && <p className="form-status" role="status">Add a show name and run date to create the show.</p>}
          <button className="primary" type="submit" disabled={!valid}>Create Show</button>
        </div>
      </form>
    </section>}
    <div className="featuregrid">{shows.map((show) => <article className="featurecard showcard" key={show.id}>
      <div className="showmark">◇</div><div><p className="eyebrow">{show.discipline} · {show.tier}</p><h3>{show.name}</h3><p>{show.description || "A player-hosted Legacy Equine competition."}</p><p><b>Hosted by {show.creator_name} #{show.creator_account}</b></p><p>{new Date(show.run_at).toLocaleString([], { timeZone: "America/New_York" })} · {show.entry_count}{show.max_entries ? ` / ${show.max_entries}` : ""} entries · {show.entry_fee} LED</p>{show.status === "open" && <><select aria-label={`Horse for ${show.name}`} value={choices[show.id] ?? ""} onChange={(event) => setChoices({ ...choices, [show.id]: event.target.value })}><option value="">Choose an eligible horse…</option>{horses.map((horse) => <option value={horse.id} key={horse.id}>{horse.name} · {horse.career_points ?? 0} Career Points</option>)}</select><button className="primary" disabled={!choices[show.id]} onClick={() => enter(show.id)}>Enter Show</button></>}</div>
    </article>)}</div>
    {!shows.length && <p className="featurehint">No player-created shows yet. Host the first one.</p>}
  </>;
}
