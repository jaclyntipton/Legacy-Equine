import{readFileSync,existsSync}from"node:fs";import{describe,expect,it}from"vitest";
const page=readFileSync(new URL("../app/page.tsx",import.meta.url),"utf8"),art=readFileSync(new URL("../lib/game/horse-artwork.ts",import.meta.url),"utf8"),card=page.slice(page.indexOf("function StoreCard"),page.indexOf("function StorePreview"));
describe("actual Foundation Store card render path",()=>{
 it("renders the tracked generic PNG through the real StoreCard",()=>{expect(existsSync(new URL("../public/generic-horse-placeholder.png",import.meta.url))).toBe(true);expect(card).toContain('<HorseArtworkImage url="" alt={h.name}/>');expect(art).toContain('GENERIC_HORSE_PLACEHOLDER="/generic-horse-placeholder.png"')});
 it("contains identity, price, and actions but zero seven-stat rendering",()=>{for(const value of["h.name","h.breed","h.sex","storeAgeLabel(h)","h.color","h.mature_height_hands","h.price","View Horse","Purchase"])expect(card).toContain(value);expect(card).not.toContain("GAME.stats");expect(card).not.toContain("storestats");for(const stat of["Agility","Speed","Endurance","Temperament","Strength","Intelligence","Conformation"])expect(card).not.toContain(stat)});
});
