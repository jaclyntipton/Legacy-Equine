import{describe,expect,it}from"vitest";
import fs from"node:fs";
import path from"node:path";
const root=path.resolve(__dirname,"..");
const page=fs.readFileSync(path.join(root,"app/page.tsx"),"utf8");
const inventory=fs.readFileSync(path.join(root,"app/stable-inventory.tsx"),"utf8");
const horse=fs.readFileSync(path.join(root,"app/horse-profile.tsx"),"utf8");
describe("player information architecture",()=>{
 it("separates profile identity from stable operations",()=>{expect(page).toContain('| "profile"');expect(page).toContain("Profile</button>");expect(page).toContain("Artwork Album</button>");expect(page).toContain("My Horses</button>");expect(page).toContain("Tack Room</button>");expect(page).toContain("Feed Room</button>")});
 it("routes each product department to an owned inventory room",()=>{expect(page).toContain('label:"Feed Room"');expect(page).toContain('label:"Tack Room"');expect(page).toContain('label:"Supply Room"');expect(page).not.toMatch(/storeDepartment!=="horses"&&<>[\s\S]*<StableInventory/)});
 it("keeps one inventory source and supports returning tack",()=>{expect(inventory).toContain('from("player_store_items")');expect(inventory).toContain('rpc("unequip_tack"');expect(inventory).toContain('"feed"|"tack"|"supplies"')});
 it("offers all three horse artwork sources",()=>{expect(horse).toContain("Legacy Equine Visual");expect(horse).toContain("Artwork Album");expect(horse).toContain("External URL")});
});
