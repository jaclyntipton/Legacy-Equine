import{describe,expect,it}from"vitest";
import fs from"node:fs";
import path from"node:path";
const root=path.resolve(__dirname,"..");
const page=fs.readFileSync(path.join(root,"app/page.tsx"),"utf8");
const inventory=fs.readFileSync(path.join(root,"app/stable-inventory.tsx"),"utf8");
const horse=fs.readFileSync(path.join(root,"app/horse-profile.tsx"),"utf8");
const storeCleanup=fs.readFileSync(path.join(root,"supabase/migrations/202609170006_store_tack_feed_ux_cleanup.sql"),"utf8");
describe("player information architecture",()=>{
 it("separates profile identity from stable operations",()=>{expect(page).toMatch(/type MainView=.*"stable".*"profile"/);expect(page).toContain("Profile</button>");expect(page).toContain("Artwork Album</button>");expect(page).toContain("My Horses</button>");expect(page).toContain("Tack Room</button>");expect(page).toContain("Feed Room</button>")});
 it("routes current Store products to their owned inventory rooms",()=>{expect(page).toContain('label:"Feed Room"');expect(page).toContain('label:"Tack Room"');expect(page).not.toContain('label:"Supply Room"');expect(page).not.toMatch(/storeDepartment!=="horses"&&<>[\s\S]*<StableInventory/)});
 it("limits the Store to three compact, filterable departments",()=>{expect(page).toContain('type StoreDepartment="horses"|"feed"|"tack"');expect(page).not.toContain('>Stable Supplies</button>');expect(page).toContain('aria-label={storeDepartment==="tack"?"Tack category":"Feed and hay type"}');expect(page).toContain('placeholder={`Search ${storeDepartment==="tack"?"Tack":"Feed & Hay"}`}')});
 it("normalizes tack tiers without deleting owned inventory",()=>{for(const tier of ["Entry","Quality","Elite","Legendary"])expect(storeCleanup).toContain(`'${tier}'`);expect(storeCleanup).toContain("update public.store_products set active=false where department='stable_supplies'");expect(storeCleanup).not.toMatch(/delete from public\.(player_store_items|currency_ledger)/);expect(storeCleanup).toContain("where id=i.product_id and department='tack'")});
 it("keeps one inventory source and supports returning tack",()=>{expect(inventory).toContain('from("player_store_items")');expect(inventory).toContain('rpc("unequip_tack"');expect(inventory).toContain('"feed"|"tack"|"supplies"')});
 it("offers all three horse artwork sources",()=>{expect(horse).toContain("Legacy Equine Visual");expect(horse).toContain("Artwork Album");expect(horse).toContain("External URL")});
});
