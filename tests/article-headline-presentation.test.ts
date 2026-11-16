import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const ui=readFileSync(new URL("../app/handbook.tsx",import.meta.url),"utf8");
const css=readFileSync(new URL("../app/article-headline.css",import.meta.url),"utf8");
describe("article headline presentation",()=>{it("uses a simple readable headline card",()=>{expect(ui).toContain('className="handbookarticlehead"');expect(ui).not.toContain('<header><p className="eyebrow">{article.category}</p>');expect(css).toContain("background: #fff");expect(css).toContain("color: #3f2856");expect(css).toContain("display: block");expect(css).toMatch(/@media \(max-width: 700px\)/)})});
