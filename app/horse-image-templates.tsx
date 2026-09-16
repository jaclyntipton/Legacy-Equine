/* eslint-disable @next/next/no-img-element */
"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { GAME } from "@/lib/game/config";
const supabase = createClient();
type Kind =
  | "body_template"
  | "base_coat"
  | "modifier"
  | "pattern"
  | "face_marking"
  | "leg_marking"
  | "leg_points"
  | "mane"
  | "tail"
  | "clean_body";
type Asset = {
  id: string;
  asset_key: string;
  asset_type: Kind;
  breed: string | null;
  sex: "Mare" | "Stallion" | null;
  phenotype_key: string | null;
  marking_key: string | null;
  leg_position: string | null;
  image_url: string;
  z_index: number;
  status: "pending" | "approved" | "rejected";
  active: boolean;
  review_notes: string;
  immutable_source?: boolean;
};
const kinds: Kind[] = [
    "body_template",
    "base_coat",
    "modifier",
    "pattern",
    "face_marking",
    "leg_marking",
    "leg_points",
    "mane",
    "tail",
    "clean_body",
  ],
  blank = {
    asset_key: "",
    asset_type: "body_template" as Kind,
    breed: GAME.foundationBreeds[0] as string,
    sex: "",
    phenotype_key: "",
    marking_key: "",
    leg_position: "",
    image_url: "",
    z_index: 0,
  };
const qhMareProof = ["sorrel", "bay", "black", "palomino", "buckskin"];
const proofRevision = "2026-09-16-stallion-black-mane-3";
const hairTreatments = ["Chestnut", "Black", "Flaxen / Cream"] as const;
const qhHairMasters = [
  { key: "qh_mare_master_01", label: "Quarter Horse Mare Master 01", sex: "Mare", source: "/horse-visuals/masters/qh_mare_master_01.png" },
  { key: "qh_stallion_master_01", label: "Quarter Horse Stallion Master 01", sex: "Stallion", source: "/horse-visuals/masters/qh_stallion_master_01.png" },
] as const;
const qhMareMarkingProof = [
  "no-markings",
  "star-only",
  "blaze-only",
  "lf-sock-only",
  "rh-stocking-only",
  "blaze-lf-sock-rh-stocking",
];
type ProofSelection = {
  key: string;
  label: string;
  base: string;
  master: string;
  subject: string;
  approved: boolean;
};
export function HorseImageTemplates({
  notify,
}: {
  notify: (s: string) => void;
  changed: () => void;
}) {
  const [assets, setAssets] = useState<Asset[]>([]),
    [form, setForm] = useState(blank),
    [editing, setEditing] = useState<string | null>(null),
    [busy, setBusy] = useState(false),
    [selectedProof, setSelectedProof] = useState<ProofSelection | null>(null),
    [compareMaster, setCompareMaster] = useState(false),
    [preview, setPreview] = useState({
      breed: GAME.foundationBreeds[0] as string,
      sex: "Mare",
      color: "palomino",
      pattern: "none",
      face: "blaze",
      left_front: "sock",
      right_front: "none",
      left_hind: "stocking",
      right_hind: "sock",
    });
  const load = useCallback(async () => {
    const { data, error } = await supabase.rpc(
      "admin_list_horse_visual_assets",
    );
    if (error) notify(error.message);
    else setAssets((data ?? []) as Asset[]);
  }, [notify]);
  useEffect(() => {
    void load();
  }, [load]);
  const upload = async (file: File) => {
    if (
      !["image/png", "image/webp"].includes(file.type) ||
      file.size > 5 * 1024 * 1024
    ) {
      notify("Visual layers must be transparent PNG or WebP files under 5 MB.");
      return;
    }
    setBusy(true);
    const { data: user } = await supabase.auth.getUser(),
      path = `${user.user!.id}/visual-library/${crypto.randomUUID()}-${file.name.replace(/[^a-zA-Z0-9._-]/g, "-")}`,
      result = await supabase.storage
        .from("legacy-equine-media")
        .upload(path, file, { upsert: false });
    if (result.error) notify(result.error.message);
    else
      setForm((x) => ({
        ...x,
        image_url: supabase.storage
          .from("legacy-equine-media")
          .getPublicUrl(path).data.publicUrl,
      }));
    setBusy(false);
  };
  const save = async () => {
    setBusy(true);
    const { error } = await supabase.rpc("admin_save_horse_visual_asset", {
      p_id: editing,
      p_asset_key: form.asset_key,
      p_asset_type: form.asset_type,
      p_breed: form.breed,
      p_sex: form.sex,
      p_phenotype_key: form.phenotype_key,
      p_marking_key: form.marking_key,
      p_leg_position: form.leg_position,
      p_image_url: form.image_url,
      p_z_index: form.z_index,
    });
    notify(error?.message ?? "Visual asset saved as pending review.");
    if (!error) {
      setEditing(null);
      setForm(blank);
      await load();
    }
    setBusy(false);
  };
  const review = async (
    asset: Asset,
    status: "approved" | "rejected",
    active: boolean,
  ) => {
    const { error } = await supabase.rpc("admin_review_horse_visual_asset", {
      p_id: asset.id,
      p_status: status,
      p_active: active,
      p_notes: prompt("Review notes") ?? "",
    });
    notify(error?.message ?? `Visual asset ${status}.`);
    if (!error) await load();
  };
  const layers = useMemo(
    () =>
      assets
        .filter(
          (a) =>
            a.status === "approved" &&
            a.active &&
            (a.breed == null || a.breed === "*" || a.breed === preview.breed) &&
            (a.sex == null || a.sex === preview.sex) &&
            (a.asset_type === "body_template" ||
              (a.asset_type === "base_coat" &&
                a.phenotype_key === preview.color) ||
              (a.asset_type === "modifier" &&
                a.phenotype_key === preview.color) ||
              (a.asset_type === "pattern" &&
                a.marking_key === preview.pattern) ||
              (a.asset_type === "face_marking" &&
                a.marking_key === preview.face) ||
              (a.asset_type === "leg_marking" &&
                a.leg_position &&
                a.marking_key ===
                  preview[a.leg_position as keyof typeof preview]) ||
              ((a.asset_type === "mane" || a.asset_type === "tail") &&
                a.phenotype_key === preview.color)),
        )
        .sort((a, b) => a.z_index - b.z_index),
    [assets, preview],
  );
  return (
    <section className="panel visuallibrary">
      <p className="eyebrow">OWNER / ADMIN · APPROVED ASSETS ONLY</p>
      <h2>Horse Visual Library</h2>
      <p className="panelsub">
        Production horses are assembled deterministically from reviewed breed
        templates and genetic phenotype layers. This library never changes horse
        genetics.
      </p>
      <section className="coatproof">
        <p className="eyebrow">
          QUARTER HORSE MARE MASTER 01 · APPROVED · LOCKED
        </p>
        <h3>Same locked conformation, five test phenotypes</h3>
        <p className="panelsub">
          These owner-approved composites preserve the master’s exact canvas,
          alpha silhouette, anatomy, pigment maps, texture, and anatomy-aware
          transitions. The approved assets remain disconnected from Store horses.
        </p>
        <div className="coatproofgrid">
          {qhMareProof.map((coat) => (
            <figure key={coat}>
              <button
                type="button"
                onClick={() => {
                  setSelectedProof({ key: coat, label: coat, base: "/horse-visuals/proofs/qh_mare_master_01", master: "/horse-visuals/masters/qh_mare_master_01.png", subject: "Quarter Horse Mare", approved: true });
                  setCompareMaster(false);
                }}
                aria-label={`Inspect ${coat} proof at full size`}
              >
                <img
                  src={`/horse-visuals/proofs/qh_mare_master_01/${coat}.png?rev=${proofRevision}`}
                  alt={`Quarter Horse mare ${coat} phenotype proof`}
                />
              </button>
              <figcaption>{coat}</figcaption>
            </figure>
          ))}
        </div>
        <details>
          <summary>Non-destructive marking workflow</summary>
          <p>
            The immutable master stays untouched. An anatomy alpha mask and a
            separate source-white-markings mask are derived alongside coat
            tests. Production marking layers will be built only after a clean,
            human-reviewed neutral coat master is available; automated
            inpainting will not overwrite or invent master anatomy.
          </p>
        </details>
      </section>
      <section className="coatproof hairassetarchitecture">
        <p className="eyebrow">INDEPENDENT HAIR ASSETS · AWAITING HUMAN ARTWORK</p>
        <h3>Quarter Horse mane and tail registration</h3>
        <p className="panelsub">The rejected stallion coat proof has been removed from review. Mane and tail are now separate transparent artwork layers bound to one exact body master. No procedural hair mask is eligible for production.</p>
        {qhHairMasters.map((master) => (
          <article className="hairmaster" key={master.key}>
            <header>
              <div><p className="eyebrow">{master.key} · LOCKED SOURCE</p><h4>{master.label}</h4></div>
              <span className="reviewbadge">ASSETS NEEDED</span>
            </header>
            <div className="hairalignment">
              <figure>
                <img src={master.source} alt={`${master.label} immutable alignment reference`} />
                <figcaption>Registration reference · exact master canvas</figcaption>
              </figure>
              <div className="alignmentdetails">
                <b>Layer alignment contract</b>
                <span>Canvas: 1500 × 1024 px</span>
                <span>Origin: 0, 0</span>
                <span>Scale: 100%</span>
                <span>Transform: none</span>
                <span>Required format: transparent PNG/WebP</span>
                <span>Bound sex: {master.sex}</span>
              </div>
            </div>
            <div className="hairslots" aria-label={`${master.label} mane and tail asset slots`}>
              {hairTreatments.flatMap((treatment) => ["Mane", "Tail"].map((part) => (
                <div className="hairslot" key={`${part}-${treatment}`}>
                  <span>{part}</span><b>{treatment}</b><small>Awaiting approved transparent artwork</small>
                </div>
              )))}
            </div>
            <div className="cleanbodyslot">
              <b>Clean derived body</b>
              <span>Required because the immutable source contains mane and tail pixels.</span>
              <small>Awaiting a human-reviewed, non-destructive derived asset. The immutable master will not be overwritten or inpainted automatically.</small>
            </div>
          </article>
        ))}
      </section>
      <section className="coatproof">
        <p className="eyebrow">QUARTER HORSE MARE MASTER 01 · WHITE MARKINGS · REVIEW ONLY</p>
        <h3>Independent face and leg marking proof</h3>
        <p className="panelsub">The same approved Sorrel mare is shown with independently controlled markings. Every variant retains the immutable master canvas, alpha silhouette, anatomy, hoof geometry, and coat shading.</p>
        <div className="coatproofgrid" style={{ gridTemplateColumns: "repeat(3, minmax(0, 1fr))" }}>
          {qhMareMarkingProof.map((marking) => {
            const label = marking.replaceAll("-", " ");
            return (
              <figure key={marking}>
                <button type="button" onClick={() => { setSelectedProof({ key: marking, label, base: "/horse-visuals/proofs/qh_mare_master_01/markings", master: "/horse-visuals/masters/qh_mare_master_01.png", subject: "Quarter Horse Mare", approved: false }); setCompareMaster(false); }} aria-label={`Inspect ${label} proof at full size`}>
                  <img src={`/horse-visuals/proofs/qh_mare_master_01/markings/${marking}.png?rev=${proofRevision}`} alt={`Quarter Horse mare ${label} proof`} />
                </button>
                <figcaption>{label}</figcaption>
              </figure>
            );
          })}
        </div>
      </section>
      {selectedProof && (
        <div
          className="prooflightbox"
          role="dialog"
          aria-modal="true"
          aria-label={`${selectedProof.label} full-size proof`}
          onClick={() => setSelectedProof(null)}
        >
          <section onClick={(event) => event.stopPropagation()}>
            <header>
              <div>
                <p className="eyebrow">{selectedProof.approved ? "APPROVED · LOCKED" : "REVIEW ONLY · NOT APPROVED"}</p>
                <h3>
                  {selectedProof.label.replace(/\b\w/g, (letter) => letter.toUpperCase())}{" "}{selectedProof.subject}
                </h3>
              </div>
              <button
                type="button"
                onClick={() => setSelectedProof(null)}
                aria-label="Close full-size proof"
              >
                ×
              </button>
            </header>
            <div
              className={
                compareMaster ? "proofcompare is-comparing" : "proofcompare"
              }
            >
              <figure>
                <img
                  src={`${selectedProof.base}/${selectedProof.key}.png?rev=${proofRevision}`}
                  alt={`${selectedProof.label} full-resolution proof`}
                />
                <figcaption>{selectedProof.label} proof</figcaption>
              </figure>
              {compareMaster && (
                <figure>
                  <img
                  src={selectedProof.master}
                  alt={`Immutable ${selectedProof.subject} master reference`}
                  />
                  <figcaption>Immutable source master</figcaption>
                </figure>
              )}
            </div>
            <button
              type="button"
              className="secondary"
              onClick={() => setCompareMaster((value) => !value)}
            >
              {compareMaster ? "Hide Master" : "Compare to Master"}
            </button>
          </section>
        </div>
      )}
      <div className="adminformgrid">
        <label>
          Asset key
          <input
            placeholder="morgan_mare_02"
            value={form.asset_key}
            onChange={(e) => setForm({ ...form, asset_key: e.target.value })}
          />
        </label>
        <label>
          Layer type
          <select
            value={form.asset_type}
            onChange={(e) =>
              setForm({ ...form, asset_type: e.target.value as Kind })
            }
          >
            {kinds.map((x) => (
              <option key={x} value={x}>
                {x.replaceAll("_", " ")}
              </option>
            ))}
          </select>
        </label>
        <label>
          Breed
          <select
            value={form.breed}
            onChange={(e) => setForm({ ...form, breed: e.target.value })}
          >
            <option value="*">Generic fallback</option>
            {GAME.foundationBreeds.map((x) => (
              <option key={x}>{x}</option>
            ))}
          </select>
        </label>
        <label>
          Sex
          <select
            value={form.sex}
            onChange={(e) => setForm({ ...form, sex: e.target.value })}
          >
            <option value="">Any</option>
            <option>Mare</option>
            <option>Stallion</option>
          </select>
        </label>
        <label>
          Phenotype key
          <input
            placeholder="palomino"
            value={form.phenotype_key}
            onChange={(e) =>
              setForm({ ...form, phenotype_key: e.target.value.toLowerCase() })
            }
          />
        </label>
        <label>
          Marking key
          <input
            placeholder="blaze / sock / tobiano"
            value={form.marking_key}
            onChange={(e) =>
              setForm({ ...form, marking_key: e.target.value.toLowerCase() })
            }
          />
        </label>
        <label>
          Leg position
          <select
            value={form.leg_position}
            onChange={(e) => setForm({ ...form, leg_position: e.target.value })}
          >
            <option value="">Not a leg layer</option>
            {["left_front", "right_front", "left_hind", "right_hind"].map(
              (x) => (
                <option key={x}>{x}</option>
              ),
            )}
          </select>
        </label>
        <label>
          Layer order
          <input
            type="number"
            value={form.z_index}
            onChange={(e) =>
              setForm({ ...form, z_index: Number(e.target.value) })
            }
          />
        </label>
        <label>
          Transparent asset
          <input
            type="file"
            accept="image/png,image/webp"
            onChange={(e) =>
              e.target.files?.[0] && void upload(e.target.files[0])
            }
          />
        </label>
      </div>
      <button
        className="primary"
        disabled={busy || !form.asset_key.trim() || !form.image_url}
        onClick={save}
      >
        {editing ? "Save Replacement for Review" : "Add Pending Asset"}
      </button>
      <h3>Preview Horse Combination</h3>
      <div className="visualpreviewcontrols">
        <select
          value={preview.breed}
          onChange={(e) => setPreview({ ...preview, breed: e.target.value })}
        >
          {GAME.foundationBreeds.map((x) => (
            <option key={x}>{x}</option>
          ))}
        </select>
        <select
          value={preview.sex}
          onChange={(e) => setPreview({ ...preview, sex: e.target.value })}
        >
          <option>Mare</option>
          <option>Stallion</option>
        </select>
        <input
          aria-label="Preview color"
          value={preview.color}
          onChange={(e) =>
            setPreview({ ...preview, color: e.target.value.toLowerCase() })
          }
        />
        <input
          aria-label="Preview pattern"
          value={preview.pattern}
          onChange={(e) =>
            setPreview({ ...preview, pattern: e.target.value.toLowerCase() })
          }
        />
        <input
          aria-label="Preview face"
          value={preview.face}
          onChange={(e) =>
            setPreview({ ...preview, face: e.target.value.toLowerCase() })
          }
        />
      </div>
      <div className="layerpreview">
        {layers.map((a) => (
          <img
            key={a.id}
            src={a.image_url}
            alt=""
            style={{ zIndex: a.z_index }}
          />
        ))}
        {!layers.length && (
          <div className="visualpending"><strong>LEGACY EQUINE™</strong><span>Horse Visual Pending</span><small>{preview.breed} · {preview.color}</small></div>
        )}
      </div>
      <small>
        {layers.length
          ? layers.map((x) => x.asset_key).join(" → ")
          : "Incomplete combination — branded visual-pending state"}
      </small>
      <div className="templategrid">
        {assets.map((a) => (
          <article key={a.id}>
            <img src={a.image_url} alt={a.asset_key} />
            <p className="eyebrow">
              {a.asset_type} · {a.status}
              {a.active ? " · ACTIVE" : ""}
              {a.immutable_source ? " · LOCKED SOURCE" : ""}
            </p>
            <h3>{a.asset_key}</h3>
            <p>
              {a.breed ?? "Any breed"} · {a.sex ?? "Any sex"}
            </p>
            {!a.immutable_source && (
              <div className="buttonrow">
                <button
                  onClick={() => {
                    setEditing(a.id);
                    setForm({
                      asset_key: a.asset_key,
                      asset_type: a.asset_type,
                      breed: a.breed ?? "*",
                      sex: a.sex ?? "",
                      phenotype_key: a.phenotype_key ?? "",
                      marking_key: a.marking_key ?? "",
                      leg_position: a.leg_position ?? "",
                      image_url: a.image_url,
                      z_index: a.z_index,
                    });
                  }}
                >
                  Replace
                </button>
                {a.status !== "approved" && (
                  <button onClick={() => void review(a, "approved", true)}>
                    Approve & Activate
                  </button>
                )}
                {a.status === "approved" && (
                  <button onClick={() => void review(a, "approved", !a.active)}>
                    {a.active ? "Deactivate" : "Activate"}
                  </button>
                )}
                <button onClick={() => void review(a, "rejected", false)}>
                  Reject
                </button>
              </div>
            )}
          </article>
        ))}
      </div>
    </section>
  );
}
