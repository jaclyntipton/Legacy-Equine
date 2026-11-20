import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const root = "public/horse-visuals/coat-layers";
const pathFor = (svg: string, idSuffix: string) => svg.match(new RegExp(`<path id="[^"]+__${idSuffix}"[^>]* d="([^"]+)"`))?.[1];

describe("Registered facial marking refinements", () => {
  it.each(readdirSync(root))("keeps %s muzzle transitions aligned with facial markings", master => {
    const directory = join(root, master);
    const {layers} = JSON.parse(readFileSync(join(directory, "manifest.json"), "utf8"));
    const faces = layers.filter((layer: {category: string}) => layer.category === "face_marking");
    const skin = layers.filter((layer: {trait_key: string}) => layer.trait_key.startsWith("pink_under_"));
    const quarterHorse = master.startsWith("qh_");
    expect(faces).toHaveLength(quarterHorse ? 13 : 12);
    expect(skin).toHaveLength(quarterHorse ? 6 : 5);
    for (const layer of skin) {
      const paired = faces.find((face: {trait_key: string}) => face.trait_key === layer.trait_key.slice("pink_under_".length));
      expect(paired).toBeDefined();
      const pink = readFileSync(join(directory, layer.file), "utf8");
      const face = readFileSync(join(directory, paired.file), "utf8");
      expect(pathFor(pink, "pink")).toBeTruthy();
      if (["pink_under_bald_face", "pink_under_badger_face"].includes(layer.trait_key)) {
        expect(pathFor(pink, "pink")).toBe(pathFor(face, "muzzle-erase"));
        expect(pink).toContain('stdDeviation="1.8"');
        expect(pink).toContain('mask="url(');
      } else {
        expect(pathFor(pink, "pink")).toBe(pathFor(face, "marking"));
        expect(pink).toContain('stop-opacity="0"');
        expect(pink).toContain('clip-path="url(');
      }
      expect(layer.sha256).toBe(createHash("sha256").update(pink).digest("hex"));
    }
  });
});
