import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const roots = ["qh_mare_master_01", "qh_stallion_master_01"];
const traits = [
  "tobiano", "frame_overo", "sabino", "sabino_roaning", "splash_white",
  "medicine_hat", "tovero", "lp_blanket", "lp_snowcap", "lp_spotted_blanket",
  "lp_leopard", "lp_fewspot", "lp_snowflake", "lp_varnish_roan",
];
const guardedElement = {
  tobiano: "body", frame_overo: "body", sabino: "belly", sabino_roaning: "speckle",
  splash_white: "belly", medicine_hat: "fill", tovero: "fill", lp_blanket: "fill",
  lp_snowcap: "fill", lp_spotted_blanket: "fill", lp_leopard: "fill", lp_fewspot: "fill",
  lp_snowflake: "flecks", lp_varnish_roan: "speckle",
};

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
    svg = svg.replace(new RegExp(`<path id="${layerId}__rear-overlap-guard"[^>]+/>`), "");
    const guardId = `${layerId}__rear-overlap-guard`;
    const guard = `<mask id="${guardId}" maskUnits="userSpaceOnUse" x="0" y="0" width="1496" height="1051"><rect width="1496" height="1051" fill="#ffffff"/><path fill="#000000" fill-rule="evenodd" d="${lhReference[1]}"/></mask>`;
    if (!svg.includes(`<mask id="${guardId}"`)) svg = svg.replace("</defs>", `${guard}\n</defs>`);
    const elementId = `${layerId}__${guardedElement[trait]}`;
    const directGuard = `id="${elementId}" mask="url(#${guardId})"`;
    const element = new RegExp(`(<(?:path|rect|g) id="${elementId}")(?![^>]*mask=)`);
    if (element.test(svg)) {
      svg = svg.replace(element, `$1 mask="url(#${guardId})"`);
    } else if (!svg.includes(directGuard) && !svg.includes(`<g mask="url(#${guardId})"><rect id="${elementId}"`)) {
      const maskedElement = new RegExp(`(<rect id="${elementId}"[^>]*/>)`);
      if (!maskedElement.test(svg)) throw new Error(`Missing guarded element ${elementId}`);
      svg = svg.replace(maskedElement, `<g mask="url(#${guardId})">$1</g>`);
    }
    fs.writeFileSync(file, svg);
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

const foalDirectory = "public/horse-visuals/coat-layers/qh_foal_master_01/layers";
const foalPollUndercoatPath = "M1158,92 C1183,84 1215,88 1240,103 C1246,109 1249,117 1248,126 C1232,128 1218,126 1204,122 C1187,117 1171,113 1158,109Z";
const foalBaseColors = {
  bay: "#7E4426",
  black: "#2E2829",
  brown: "#3E2820",
  chestnut: "#A65A2E",
};

for (const [trait, color] of Object.entries(foalBaseColors)) {
  const layerId = `qh_foal_master_01__base_${trait}`;
  const file = path.join(foalDirectory, `${layerId}.svg`);
  let svg = fs.readFileSync(file, "utf8");
  svg = svg.replace(new RegExp(`<path id="${layerId}__poll-undercoat"[^>]+/>\\n?`), "");
  svg = svg.replace("</svg>", `<path id="${layerId}__poll-undercoat" fill="${color}" d="${foalPollUndercoatPath}"/>\n</svg>`);
  fs.writeFileSync(file, svg);
  const record = foalManifest.layers.find(layer => layer.layer_id === layerId);
  if (!record) throw new Error(`Missing manifest record ${layerId}`);
  record.sha256 = digest(svg);
  record.svg_element_ids ??= [];
  record.svg_element_ids = record.svg_element_ids.filter(id => id !== `${layerId}__poll-undercoat`);
  record.svg_element_ids.push(`${layerId}__poll-undercoat`);
}

for (const trait of ["black", "chestnut"]) {
  const layerId = `qh_foal_master_01__mane_${trait}`;
  const file = path.join(foalDirectory, `${layerId}.svg`);
  let svg = fs.readFileSync(file, "utf8");
  svg = svg.replace(new RegExp(`<path id="${layerId}__poll_bridge"[^>]+/>\\n?`), "");
  fs.writeFileSync(file, svg);
  const record = foalManifest.layers.find(layer => layer.layer_id === layerId);
  if (!record) throw new Error(`Missing manifest record ${layerId}`);
  record.sha256 = digest(svg);
  record.svg_element_ids = (record.svg_element_ids ?? []).filter(id => id !== `${layerId}__poll_bridge`);
}
fs.writeFileSync(foalManifestPath, `${JSON.stringify(foalManifest, null, 1)}\n`);
