import{describe,expect,it}from"vitest";
import fs from"node:fs";
import path from"node:path";

const root=path.resolve(__dirname,"..");
const page=fs.readFileSync(path.join(root,"app/page.tsx"),"utf8");
const storeCss=fs.readFileSync(path.join(root,"app/store-catalog-cleanup.css"),"utf8");
const nextConfig=fs.readFileSync(path.join(root,"next.config.ts"),"utf8");

describe("targeted LE Store correction",()=>{
 it("keeps exactly three player-facing Store departments",()=>{expect(page).toContain('type StoreDepartment="horses"|"feed"|"tack"');expect(page).not.toContain('>Stable Supplies</button>');expect(page.match(/openStoreDepartment\("(horses|feed|tack)"\)/g)).toHaveLength(3)});
 it("safely redirects the retired Stable Supplies route",()=>{expect(nextConfig).toContain('source: "/store/supplies/:path*"');expect(nextConfig).toContain('destination: "/store/foundation-horses"')});
 it("supports authoritative tier and quality filtering",()=>{expect(page).toContain('const STORE_TIERS=["Entry","Quality","Elite","Legendary"]');expect(page).toContain('product.quality===productTier');expect(page).toContain("const feedQualityOrder=useMemo")});
 it("supports tier and price sorting in both directions",()=>{for(const value of ["tier-asc","tier-desc","price-asc","price-desc"])expect(page).toContain(`value="${value}"`);expect(page).toContain('tierOrder.indexOf(a.quality??"")');expect(page).toContain('a.price-b.price');expect(page).toContain('b.price-a.price')});
 it("renders compact Foundation cards without the seven-stat strip",()=>{const card=page.slice(page.indexOf("function StoreCard"),page.indexOf("function StorePreview"));expect(card).not.toContain("GAME.stats.map");expect(card).toContain("storeAgeLabel(h)");expect(card).toContain("h.color");expect(card).toContain("h.breed");expect(card).toContain("h.sex");expect(card).toContain("View Horse");expect(storeCss).toContain("stats stay on View Horse");expect(storeCss).toContain("grid-template-columns:repeat(4,minmax(0,1fr))")});
});
