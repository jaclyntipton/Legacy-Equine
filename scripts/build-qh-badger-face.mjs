import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

for (const stage of ["mare", "stallion", "foal"]) {
  const master = `qh_${stage}_master_01`;
  const root = join("public/horse-visuals/coat-layers", master);
  const manifestFile = join(root, "manifest.json");
  const manifest = JSON.parse(readFileSync(manifestFile, "utf8"));
  const face = manifest.layers.find(layer => layer.trait_key === "bald_face");
  const skin = manifest.layers.find(layer => layer.trait_key === "pink_under_bald_face");
  for (const source of [face, skin]) {
    const layerId = source.layer_id.replace("bald_face", "badger_face");
    const file = `layers/${layerId}.svg`;
    let svg = readFileSync(join(root, source.file), "utf8").replaceAll("bald_face", "badger_face");
    const ids = source.svg_element_ids.map(id => id.replaceAll("bald_face", "badger_face"));
    if (source === face) {
      const bounds = svg.match(/__marking"[^>]* d="([^"]+)"/)[1];
      const points = [...bounds.matchAll(/([\d.]+),([\d.]+)/g)].map(match => [Number(match[1]), Number(match[2])]);
      const xs = points.map(p => p[0]), ys = points.map(p => p[1]);
      const left = Math.min(...xs), top = Math.min(...ys), width = Math.max(...xs) - left, height = Math.max(...ys) - top;
      const p = (x, y) => `${(left + x * width).toFixed(1)},${(top + y * height).toFixed(1)}`;
      // Let the pigmented bridge reach the profile edge. The far-side white
      // cannot show on a side-view horse, so only the near cheek ribbon remains.
      const reverseBlaze = `M${p(.49, .02)} C${p(.45, .10)} ${p(.42, .21)} ${p(.46, .32)} C${p(.51, .43)} ${p(.59, .52)} ${p(.65, .58)} C${p(.71, .64)} ${p(.76, .65)} ${p(.80, .61)} C${p(.86, .58)} ${p(.97, .56)} ${p(1.15, .54)} L${p(1.15, -.10)} L${p(.53, -.10)}Z`;
      const island = `${layerId}__pigmented-center`;
      ids.push(island);
      svg = svg.replace("</defs>", `<mask id="${island}" maskUnits="userSpaceOnUse" width="1496" height="1051"><rect width="1496" height="1051" fill="white"/><path fill="black" d="${reverseBlaze}"/></mask>\n</defs>`)
        .replace(`<path id="${layerId}__marking"`, `<path id="${layerId}__marking" mask="url(#${island})"`);
    }
    const record = {...source, layer_id:layerId, trait_key:source.trait_key.replace("bald_face", "badger_face"),
      genetic_trigger:"badger_face_01 (Legacy Equine appearance code)", status:"generated_pending_review", file,
      sha256:createHash("sha256").update(svg).digest("hex"), svg_element_ids:ids,
      provenance:"Owner reference-led Quarter Horse review candidate",
    };
    for (const key of ["preview_png", "preview_sha256", "composite_proof", "composite_proof_stack", "validation"]) delete record[key];
    manifest.layers = manifest.layers.filter(layer => layer.layer_id !== layerId);
    manifest.layers.push(record);
    writeFileSync(join(root,file), svg);
  }
  writeFileSync(manifestFile, JSON.stringify(manifest, null, 1) + "\n");
}
