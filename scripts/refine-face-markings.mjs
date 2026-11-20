import { createHash } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const root = "public/horse-visuals/coat-layers";
const broaderMarkings = new Set(["bald_face", "blaze", "blaze_snip", "broken_stripe", "irregular_blaze", "star_stripe", "stripe"]);
const coordinate = value => Number(value.toFixed(2));
const pair = ([x, y]) => `${coordinate(x)},${coordinate(y)}`;
const softenPinkTint = svg => svg.replace(/fill-opacity="(?:0?\.85)"/g, 'fill-opacity=".42"')
  .replace(' style="mix-blend-mode:multiply"', "");

function baldFaceMuzzle(clip) {
  const points = [...clip.matchAll(/(-?[\d.]+),(-?[\d.]+)/g)].map(match => [Number(match[1]), Number(match[2])]);
  const xs = points.map(p => p[0]), ys = points.map(p => p[1]);
  const left = Math.min(...xs), top = Math.min(...ys);
  const width = Math.max(...xs) - left, height = Math.max(...ys) - top;
  const point = (x, y) => pair([left + x * width, top + y * height]);
  return `M${point(.27, 1.2)} C${point(.24, .85)} ${point(.25, .58)} ${point(.31, .42)} C${point(.4, .19)} ${point(.57, .16)} ${point(.73, .19)} C${point(.89, .22)} ${point(1.02, .17)} ${point(1.19, .04)} L${point(1.23, 1.2)}Z`;
}

function softenDenseContours(path) {
  return path.replace(/M[^M]+/g, contour => {
    const points = [...contour.matchAll(/([MC])([^MCZ]+)|Z/g)].flatMap(match => {
      if (!match[1]) return [];
      const values = match[2].trim().split(/[ ,]+/).map(Number);
      return [values.slice(-2)];
    });
    if (points.length < 20 || !/^M[-\d., C]+Z\s*$/.test(contour) || points.some(p => p.some(v => !Number.isFinite(v)))) return contour;
    if (Math.hypot(points[0][0]-points.at(-1)[0], points[0][1]-points.at(-1)[1]) < .5) points.pop();
    const n = points.length;
    const at = (list, i) => list[(i + n) % n];
    // Suppress the short sawteeth while preserving larger changes in the silhouette.
    const smoothed = points.map((_, i) => [0, 1].map(axis =>
      [1, 2, 3, 2, 1].reduce((sum, weight, j) => sum + weight * at(points, i + j - 2)[axis], 0) / 9,
    ));
    let result = `M${pair(smoothed[0])}`;
    for (let i = 0; i < n; i++) {
      const a = at(smoothed, i - 1), b = smoothed[i], c = at(smoothed, i + 1), d = at(smoothed, i + 2);
      const control1 = b.map((v, axis) => v + (c[axis] - a[axis]) / 6);
      const control2 = c.map((v, axis) => v - (d[axis] - b[axis]) / 6);
      result += ` C${pair(control1)} ${pair(control2)} ${pair(c)}`;
    }
    return result + "Z";
  });
}

for (const master of readdirSync(root)) {
  const directory = join(root, master);
  const manifestFile = join(directory, "manifest.json");
  const manifest = JSON.parse(readFileSync(manifestFile, "utf8"));
  if (manifest.face_marking_refinement === 6) continue;
  if (manifest.face_marking_refinement >= 3) {
    for (const layer of manifest.layers.filter(layer => layer.trait_key.startsWith("pink_under_"))) {
      const file = join(directory, layer.file);
      const svg = softenPinkTint(readFileSync(file, "utf8").replace(/#(?:EDB8AC|FFD3CC)/g, "#FFE3DD"));
      writeFileSync(file, svg);
      layer.blend_mode = "normal";
      layer.sha256 = createHash("sha256").update(svg).digest("hex");
    }
    manifest.face_marking_refinement = 6;
    writeFileSync(manifestFile, JSON.stringify(manifest, null, 1) + "\n");
    continue;
  }
  const paths = new Map();
  for (const layer of manifest.layers.filter(layer => layer.category === "face_marking" && broaderMarkings.has(layer.trait_key))) {
    const file = join(directory, layer.file);
    const svg = readFileSync(file, "utf8");
    const marking = svg.match(/(<path id="[^"]+__marking"[^>]* d=")([^"]+)(")/);
    if (!marking) throw new Error(`No registered face contour: ${layer.layer_id}`);
    const adjusted = manifest.face_marking_refinement ? marking[2] : softenDenseContours(marking[2]);
    paths.set(layer.trait_key, adjusted);
    const next = svg.replace(marking[0], marking[1] + adjusted + marking[3]);
    writeFileSync(file, next);
    layer.sha256 = createHash("sha256").update(next).digest("hex");
  }
  for (const layer of manifest.layers.filter(layer => layer.category === "skin" && layer.trait_key.startsWith("pink_under_"))) {
    const file = join(directory, layer.file);
    const svg = readFileSync(file, "utf8");
    const clip = svg.match(/<clipPath[^>]*><path[^>]* d="([^"]+)"/)?.[1];
    const pink = svg.match(/(<path id="[^"]+__pink"[^>]* d=")([^"]+)(")/);
    if (!clip || !pink) throw new Error(`No registered muzzle geometry: ${layer.layer_id}`);
    if (layer.trait_key === "pink_under_bald_face") {
      const face = manifest.layers.find(record => record.category === "face_marking" && record.trait_key === "bald_face");
      const faceFile = join(directory, face.file);
      const faceSvg = readFileSync(faceFile, "utf8");
      const anatomy = faceSvg.match(/<mask id="[^"]+__mask-coat"[^>]*>.*?<\/mask>/s)?.[0];
      if (!anatomy) throw new Error(`Missing face anatomy mask: ${face.layer_id}`);
      const muzzle = baldFaceMuzzle(clip);
      const edge = layer.layer_id + "__muzzle-edge";
      const eraseId = face.layer_id + "__muzzle-erase";
      const maskId = anatomy.match(/id="([^"]+)"/)[1];
      const erase = faceSvg.replace(/(<path id="[^"]+__marking"[^>]*\/>)/, `$1\n<path id="${eraseId}" fill="#fff" d="${muzzle}"/>`);
      writeFileSync(faceFile, erase);
      face.sha256 = createHash("sha256").update(erase).digest("hex");
      face.svg_element_ids.push(eraseId);
      const next = softenPinkTint([
        '<svg xmlns="http://www.w3.org/2000/svg" width="1496" height="1051" viewBox="0 0 1496 1051">',
        '<defs>', anatomy,
        `<filter id="${edge}" x="-10%" y="-15%" width="120%" height="130%"><feGaussianBlur stdDeviation="1.8"/></filter>`,
        '</defs>',
        `<g id="${layer.layer_id}" mask="url(#${maskId})"><path id="${layer.layer_id}__pink" fill="#FFE3DD" fill-opacity=".85" filter="url(#${edge})" d="${muzzle}"/></g>`,
        '</svg>', '',
      ].join("\n"));
      writeFileSync(file, next);
      layer.sha256 = createHash("sha256").update(next).digest("hex");
      layer.blend_mode = "normal";
      layer.svg_element_ids = [maskId, edge, layer.layer_id, layer.layer_id + "__pink"];
      continue;
    }
    const ys = [...clip.matchAll(/(-?[\d.]+),(-?[\d.]+)/g)].map(match => Number(match[2]));
    const top = Math.min(...ys), depth = Math.max(...ys) - top;
    if (!Number.isFinite(top) || depth <= 0) throw new Error(`Invalid muzzle extent: ${layer.layer_id}`);
    const id = layer.layer_id + "__muzzle-transition";
    const fade = Math.min(6, depth * .09);
    const gradient = `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="0" x2="0" y1="${top}" y2="${coordinate(top + fade)}"><stop stop-color="#FFE3DD" stop-opacity="0"/><stop offset="1" stop-color="#FFE3DD"/></linearGradient>`;
    const marking = paths.get(layer.trait_key.slice("pink_under_".length)) ?? pink[2];
    const next = softenPinkTint(svg.replace(pink[0], pink[1].replace('fill="#EDB8AC"', `fill="url(#${id})"`) + marking + pink[3])
      .replace(new RegExp(`<linearGradient id="${id}"[^>]*>.*?</linearGradient>\\n?`), "")
      .replace("</defs>", `${gradient}\n</defs>`));
    writeFileSync(file, next);
    layer.sha256 = createHash("sha256").update(next).digest("hex");
    layer.blend_mode = "normal";
    if (!layer.svg_element_ids.includes(id)) layer.svg_element_ids.push(id);
  }
  manifest.face_marking_refinement = 6;
  writeFileSync(manifestFile, JSON.stringify(manifest, null, 1) + "\n");
}
