import fs from "node:fs";
import path from "node:path";
import {describe, expect, it} from "vitest";

const masters = ["qh_mare_master_01", "qh_stallion_master_01"];
const traits = ["tobiano", "frame_overo", "sabino", "sabino_roaning", "splash_white", "medicine_hat", "tovero", "lp_blanket", "lp_snowcap", "lp_spotted_blanket", "lp_leopard", "lp_fewspot", "lp_snowflake", "lp_varnish_roan"];

describe("registered coat-layer occlusion", () => {
  it.each(masters)("prevents broad %s body patterns from bleeding into the foreground LH gaskin", master => {
    for (const trait of traits) {
      const layerId = `${master}__${trait}`;
      const svg = fs.readFileSync(path.join("public/horse-visuals/coat-layers", master, "layers", `${layerId}.svg`), "utf8");
      expect(svg).toContain(`<mask id="${layerId}__rear-overlap-guard"`);
      if (master === "qh_mare_master_01" && trait === "lp_leopard") {
        expect(svg).not.toContain(`mask="url(#${layerId}__rear-overlap-guard)"`);
        expect(svg).not.toContain("lh-inner-clip");
      } else {
        expect(svg).toContain(`mask="url(#${layerId}__rear-overlap-guard)"`);
      }
      expect(svg).not.toMatch(new RegExp(`<mask id="${layerId}__mask-coat"[\\s\\S]*<path id="${layerId}__rear-overlap-guard"[\\s\\S]*</mask>`));
    }
  });

  it("uses continuous leopard coverage and procedural sabino hair roaning", () => {
    const leopard = fs.readFileSync("public/horse-visuals/coat-layers/qh_mare_master_01/layers/qh_mare_master_01__lp_leopard.svg", "utf8");
    const sabino = fs.readFileSync("public/horse-visuals/coat-layers/qh_mare_master_01/layers/qh_mare_master_01__sabino_roaning.svg", "utf8");
    expect(leopard).not.toContain("lh-inner-clip");
    expect(sabino).toContain("sabino_roaning__hair-noise");
    expect(sabino).toContain('<feTurbulence type="fractalNoise" baseFrequency="0.085 0.16"');
    expect(sabino).not.toContain("M305 485 l9 -5");
  });

  it("renders foal mane and tail pigment after coat-removing modifiers", () => {
    const manifest = JSON.parse(fs.readFileSync("public/horse-visuals/coat-layers/qh_foal_master_01/manifest.json", "utf8"));
    const hair = manifest.layers.filter((layer: {category: string}) => layer.category === "mane" || layer.category === "tail");
    expect(hair).toHaveLength(4);
    expect(hair.every((layer: {stacking_order: number}) => layer.stacking_order === 615)).toBe(true);
    expect(Math.max(...manifest.layers.filter((layer: {category: string}) => ["gray", "roan", "pinto", "leg_marking", "face_marking"].includes(layer.category)).map((layer: {stacking_order: number}) => layer.stacking_order))).toBeLessThan(615);
  });
});
