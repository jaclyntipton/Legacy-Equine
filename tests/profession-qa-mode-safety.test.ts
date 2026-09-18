import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const ui=readFileSync("app/professions.tsx","utf8");
const css=readFileSync("app/profession-qa-safety.css","utf8");
const openQa=ui.slice(ui.indexOf("const openQaCareer"),ui.indexOf("const openTest"));
const stageSelector=ui.slice(ui.indexOf('value={qaStage}'),ui.indexOf('</select>',ui.indexOf('value={qaStage}')));
const modeToggle=ui.slice(ui.indexOf('checked={runNormal}'),ui.indexOf('</label>',ui.indexOf('checked={runNormal}')));
describe("Owner Profession QA gameplay mode safety",()=>{
 it("does not change gameplay mode when Profession or Level changes",()=>{expect(openQa).not.toContain("setRunNormal");expect(openQa).toContain("openCareerRoute(professionId, true)")});
 it("does not change gameplay mode when Stage changes",()=>{expect(stageSelector).not.toContain("setRunNormal");expect(stageSelector).toContain("setQaStage(value)")});
 it("changes gameplay mode only through the enrollment-aware explicit toggle and retains the QA workspace",()=>{expect(modeToggle).toContain("requestLiveMode(p, event.target.checked)");expect(modeToggle).not.toContain("setCareer(");expect(modeToggle).not.toContain("history.replaceState")});
 it("resets gameplay mode when the Career is exited",()=>{const exit=ui.slice(ui.indexOf("const backToProfessions"),ui.indexOf("const run ="));expect(exit).toContain("setRunNormal(false)")});
 it("shows persistent, explicit live and preview banners",()=>{expect(ui).toContain("LIVE GAMEPLAY");expect(ui).toContain("progress, certifications, rates and services will be permanently saved.");expect(ui).toContain("QA PREVIEW");expect(ui).toContain("changes will not affect permanent progression or market data.");expect(css).toContain("position:sticky");expect(css).toContain(".qamodebanner.live");expect(css).toContain(".qamodebanner.preview")});
 it("labels test, rate, and advancement writes as saved or not saved",()=>{for(const label of["Submit QA Test — Not Saved","Submit Certification Test","Save QA Rate — Not Saved","Save Rate — Permanently Saved","Advance to ${advanceName} — Not Saved","Advance to ${advanceName} — Permanently Saved"])expect(ui).toContain(label)});
});
