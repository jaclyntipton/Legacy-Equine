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

if (!process.argv.includes("--foal-only")) for (const master of roots) {
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
const foalMalformedPollOutlineStarts = new Set([
  "M1246.4,94.9",
  "M1248.6,97.0",
  "M1259.9,112.4",
  "M1240.8,128.2",
  "M1262.1,123.9",
  "M1226.6,124.2",
  "M1260.3,134.4",
]);
const foalMalformedForelock = "M1257.8,136.5 L1236.1,135.2 L1234.2,134.0 L1227.1,125.9 L1224.2,120.9 L1223.8,112.7 L1225.2,111.6 L1227.8,111.1 L1230.2,112.6 L1232.0,112.6 L1233.5,111.3 L1236.6,110.7 L1238.2,107.7 L1236.3,104.5 L1226.2,104.1 L1223.3,103.0 L1220.3,105.7 L1218.1,94.2 L1219.5,91.9 L1239.1,85.4 L1248.3,86.4 L1251.7,89.2 L1256.7,94.8 L1256.3,99.1 L1262.9,105.9 L1267.8,116.4 L1268.6,121.4 L1268.3,122.8 L1265.5,125.7 L1257.0,132.5 L1256.9,133.8 L1258.5,135.6ZM1228.0,91.1 L1229.5,90.0 L1228.6,89.8 L1226.9,91.0Z";
const foalResidualForelockHoles = [
  "M1228.0,91.1 L1229.5,90.0 L1228.6,89.8 L1226.9,91.0Z",
  "M1232.2,112.4 L1237.2,110.1 L1238.2,107.7 L1237.6,105.5 L1232.7,103.6 L1226.2,104.1 L1223.3,103.0 L1222.5,103.5 L1217.3,113.3 L1221.7,110.4 L1226.7,108.6 L1230.3,108.6 L1230.6,109.7 L1228.9,111.7 L1230.4,112.7Z",
];
// Repair only the actual poll gap. Extending this bridge behind the left ear
// exposes white silhouette pixels between the ears after coat compositing.
const foalPollSilhouetteRepair = "M1164,119 C1178,109 1192,103 1207,104 C1214,104 1220,107 1224,112 L1222,117 L1216,113 L1207,110 L1198,111 L1190,118 L1184,126 L1168,129Z";
// Pigment the existing head/ear silhouette around the forelock. This is
// intentionally broader than the silhouette bridge because the legacy base
// masks omitted this region and otherwise leave white master pixels exposed.
const foalPollCoatRepair = "M1164,119 C1178,109 1192,103 1207,104 C1218,101 1228,102 1236,107 L1244,114 L1241,123 L1234,130 L1228,124 L1222,117 L1216,113 L1207,110 L1198,111 L1190,118 L1184,126 L1168,129Z";
// Approved foal poll redraw. The near ear occludes the continuous lock.
const foalFarEar = "M1218 104 C1226 91 1237 80 1247 71 C1254 64 1256 54 1264 46 C1262 60 1262 74 1258 87 C1255 98 1250 105 1243 109 C1234 112 1224 109 1218 104Z";
const foalNearEar = "M1188 113 C1192 105 1193 93 1197 82 C1203 66 1211 54 1226 46 C1226 54 1221 65 1221 75 C1221 87 1225 96 1220 105 C1217 112 1211 117 1204 117 C1198 119 1193 118 1188 113Z";
const foalEarArtwork = [
  `<path id="ear-left" fill="#d7d0c7" stroke="#43362e" stroke-width="2.5" stroke-linejoin="round" d="${foalFarEar}"/>`,
  '<path fill="#b7a89d" d="M1229 100 C1240 83 1255 75 1260 57 C1258 76 1253 92 1243 100 C1238 103 1234 103 1229 100Z"/>',
  `<path id="ear-right" fill="#e9e7e1" d="${foalNearEar}"/>`,
  '<path fill="#bcb0a4" d="M1195 110 C1199 97 1200 82 1209 67 C1213 61 1217 57 1221 54 C1216 66 1213 78 1214 89 C1216 99 1213 109 1207 113 C1203 116 1198 114 1195 110Z"/>',
  '<path fill="#fcfffc" d="M1193 108 C1197 82 1207 62 1222 51 C1212 62 1204 84 1201 100 C1199 107 1196 110 1193 108Z"/>',
  '<path fill="none" stroke="#4a3930" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round" d="M1189 113 C1193 105 1194 92 1197 82 C1203 66 1212 54 1226 46 C1226 54 1221 65 1221 75 C1221 87 1225 96 1220 105 C1218 110 1214 113 1210 115"/>',
].join("");
const foalForelockRepair = [
  "M1109 95 C1129 92 1147 91 1162 96 C1175 100 1183 96 1193 91 C1203 89 1216 94 1227 94",
  "C1243 94 1253 100 1257 111 C1262 123 1263 133 1274 143 C1265 141 1259 138 1255 135",
  "C1253 140 1255 144 1258 147 C1245 144 1234 138 1228 129 C1222 119 1219 114 1210 113",
  "C1195 112 1184 118 1168 120 C1147 123 1127 126 1109 127Z",
].join(" ");
const foalForelockHighlight = "M1130 99 C1155 95 1175 110 1196 104 C1210 101 1224 98 1236 102 C1253 107 1253 125 1264 135 C1253 128 1250 117 1244 111 C1231 98 1215 106 1199 108 C1176 113 1159 102 1130 99Z";
const foalMasterPath = "public/horse-visuals/vector-masters/qh_01/qh_foal_master_01.svg";
let foalMasterSvg = fs.readFileSync(foalMasterPath, "utf8");
foalMasterSvg = foalMasterSvg.replace(/<g id="redrawn-ears">.*?<\/g>\n?/, "");
foalMasterSvg = foalMasterSvg.replace(/<path id="ear-(left|right)"[^>]*\/>/g, "");
foalMasterSvg = foalMasterSvg.replace("</svg>", `<g id="redrawn-ears">${foalEarArtwork}</g>\n</svg>`);
foalMasterSvg = foalMasterSvg.replace(/<path id="poll-silhouette-repair"[^>]+\/>\n?/, "");
foalMasterSvg = foalMasterSvg.replace('<path id="head-base"', `<path id="poll-silhouette-repair" fill="#ffffff" d="${foalPollSilhouetteRepair}"/>\n<path id="head-base"`);
foalMasterSvg = foalMasterSvg.replace(/(<path id="mane-base"[^>]* d=")([^"]+)("\/?>)/, (match, prefix, d, suffix) => {
  let cleaned = d.replaceAll(foalMalformedForelock, "");
  for (const hole of foalResidualForelockHoles) cleaned = cleaned.replaceAll(hole, "");
  return `${prefix}${cleaned}${suffix}`;
});
foalMasterSvg = foalMasterSvg.replace(/(<path id="outline-lines"[^>]* d=")([^"]+)("\/?>)/, (match, prefix, d, suffix) => {
  const cleaned = d
    .split(/(?=M)/)
    .filter(subpath => {
      const start = subpath.match(/^M[-\d.]+,[-\d.]+/)?.[0];
      return start !== "M1149.4,97.8"
        && start !== "M1172.8,94.3"
        && start !== "M1198.5,129.8"
        && start !== "M1199.6,127.8"
        && !foalMalformedPollOutlineStarts.has(start);
    })
    .join("");
  const contour = cleaned.replace(
    /(L1122\.9,124\.5) L1168\.8,115\.1 .*? (L1121\.4,122\.4)/,
    "$1 C1146,119 1169,115 1193,107 C1170,113 1147,117 1128,121 $2",
  );
  return `${prefix}${contour}${suffix}`;
});
fs.writeFileSync(foalMasterPath, foalMasterSvg);
foalManifest.master.sha256 = digest(foalMasterSvg);
foalManifest.master.ear_pigment_paths = [foalFarEar, foalNearEar];
for (const trait of ["bay", "black", "brown", "chestnut"]) {
  const layerId = `qh_foal_master_01__base_${trait}`;
  const file = path.join(foalDirectory, `${layerId}.svg`);
  let svg = fs.readFileSync(file, "utf8");
  svg = svg.replace(new RegExp(`<path id="${layerId}__poll-undercoat"[^>]+/>\\n?`), "");
  svg = svg.replace(new RegExp(`<path id="${layerId}__poll-mask-[^"]+"[^>]+/>\\n?`, "g"), "");
  svg = svg.replace(new RegExp(`<clipPath id="${layerId}__poll-clip">[\\s\\S]*?<\\/clipPath>\\n?`), "");
  svg = svg.replace(new RegExp(`<path id="${layerId}__poll-pigment"[^>]+/>\\n?`), "");
  svg = svg.replace(new RegExp(`<path id="${layerId}__poll-underlay"[^>]+/>\\n?`), "");
  svg = svg.replace(new RegExp(`<path id="${layerId}__poll-coat-repair"[^>]+/>\\n?`), "");
  // This same malformed forelock path was embedded as a black exclusion in
  // every base-coat mask. Removing the exclusion lets the normal coat layer
  // pigment the poll continuously without a separate overlay patch.
  svg = svg.replaceAll(foalMalformedForelock, "");
  for (const hole of foalResidualForelockHoles) svg = svg.replaceAll(hole, "");
  svg = svg.replace(
    new RegExp(`<path id="${layerId}__fill" fill="([^"]+)" fill-rule="evenodd" d="[^"]+"\\/>`),
    `<rect id="${layerId}__fill" width="1496" height="1051" fill="$1"/>`,
  );
  const baseFill = svg.match(new RegExp(`id="${layerId}__fill"[^>]+fill="([^"]+)"`))?.[1];
  if (!baseFill) throw new Error(`Missing base fill for ${layerId}`);
  svg = svg.replace("</svg>", `<path id="${layerId}__poll-coat-repair" fill="${baseFill}" d="${foalPollCoatRepair}"/>\n</svg>`);
  fs.writeFileSync(file, svg);
  const record = foalManifest.layers.find(layer => layer.layer_id === layerId);
  if (!record) throw new Error(`Missing manifest record ${layerId}`);
  record.sha256 = digest(svg);
  record.svg_element_ids ??= [];
  record.svg_element_ids = record.svg_element_ids.filter(id => id !== `${layerId}__poll-undercoat`);
  record.svg_element_ids = record.svg_element_ids.filter(id => !id.startsWith(`${layerId}__poll-mask-`));
  record.svg_element_ids = record.svg_element_ids.filter(id => id !== `${layerId}__poll-clip` && id !== `${layerId}__poll-pigment`);
  record.svg_element_ids = record.svg_element_ids.filter(id => id !== `${layerId}__poll-underlay`);
  if (!record.svg_element_ids.includes(`${layerId}__poll-coat-repair`)) record.svg_element_ids.push(`${layerId}__poll-coat-repair`);
}

foalManifest.layers = foalManifest.layers.filter(layer => layer.category !== "poll_cleanup");
foalManifest.layers = foalManifest.layers.filter(layer => layer.category !== "poll_coat");
for (const trait of ["bay", "black", "brown", "chestnut"]) {
  const obsolete = path.join(foalDirectory, `qh_foal_master_01__poll_coat_${trait}.svg`);
  if (fs.existsSync(obsolete)) fs.unlinkSync(obsolete);
}

for (const trait of ["black", "chestnut"]) {
  const layerId = `qh_foal_master_01__mane_${trait}`;
  const file = path.join(foalDirectory, `${layerId}.svg`);
  let svg = fs.readFileSync(file, "utf8");
  svg = svg.replace(new RegExp(`<path id="${layerId}__poll_bridge"[^>]+/>\\n?`), "");
  svg = svg.replace(foalMalformedForelock, "");
  svg = svg.replace(new RegExp(`<path id="${layerId}__forelock-[1-4]"[^>]+/>\\n?`, "g"), "");
  svg = svg.replace(new RegExp(`<path id="${layerId}__forelock-redraw"[^>]+/>\\n?`), "");
  svg = svg.replace(new RegExp(`<path id="${layerId}__poll-mane-repair"[^>]+/>\\n?`), "");
  svg = svg.replace(new RegExp(`<path id="${layerId}__forelock-repair"[^>]+/>\\n?`), "");
  const maneFill = svg.match(/fill="(#[0-9A-Fa-f]{6})"/)?.[1];
  if (!maneFill) throw new Error(`Missing mane fill for ${layerId}`);
  const earMask = `${layerId}__near-ear-occlusion`;
  const rootFade = `${layerId}__forelock-root-fade`;
  const highlight = `${layerId}__forelock-highlight`;
  svg = svg.replace(new RegExp(`<mask id="${earMask}"[^>]*>.*?</mask>\\n?`), "");
  svg = svg.replace(new RegExp(`<linearGradient id="${rootFade}"[^>]*>.*?</linearGradient>\\n?`), "");
  svg = svg.replace(new RegExp(`<path id="${highlight}"[^>]+/>\\n?`), "");
  const hairColor = trait === "black" ? "#231e1d" : maneFill;
  const highlightColor = trait === "black" ? "#49403b" : "#c17a50";
  const foreground = [
    '<svg xmlns="http://www.w3.org/2000/svg" width="1496" height="1051" viewBox="0 0 1496 1051">',
    "<defs>",
    `<mask id="${earMask}" maskUnits="userSpaceOnUse" x="0" y="0" width="1496" height="1051"><rect width="1496" height="1051" fill="white"/><path fill="black" d="${foalNearEar}"/></mask>`,
    `<linearGradient id="${rootFade}" gradientUnits="userSpaceOnUse" x1="1109" x2="1162"><stop stop-color="${hairColor}" stop-opacity="0"/><stop offset="1" stop-color="${hairColor}"/></linearGradient>`,
    "</defs>",
    `<path id="${layerId}__forelock-repair" mask="url(#${earMask})" fill="url(#${rootFade})" d="${foalForelockRepair}"/>`,
    `<path id="${highlight}" mask="url(#${earMask})" fill="${highlightColor}" opacity=".60" d="${foalForelockHighlight}"/>`,
    "</svg>",
    "",
  ].join("\n");
  const foregroundName = `${layerId}__forelock.svg`;
  fs.writeFileSync(path.join(foalDirectory, foregroundName), foreground);
  fs.writeFileSync(file, svg);
  const record = foalManifest.layers.find(layer => layer.layer_id === layerId);
  if (!record) throw new Error(`Missing manifest record ${layerId}`);
  record.sha256 = digest(svg);
  record.svg_element_ids = (record.svg_element_ids ?? []).filter(id => id !== `${layerId}__poll_bridge`);
  record.svg_element_ids = record.svg_element_ids.filter(id => !id.startsWith(`${layerId}__forelock-`));
  record.svg_element_ids = record.svg_element_ids.filter(id => id !== earMask);
  record.foreground = {file: `layers/${foregroundName}`, sha256: digest(foreground)};
}
fs.writeFileSync(foalManifestPath, `${JSON.stringify(foalManifest, null, 1)}\n`);
