import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const migration=readFileSync("supabase/migrations/202611020001_restore_profession_certification_rpc_access.sql","utf8");

describe("Profession certification browser RPC access",()=>{
  it("restores both normal and authorized QA question/test endpoints",()=>{
    for(const name of[
      "get_certification_questions",
      "take_certification_test",
      "get_profession_qa_questions",
      "grade_profession_qa_test",
    ])expect(migration).toContain(`'${name}'`);
    expect(migration).toContain("grant execute on function %s to authenticated");
    expect(migration).toContain("has_function_privilege('authenticated',p.oid,'execute')");
  });

  it("does not expose certification endpoints anonymously",()=>{
    expect(migration).not.toContain("to anon");
    expect(migration).not.toContain("to public");
  });
});
