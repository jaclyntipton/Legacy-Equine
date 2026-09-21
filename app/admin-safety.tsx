"use client";
import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import "@/app/admin-safety.css";
const supabase = createClient();
type Event = {
  id: string;
  content_type: string;
  content_id: string | null;
  account_number: number | null;
  author: string | null;
  category: string;
  severity: string;
  action: string;
  status: string;
  content_evidence: string;
  created_at: string;
  review_note: string | null;
};
type Rule = {
  id: string;
  label: string;
  pattern: string;
  category: string;
  severity: string;
  action: string;
  active: boolean;
  version: number;
};
type Report = { id:string;ticket_number:string;title:string;status:string;account_number:number;author:string;created_at:string };
export function AdminSafety({ notify }: { notify: (message: string) => void }) {
  const [data, setData] = useState<{ queue: Event[]; rules: Rule[]; reports:Report[] }>({
      queue: [],
      rules: [],
      reports: [],
    }),
    [tab, setTab] = useState("queue"),
    [sample, setSample] = useState(""),
    [testResult, setTestResult] = useState<Record<string, string> | null>(null),
    [editing, setEditing] = useState<Rule | null>(null),
    [note, setNote] = useState("Reviewed by Safety Admin");
  const load = useCallback(async () => {
    const { data: next, error } = await supabase.rpc(
      "admin_moderation_workspace",
    );
    if (error) notify(error.message);
    else setData(next as typeof data);
  }, [notify]);
  useEffect(() => {
    const timer = setTimeout(() => void load(), 0);
    return () => clearTimeout(timer);
  }, [load]);
  const test = async () => {
    const { data: result, error } = await supabase.rpc(
      "admin_test_moderation",
      { p_text: sample },
    );
    if (error) notify(error.message);
    else setTestResult(result);
  };
  const save = async () => {
    if (!editing) return;
    const { error } = await supabase.rpc("admin_save_moderation_rule", {
      p_id: editing.id || null,
      p_label: editing.label,
      p_pattern: editing.pattern,
      p_category: editing.category,
      p_severity: editing.severity,
      p_action: editing.action,
      p_active: editing.active,
    });
    notify(error?.message ?? "Private moderation rule saved and audited.");
    if (!error) {
      setEditing(null);
      await load();
    }
  };
  const remove=async()=>{if(!editing?.id)return;const{error}=await supabase.rpc("admin_delete_moderation_rule",{p_id:editing.id});notify(error?.message??"Private moderation rule removed and audited.");if(!error){setEditing(null);await load()}};
  const resolve = async (id: string, status: string) => {
    const { error } = await supabase.rpc("admin_resolve_moderation_event", {
      p_event: id,
      p_status: status,
      p_note: note,
    });
    notify(error?.message ?? "Moderation review saved and audited.");
    if (!error) await load();
  };
  return (
    <div className="adminsafety">
      <nav className="sectiontabs">
        <button
          className={tab === "queue" ? "active" : ""}
          onClick={() => setTab("queue")}
        >
          Review Queue
        </button>
        <button
          className={tab === "rules" ? "active" : ""}
          onClick={() => setTab("rules")}
        >
          Moderation Rules
        </button>
        <button
          className={tab === "reports" ? "active" : ""}
          onClick={() => setTab("reports")}
        >
          Reported Content
        </button>
        <button
          className={tab === "test" ? "active" : ""}
          onClick={() => setTab("test")}
        >
          Moderation Test
        </button>
        <button
          className={tab === "history" ? "active" : ""}
          onClick={() => setTab("history")}
        >
          Actions / History
        </button>
      </nav>
      {(tab === "queue" || tab === "history") && (
        <section className="panel">
          <p className="eyebrow">PRIVATE SAFETY REVIEW</p>
          <h2>{tab === "queue" ? "Review Queue" : "Moderation History"}</h2>
          <label>
            Review note
            <input value={note} onChange={(e) => setNote(e.target.value)} />
          </label>
          <div className="safetyqueue">
            {data.queue
              .filter((x) =>
                tab === "queue"
                  ? x.status === "pending"
                  : x.status !== "pending",
              )
              .map((item) => (
                <article key={item.id}>
                  <header>
                    <b>{item.category.replaceAll("_", " ")}</b>
                    <span>
                      {item.severity} · {item.action}
                    </span>
                  </header>
                  <small>
                    {item.content_type} · Account #
                    {item.account_number ?? "deleted"} ·{" "}
                    {new Date(item.created_at).toLocaleString()}
                  </small>
                  <p>{item.content_evidence}</p>
                  <div>
                    <button onClick={() => void resolve(item.id, "dismissed")}>
                      Dismiss False Positive
                    </button>
                    <button onClick={() => void resolve(item.id, "reviewed")}>
                      Mark Reviewed
                    </button>
                    <button onClick={() => void resolve(item.id, "actioned")}>
                      Action Taken
                    </button>
                  </div>
                </article>
              ))}
            {!data.queue.some((x) =>
              tab === "queue" ? x.status === "pending" : x.status !== "pending",
            ) && <p className="featurehint">No items in this view.</p>}
          </div>
        </section>
      )}
      {tab==="reports"&&<section className="panel"><p className="eyebrow">PLAYER REPORTS</p><h2>Reported Content</h2><div className="safetyqueue">{data.reports.map(report=><article key={report.id}><header><b>{report.ticket_number} · {report.title}</b><span>{report.status}</span></header><small>Account #{report.account_number} · {new Date(report.created_at).toLocaleString()}</small><a href={`/admin/support?ticket=${report.id}`}>Open in Support →</a></article>)}{!data.reports.length&&<p className="featurehint">No reported content tickets.</p>}</div></section>}
      {tab === "rules" && (
        <section className="panel">
          <div className="safetytitle">
            <div>
              <p className="eyebrow">OWNER-MANAGED · PRIVATE</p>
              <h2>Moderation Rules</h2>
            </div>
            <button
              className="primary"
              onClick={() =>
                setEditing({
                  id: "",
                  label: "",
                  pattern: "",
                  category: "harassment",
                  severity: "medium",
                  action: "block",
                  active: true,
                  version: 1,
                })
              }
            >
              Add Rule
            </button>
          </div>
          <div className="safetyrules">
            {data.rules.map((rule) => (
              <button key={rule.id} onClick={() => setEditing(rule)}>
                <span>
                  <b>{rule.label}</b>
                  <small>
                    {rule.category} · v{rule.version}
                  </small>
                </span>
                <em>{rule.active ? rule.action : "disabled"}</em>
              </button>
            ))}
          </div>
        </section>
      )}
      {tab === "test" && (
        <section className="panel safetytest">
          <p className="eyebrow">DOES NOT PUBLISH</p>
          <h2>Moderation Test</h2>
          <textarea
            rows={6}
            value={sample}
            onChange={(e) => setSample(e.target.value)}
            placeholder="Test normal horse language or a suspected rule match…"
          />
          <button
            className="primary"
            disabled={!sample.trim()}
            onClick={() => void test()}
          >
            Test Sample
          </button>
          {testResult && (
            <p className="testresult">
              <b>{testResult.action?.toUpperCase()}</b>
              {testResult.category &&
                ` · ${testResult.category.replaceAll("_", " ")}`}
              {testResult.rule_reference &&
                ` · Rule ${testResult.rule_reference}`}
            </p>
          )}
        </section>
      )}
      {editing && (
        <section className="panel ruleeditor">
          <h2>{editing.id ? "Edit Rule" : "Add Rule"}</h2>
          <label>
            Internal label
            <input
              value={editing.label}
              onChange={(e) =>
                setEditing({ ...editing, label: e.target.value })
              }
            />
          </label>
          <label>
            Private pattern
            <textarea
              value={editing.pattern}
              onChange={(e) =>
                setEditing({ ...editing, pattern: e.target.value })
              }
            />
          </label>
          <div>
            <label>
              Category
              <select
                value={editing.category}
                onChange={(e) =>
                  setEditing({ ...editing, category: e.target.value })
                }
              >
                {[
                  "sexual_explicit",
                  "sexual_solicitation",
                  "harassment",
                  "threats_violence",
                  "self_harm",
                  "hate",
                  "predatory",
                  "personal_information",
                  "spam_scam",
                ].map((x) => (
                  <option key={x}>{x}</option>
                ))}
              </select>
            </label>
            <label>
              Severity
              <select
                value={editing.severity}
                onChange={(e) =>
                  setEditing({ ...editing, severity: e.target.value })
                }
              >
                {["low", "medium", "high", "urgent"].map((x) => (
                  <option key={x}>{x}</option>
                ))}
              </select>
            </label>
            <label>
              Action
              <select
                value={editing.action}
                onChange={(e) =>
                  setEditing({ ...editing, action: e.target.value })
                }
              >
                {["warn", "block", "review", "urgent_review"].map((x) => (
                  <option key={x}>{x}</option>
                ))}
              </select>
            </label>
          </div>
          <label>
            <input
              type="checkbox"
              checked={editing.active}
              onChange={(e) =>
                setEditing({ ...editing, active: e.target.checked })
              }
            />{" "}
            Active
          </label>
          <div>
            {editing.id&&<button onClick={() => void remove()}>Remove Rule</button>}
            <button onClick={() => setEditing(null)}>Cancel</button>
            <button className="primary" onClick={() => void save()}>
              Save Rule
            </button>
          </div>
        </section>
      )}
    </div>
  );
}
