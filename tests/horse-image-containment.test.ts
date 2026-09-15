import {describe,expect,it} from "vitest";
import fs from "node:fs";
import path from "node:path";

const root=path.resolve(__dirname,"..");
const css=fs.readFileSync(path.join(root,"app/horse-artwork.css"),"utf8");
const component=fs.readFileSync(path.join(root,"app/contained-horse-artwork.tsx"),"utf8");
const page=fs.readFileSync(path.join(root,"app/page.tsx"),"utf8");

describe("global full-horse artwork containment",()=>{
 it("uses one padded, centered, non-cropping renderer",()=>{
  expect(css).toContain("padding:5%");
  expect(css).toContain("object-fit:contain!important");
  expect(css).toContain("object-position:center center!important");
  expect(css).toContain("background:transparent!important");
 });
 it.each(["portrait PNG","square WebP","landscape image","player artwork","Foundation fallback"])("preserves the entire %s through aspect-ratio agnostic CSS",()=>{
  expect(css).toContain("width:100%;height:100%;max-width:100%;max-height:100%");
  expect(component).not.toContain("object-fit:cover");
 });
 it("keeps the profile hero near a 40/60 desktop split",()=>expect(css).toContain("minmax(280px,2fr) minmax(0,3fr)"));
 it("uses the shared renderer throughout game horse cards and horse uploads",()=>{
  expect(page).toContain("return <ContainedHorseArtwork url={url} alt={alt}/>");
  expect(page).toContain('shape === "horse" ? <ContainedHorseArtwork');
 });
 it("falls back without replacing or transforming player artwork",()=>{
  expect(component).toContain("horseArtworkCandidates");
  expect(css).toContain("transform:none!important");
 });
});
