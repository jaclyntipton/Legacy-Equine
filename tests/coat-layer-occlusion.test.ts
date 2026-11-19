import fs from "node:fs";
import path from "node:path";
import sharp from "sharp";
import {describe, expect, it} from "vitest";

const masters = ["qh_mare_master_01", "qh_stallion_master_01"];
const traits = ["tobiano", "frame_overo", "sabino", "sabino_roaning", "splash_white", "medicine_hat", "tovero", "lp_blanket", "lp_snowcap", "lp_spotted_blanket", "lp_leopard", "lp_fewspot", "lp_snowflake", "lp_varnish_roan", "lp_frost"];

describe("registered coat-layer occlusion", () => {
  it("covers the Thoroughbred tail head without changing the master anatomy", () => {
    for (const sex of ["mare", "stallion"]) {
      const master = `thoroughbred_${sex}_master_01`;
      const manifest = JSON.parse(fs.readFileSync(`public/horse-visuals/coat-layers/${master}/manifest.json`, "utf8"));

      for (const pigment of ["black", "chestnut"]) {
        const layerId = `${master}__tail_${pigment}`;
        const svg = fs.readFileSync(`public/horse-visuals/coat-layers/${master}/layers/${layerId}.svg`, "utf8");
        const record = manifest.layers.find((layer: { layer_id: string }) => layer.layer_id === layerId);

        expect(svg).toContain(`${layerId}__dock`);
        expect(record.svg_element_ids).toContain(`${layerId}__dock`);
      }
    }
  });

  it("connects the Thoroughbred mane pigment through the poll and forelock", () => {
    for (const sex of ["mare", "stallion"]) {
      const master = `thoroughbred_${sex}_master_01`;
      const manifest = JSON.parse(fs.readFileSync(`public/horse-visuals/coat-layers/${master}/manifest.json`, "utf8"));

      for (const pigment of ["black", "chestnut"]) {
        const layerId = `${master}__mane_${pigment}`;
        const svg = fs.readFileSync(`public/horse-visuals/coat-layers/${master}/layers/${layerId}.svg`, "utf8");
        const record = manifest.layers.find((layer: { layer_id: string }) => layer.layer_id === layerId);

        expect(svg).toContain(`${layerId}__poll_bridge`);
        expect(record.svg_element_ids).toContain(`${layerId}__poll_bridge`);
      }
    }
  });

  it("fills the shared foal poll with matching base-coat pigment beneath the mane", async () => {
    const master = "qh_foal_master_01";
    const manifest = JSON.parse(fs.readFileSync(`public/horse-visuals/coat-layers/${master}/manifest.json`, "utf8"));

    for (const base of ["bay", "black", "brown", "chestnut"]) {
      const layerId = `${master}__base_${base}`;
      const svg = fs.readFileSync(`public/horse-visuals/coat-layers/${master}/layers/${layerId}.svg`, "utf8");
      const record = manifest.layers.find((layer: { layer_id: string }) => layer.layer_id === layerId);
      expect(svg).toContain(`${layerId}__poll-undercoat`);
      expect(record.svg_element_ids).toContain(`${layerId}__poll-undercoat`);
    }

    for (const pigment of ["black", "chestnut"]) {
      const layerId = `${master}__mane_${pigment}`;
      const svg = fs.readFileSync(`public/horse-visuals/coat-layers/${master}/layers/${layerId}.svg`, "utf8");
      const record = manifest.layers.find((layer: { layer_id: string }) => layer.layer_id === layerId);

      expect(svg).not.toContain(`${layerId}__poll_bridge`);
      expect(record.svg_element_ids).not.toContain(`${layerId}__poll_bridge`);
      expect(record.compositing_group).toBe("top");
    }

    const root = `public/horse-visuals/coat-layers/${master}/layers`;
    const base = await sharp(`${root}/${master}__base_black.svg`).resize(1496, 1051, {fit: "fill"}).png().toBuffer();
    const mane = await sharp(`${root}/${master}__mane_black.svg`).resize(1496, 1051, {fit: "fill"}).png().toBuffer();
    const {data, info} = await sharp({create: {width: 1496, height: 1051, channels: 4, background: {r: 0, g: 0, b: 0, alpha: 0}}})
      .composite([{input: base}, {input: mane}])
      .raw()
      .toBuffer({resolveWithObject: true});
    for (const [x, y] of [[1180, 105], [1205, 115], [1230, 120]]) {
      expect(data[(y * info.width + x) * info.channels + 3]).toBeGreaterThan(240);
    }
  });

  it.each(masters)("prevents broad %s body patterns from bleeding into the foreground LH gaskin", master => {
    for (const trait of traits) {
      const layerId = `${master}__${trait}`;
      const svg = fs.readFileSync(path.join("public/horse-visuals/coat-layers", master, "layers", `${layerId}.svg`), "utf8");
      expect(svg).toContain(`<mask id="${layerId}__rear-overlap-guard"`);
      if (trait === "lp_leopard") {
        expect(svg).not.toContain(`mask="url(#${layerId}__rear-overlap-guard)"`);
        expect(svg).not.toContain("lh-inner-clip");
      } else {
        expect(svg).toContain(`mask="url(#${layerId}__rear-overlap-guard)"`);
      }
      expect(svg).not.toMatch(new RegExp(`<mask id="${layerId}__mask-coat"[\\s\\S]*<path id="${layerId}__rear-overlap-guard"[\\s\\S]*</mask>`));
    }
  });

  it("uses continuous leopard coverage and procedural sabino hair roaning", () => {
    for (const master of masters) {
      const leopard = fs.readFileSync(`public/horse-visuals/coat-layers/${master}/layers/${master}__lp_leopard.svg`, "utf8");
      const sabino = fs.readFileSync(`public/horse-visuals/coat-layers/${master}/layers/${master}__sabino_roaning.svg`, "utf8");
      expect(leopard).not.toContain("lh-inner-clip");
      expect(sabino).toContain("sabino_roaning__hair-noise");
      expect(sabino).toContain("sabino_roaning__visible-hairs");
      expect(sabino).toMatch(/fill="url\(#qh_(?:mare|stallion)_master_01__sabino_roaning__visible-hairs\)"/);
      expect(sabino).toMatch(/<feTurbulence type="fractalNoise" baseFrequency="0\.08[25] 0\.1(?:55|6)"/);
      expect(sabino).not.toContain("M305 485 l9 -5");
    }
  });

  it("keeps stallion varnish patches organic and frost distinct from snowflake", () => {
    const root = "public/horse-visuals/coat-layers/qh_stallion_master_01/layers";
    const varnish = fs.readFileSync(path.join(root, "qh_stallion_master_01__lp_varnish_roan.svg"), "utf8");
    const frost = fs.readFileSync(path.join(root, "qh_stallion_master_01__lp_frost.svg"), "utf8");
    expect(varnish).not.toContain("<circle");
    expect(varnish).not.toContain("M904 306");
    expect(varnish).not.toContain("M229 306");
    expect(varnish).not.toContain("M365 477");
    expect(varnish).not.toContain("M922 510");
    expect(frost).toContain('id="qh_stallion_master_01__lp_frost__flecks"');
    expect(frost).toContain('id="qh_stallion_master_01__lp_frost__visible-frost"');
    expect(frost).toContain('opacity="0.34"');
  });

  it("renders foal mane and tail pigment after coat-removing modifiers", () => {
    const manifest = JSON.parse(fs.readFileSync("public/horse-visuals/coat-layers/qh_foal_master_01/manifest.json", "utf8"));
    const hair = manifest.layers.filter((layer: {category: string}) => layer.category === "mane" || layer.category === "tail");
    expect(hair).toHaveLength(4);
    expect(hair.every((layer: {stacking_order: number}) => layer.stacking_order === 615)).toBe(true);
    expect(Math.max(...manifest.layers.filter((layer: {category: string}) => ["gray", "roan", "pinto", "leg_marking", "face_marking"].includes(layer.category)).map((layer: {stacking_order: number}) => layer.stacking_order))).toBeLessThan(615);
  });
});
