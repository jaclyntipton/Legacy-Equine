import {readFileSync} from "node:fs";
import {describe,expect,it} from "vitest";

const sql=readFileSync("supabase/migrations/202611170003_rare_multi_pattern_paints.sql","utf8");

describe("Foundation Paint pattern rarity",()=>{
 it("keeps Sabino and Splash possible but rare",()=>{
  expect(sql).toContain("locus in ('Sabino1', 'Splash1')");
  expect(sql).toContain("allele_frequency = 0.01");
  expect(sql).not.toContain("Tobiano', 'Frame");
 });
});
