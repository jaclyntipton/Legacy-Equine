import{describe,expect,it}from"vitest";import{renderToStaticMarkup}from"react-dom/server";import{NavIcon}from"../app/nav-icons";import{readFileSync}from"node:fs";
const names=["barn","store","round-pen","trophy","sale-tag","toolbox","bulletin","coin","heart"] as const;
describe("intentional navigation icon family",()=>{
 it.each(names)("renders accessible consistent %s SVG",name=>{const html=renderToStaticMarkup(<NavIcon name={name}/>);expect(html).toContain("<svg");expect(html).toContain('viewBox="0 0 24 24"');expect(html).toContain('aria-hidden="true"');expect(html).toContain('stroke="currentColor"');expect(html).not.toMatch(/[🐴🏪🏆🏷🧰]/)});
 it("replaces every placeholder in the game navigation",()=>{const page=readFileSync(new URL("../app/page.tsx",import.meta.url),"utf8"),nav=page.slice(page.indexOf('<nav className="game-nav"'),page.indexOf('<div className="sidebar-note"'));for(const name of names)expect(nav).toContain(`<NavIcon name="${name}"/>`);expect(nav).not.toMatch(/<span>[♞✦↗◇⌂✚◎◉♡]<\/span>/)});
});
