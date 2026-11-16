import{readdirSync,readFileSync}from"node:fs";
import{fileURLToPath}from"node:url";
import{describe,expect,it}from"vitest";
import sharp from"sharp";

const root=new URL("../public/game-art/objects/",import.meta.url),manifest=JSON.parse(readFileSync(new URL("MANIFEST.json",root),"utf8")),ui=readFileSync(new URL("../app/legacy-finds.tsx",import.meta.url),"utf8"),sql=readFileSync(new URL("../supabase/migrations/202611160007_legacy_find_reward_art.sql",import.meta.url),"utf8");
describe("Legacy Finds supplied artwork",()=>{
 it("preserves all 22 supplied objects and maps all 11 live rewards",()=>{expect(readdirSync(root).filter(x=>x.endsWith(".png"))).toHaveLength(22);expect(Object.keys(manifest.legacy_find_assets)).toHaveLength(11)});
 it("ships transparent PNG artwork",async()=>{for(const file of readdirSync(root).filter(x=>x.endsWith(".png"))){const meta=await sharp(fileURLToPath(new URL(file,root))).metadata();expect(meta.format).toBe("png");expect(meta.hasAlpha).toBe(true)}});
 it("returns the selected image without changing reward balancing",()=>{expect(sql).toContain("'image_url',reward.image_url");expect(sql).not.toContain("update public.legacy_find_config");expect(sql).not.toContain("weight=")});
 it("renders artwork with an emoji fallback",()=>{expect(ui).toContain('find.image_url?<img');expect(ui).toContain(':find.icon')});
});
