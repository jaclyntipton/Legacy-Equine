import { describe, expect, it } from "vitest";
import fs from "node:fs";

const ui = fs.readFileSync("app/professions.tsx", "utf8");
const css = fs.readFileSync("app/theme.css", "utf8");

describe("profession certification answer controls", () => {
  it("associates each full answer row with its radio and updates answer state safely", () => {
    expect(ui).toContain('className="examanswer"');
    expect(ui).toContain('htmlFor={`profession-answer-${q.id}-${choiceIndex}`}');
    expect(ui).toContain('id={`profession-answer-${q.id}-${choiceIndex}`}');
    expect(ui).toContain("setAnswers((current) => ({");
  });

  it("keeps answer rows touch friendly and visibly selected", () => {
    expect(css).toContain(".inlineexam .examanswer{min-height:44px");
    expect(css).toContain(".examanswer:has(input:checked)");
  });
});
