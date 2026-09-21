import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";

const profile=readFileSync(new URL("../app/horse-profile.tsx",import.meta.url),"utf8");

describe("Horse Profile stats consolidation",()=>{
 it("removes the redundant Stats tab while preserving the remaining navigation",()=>{expect(profile).toContain('tabs:Tab[]=["overview","training","shows","farrier","health","pedigree","progeny","breeding"]');expect(profile).not.toContain('tab==="stats"')});
 it("normalizes legacy Stats deep links to Overview",()=>{expect(profile).toContain('location.hash==="#stats"||location.pathname.endsWith("/stats")');expect(profile).toContain('`/horses/${h.id}#overview`')});
 it("keeps all seven authoritative Effective Stat chips expandable one at a time",()=>{expect(profile).toContain('aria-label="All horse stats"');expect(profile).toContain('openStat===stat');expect(profile).toContain('setOpenStat(shown?null:stat)');expect(profile).toContain('aria-expanded={shown}');expect(profile).toContain('GAME.stats.map')});
 it("shows the authoritative permanent and temporary breakdown without stat bars",()=>{expect(profile).toContain('Permanent Development: +{d.development}');expect(profile).toContain('Developed / Permanent: {d.developed}');expect(profile).toContain('Active Farrier: +{d.farrier}');expect(profile).toContain('Active Massage: +{d.massage}');expect(profile).toContain('Effective Stat: {d.effective}');expect(profile).not.toContain('className="statdetails"')});
 it("preserves permanent average, Show Level, tack, AP, history, and Owner gating",()=>{expect(profile).toContain('PERMANENT STAT AVERAGE');expect(profile).toContain('SHOW LEVEL');expect(profile).toContain('EquippedTackStrip');expect(profile).toContain('HorseAllocatablePoints');expect(profile).toContain('isAdmin={isAdmin}')});
});
