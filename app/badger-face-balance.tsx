"use client";

import {useCallback, useEffect, useState} from "react";
import {createClient} from "@/lib/supabase/client";

const rarities = ["common", "uncommon", "rare", "exceptional"];

export function BadgerFaceBalance() {
  const [enabled, setEnabled] = useState(false);
  const [percent, setPercent] = useState("");
  const [rarity, setRarity] = useState("rare");
  const [loaded, setLoaded] = useState(false);
  const [busy, setBusy] = useState(false);
  const [feedback, setFeedback] = useState("");

  const load = useCallback(async () => {
    setBusy(true);
    setFeedback("");
    try {
      const {data, error} = await createClient().rpc("admin_get_badger_face_balance");
      if (error || !data) throw new Error(error?.message ?? "Settings unavailable.");
      setEnabled(data.enabled);
      setPercent(String(data.percent));
      setRarity(data.rarity ?? "rare");
      setLoaded(true);
    } catch {
      setFeedback("Badger Face settings could not be loaded.");
    } finally {
      setBusy(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  async function save() {
    const rate = Number(percent);
    if (!percent.trim() || !Number.isFinite(rate) || rate < 0 || rate > 100 || (enabled && rate === 0)) {
      setFeedback("Enter a rate from 0 to 100%. Enabled generation requires a rate above 0%.");
      return;
    }
    setBusy(true);
    setFeedback("");
    try {
      const {data, error} = await createClient().rpc("admin_set_badger_face_balance", {
        p_enabled: enabled,
        p_percent: rate,
        p_rarity: rarity,
      });
      if (error || !data) throw new Error(error?.message ?? "Save failed.");
      setEnabled(data.enabled);
      setPercent(String(data.percent));
      setRarity(data.rarity);
      setFeedback(data.enabled ? `Saved. Appearance rate is ${data.percent}%.` : "Saved. Generation is off.");
    } catch {
      setFeedback("Badger Face settings could not be saved. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return <div>
    <span><b>Badger Face</b><small>badger_face_01</small></span>
    <span>Face marking</span>
    <label>
      <input aria-label="Badger Face appearance rate (%)" type="number" min="0" max="100" step="any"
        value={percent} disabled={busy || !loaded || !enabled} onChange={e=>setPercent(e.target.value)}/>
      <small>% per horse</small>
    </label>
    <select aria-label="Badger Face rarity" value={enabled ? rarity : "not_generated"}
      disabled={busy || !loaded || !enabled} onChange={e=>setRarity(e.target.value)}>
      {rarities.map(value => <option key={value}>{value}</option>)}
      {!enabled && <option value="not_generated">not generated</option>}
    </select>
    <label className="geneticstoggle">
      <input type="checkbox" aria-label="Enable Badger Face generation" checked={enabled}
        disabled={busy || !loaded} onChange={e=>setEnabled(e.target.checked)}/>
      <span>{enabled ? "Generated" : "Excluded"}</span>
    </label>
    <span>
      {loaded ? <button type="button" disabled={busy} aria-label="Save Badger Face settings" onClick={()=>void save()}>{busy?"Saving…":"Save"}</button>
        : busy ? <small>Loading…</small> : <button type="button" onClick={()=>void load()}>Retry</button>}
      {feedback && <small role="status">{feedback}</small>}
    </span>
  </div>;
}
