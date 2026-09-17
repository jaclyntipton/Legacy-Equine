import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const css=readFileSync("app/public-stable-profile.css","utf8");
describe("mobile My Stable header",()=>{it("stacks identity and touch-friendly actions without overlap",()=>{expect(css).toContain("@media(max-width:480px)");expect(css).toContain(".stablemanagementhead{display:flex;align-items:stretch;flex-direction:column}");expect(css).toContain(".stableprofileactions{display:grid;width:100%;grid-template-columns:1fr");expect(css).toContain("min-height:44px")})});
