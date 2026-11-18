import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const roots = ["qh_mare_master_01", "qh_stallion_master_01"];
const traits = [
  "tobiano", "frame_overo", "sabino", "sabino_roaning", "splash_white",
  "medicine_hat", "tovero", "lp_blanket", "lp_snowcap", "lp_spotted_blanket",
  "lp_leopard", "lp_fewspot", "lp_snowflake", "lp_varnish_roan",
];

const digest = value => crypto.createHash("sha256").update(value).digest("hex");

for (const master of roots) {
  const directory = path.join("public/horse-visuals/coat-layers", master);
  const manifestPath = path.join(directory, "manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const anatomyReference = fs.readFileSync(path.join(directory, "layers", `${master}__tobiano.svg`), "utf8");
  const lhReference = anatomyReference.match(new RegExp(`<clipPath id="${master}__tobiano__lw-lh"><path clip-rule="evenodd" d="([^"]+)"/></clipPath>`));
  if (!lhReference) throw new Error(`Missing LH anatomy reference for ${master}`);

  for (const trait of traits) {
    const layerId = `${master}__${trait}`;
    const file = path.join(directory, "layers", `${layerId}.svg`);
    let svg = fs.readFileSync(file, "utf8");
    if (!svg.includes(`${layerId}__rear-overlap-guard`)) {
      const coatMask = new RegExp(`(<mask id="${layerId}__mask-coat"[\\s\\S]*?)(</mask>)`);
      if (!coatMask.test(svg)) throw new Error(`Missing coat mask in ${file}`);
      svg = svg.replace(coatMask, `$1<path id="${layerId}__rear-overlap-guard" fill="#000000" fill-rule="evenodd" d="${lhReference[1]}"/>$2`);
      fs.writeFileSync(file, svg);
    }
    const record = manifest.layers.find(layer => layer.layer_id === layerId);
    if (!record) throw new Error(`Missing manifest record ${layerId}`);
    record.sha256 = digest(svg);
    record.svg_element_ids ??= [];
    if (!record.svg_element_ids.includes(`${layerId}__rear-overlap-guard`)) {
      record.svg_element_ids.push(`${layerId}__rear-overlap-guard`);
    }
  }
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 1)}\n`);
}

const foalManifestPath = "public/horse-visuals/coat-layers/qh_foal_master_01/manifest.json";
const foalManifest = JSON.parse(fs.readFileSync(foalManifestPath, "utf8"));
for (const layer of foalManifest.layers) {
  if (layer.category === "mane" || layer.category === "tail") layer.stacking_order = 615;
}
fs.writeFileSync(foalManifestPath, `${JSON.stringify(foalManifest, null, 1)}\n`);
