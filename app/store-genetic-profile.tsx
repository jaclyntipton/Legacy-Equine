"use client";

import { useEffect, useState, type ReactNode } from "react";
import { foundationGeneticHealth } from "@/lib/game/foundation-genetic-health";
import { createClient } from "@/lib/supabase/client";
import styles from "./store-genetic-profile.module.css";

type Result = {horseId: string; genetics: Record<string, unknown> | null};

export function StoreGeneticsAndStats({ horseId, coat, children }: {horseId: string; coat: string; children: ReactNode}) {
  const [result, setResult] = useState<Result | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const {data, error} = await createClient().rpc("get_horse_visual_recipe", {p_horse_id: horseId});
        const genetics = data?.genetics;
        if (active) setResult({horseId, genetics: !error && genetics && typeof genetics === "object" ? genetics : null});
      } catch {
        if (active) setResult({horseId, genetics: null});
      }
    })();
    return () => { active = false; };
  }, [horseId, attempt]);

  const current = result?.horseId === horseId ? result : null;
  return (
    <div className={styles.layout}>
      {children}
      <section className={styles.profile} aria-label="Genetic Profile">
        <h2>Genetic Profile</h2>
        <p><strong>Coat &amp; pattern</strong> · {coat}</p>
        <h3>Inherited health variants</h3>
        {!current ? <p role="status">Loading genetic results…</p> : current.genetics === null ? (
          <p role="status">Genetic results unavailable. <button type="button" onClick={() => { setResult(null); setAttempt(value => value + 1); }}>Retry</button></p>
        ) : (
          <dl className={styles.results}>
            {foundationGeneticHealth(current.genetics).map(({locus, genotype, status}) => (
              <div key={locus}>
                <dt><strong>{locus}</strong>{genotype && <span>{genotype}</span>}</dt>
                <dd>{status}</dd>
              </div>
            ))}
          </dl>
        )}
      </section>
    </div>
  );
}
