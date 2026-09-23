import { readFileSync, readdirSync, statSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  "supabase/migrations/202609220008_rpc_execute_authorization_hardening.sql",
  "utf8",
);
const completionMigration = readFileSync(
  "supabase/migrations/202609220010_rpc_browser_allowlist_completion.sql",
  "utf8",
);

function sourceFiles(root: string): string[] {
  return readdirSync(root).flatMap((entry) => {
    const path = `${root}/${entry}`;
    if (path.startsWith("app/api/")) return [];
    return statSync(path).isDirectory() ? sourceFiles(path) : /\.(ts|tsx)$/.test(path) ? [path] : [];
  });
}

function registered(section: "v_authenticated" | "v_anon") {
  const body = migration.match(new RegExp(`${section} text\\[\\] := array\\[([\\s\\S]*?)\\n  \\];`))?.[1] ?? "";
  return new Set([...body.matchAll(/'([a-zA-Z0-9_]+)'/g)].map((match) => match[1]));
}

describe("RPC execute authorization hardening", () => {
  it("removes inherited client execution before applying explicit grants", () => {
    expect(migration).toContain("revoke execute on function %s from public, anon, authenticated");
    expect(migration).toContain("grant execute on function %s to authenticated");
    expect(migration).toContain("grant execute on function %s to anon");
  });

  it("keeps privileged server jobs out of browser allowlists", () => {
    expect(migration).not.toMatch(/v_authenticated[\s\S]*?'process_due_news'/);
    expect(migration).not.toMatch(/v_authenticated[\s\S]*?'owner_register_prepared_visual_asset'/);
    expect(migration).not.toMatch(/v_anon[\s\S]*?'process_due_news'/);
  });

  it("keeps sensitive player and admin calls authenticated", () => {
    for (const rpc of [
      "get_bank_activity",
      "allocate_horse_ap",
      "get_my_support_tickets",
      "admin_adjust_balance",
      "owner_set_admin_permissions",
    ]) {
      expect(migration).toMatch(new RegExp(`v_authenticated[\\s\\S]*?'${rpc}'`));
    }
  });

  it("keeps the anonymous allowlist deliberately narrow", () => {
    const anon = migration.match(/v_anon text\[\] := array\[([\s\S]*?)\n  \];/)?.[1] ?? "";
    expect((anon.match(/'/g) ?? []).length / 2).toBe(8);
    expect(anon).toContain("'public_signup_availability'");
    expect(anon).not.toContain("get_bank_activity");
    expect(anon).not.toContain("get_chat_messages");
    expect(anon).not.toContain("get_my_support_tickets");
  });

  it("registers every literal browser RPC used by the production application", () => {
    const used = new Set(
      sourceFiles("app").flatMap((file) =>
        [...readFileSync(file, "utf8").matchAll(/\.rpc\(\s*["']([a-zA-Z0-9_]+)["']/g)].map(
          (match) => match[1],
        ),
      ),
    );
    const allowed = registered("v_authenticated");
    for (const match of completionMigration.matchAll(/'([a-zA-Z0-9_]+)'/g)) allowed.add(match[1]);
    for (const name of registered("v_anon")) allowed.add(name);
    expect([...used].filter((name) => !allowed.has(name))).toEqual([]);
    expect(used.size).toBe(163);
  });
});
