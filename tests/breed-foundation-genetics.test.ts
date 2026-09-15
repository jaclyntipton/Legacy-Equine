import{describe,expect,it}from"vitest";
import fs from"node:fs";
const sql=fs.readFileSync("supabase/migrations/202609150057_breed_foundation_genetic_populations.sql","utf8");
describe("breed-specific Foundation genetics",()=>{
 it("adds Paint as a breed rather than a color",()=>{expect(sql).toContain("'American Paint Horse',9");expect(sql).toContain("American Paint Horse Association")});
 it("uses database population weights for Foundation genotypes",()=>{expect(sql).toContain("breed_foundation_genetic_population");expect(sql).toContain("population_gene_pair(b,'Extension')");expect(sql).not.toContain("enforce_foundation_breed_genetics(breed_name")});
 it("makes loud Quarter Horse and Thoroughbred patterns exceptional",()=>{expect(sql).toContain("('Quarter Horse','Frame',.00010,'exceptional')");expect(sql).toContain("('Thoroughbred','Splash1',.00005,'exceptional')")});
 it("makes Paint the primary loud-pattern population",()=>{expect(sql).toContain("('American Paint Horse','Tobiano',.32,'common')");expect(sql).toContain("('American Paint Horse','Frame',.10,'common')")});
 it("rejects lethal Foundation results before horse creation",()=>{const generator=sql.slice(sql.indexOf("create or replace function public.generate_store_horse"));expect(generator).toContain("exit when not is_lethal_genotype(g)");expect(generator.indexOf("exit when not is_lethal_genotype(g)")).toBeLessThan(generator.indexOf("insert into horses"))});
 it("keeps breeding parental and independent of population tables",()=>{const breeding=fs.readFileSync("supabase/migrations/202609150051_confirmed_seven_stat_layers.sql","utf8");expect(breeding).toContain("child_genetics:=inherit_genetics(sire.genetics,dam.genetics)");expect(breeding).not.toContain("breed_foundation_genetic_population")});
});
