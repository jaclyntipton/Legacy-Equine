"use client";
/* eslint-disable @next/next/no-img-element */

import { useCallback, useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import "./news-digest-admin.css";

const supabase = createClient();

type Post = {
  id: string;
  title: string;
  summary: string;
  body: string;
  category: string;
  image_url: string | null;
  destination_url: string | null;
  pinned: boolean;
  status: string;
  publish_at: string | null;
  expires_at: string | null;
  published_at?: string | null;
  created_at?: string;
};

type NewsForm = {
  id: string | null;
  title: string;
  summary: string;
  body: string;
  category: string;
  image_url: string;
  destination_url: string;
  pinned: boolean;
  status: string;
  publish_at: string;
  expires_at: string;
};

type LibraryFilter = "all" | "draft" | "published" | "scheduled" | "archived";
type DigestPost={id:string;title:string;summary:string;category:string;destination_url:string|null;published_at:string};
type DigestRun={week_key:string;status:string;eligible_count:number;sent_count:number;failed_count:number;skip_reason:string|null;started_at:string;completed_at:string|null};
type DigestData={config:{enabled:boolean;window_days:number;max_articles:number;subject_prefix:string};subscriber_count:number;preview_posts:DigestPost[];recent_runs:DigestRun[]};

const blank: NewsForm = {
  id: null,
  title: "",
  summary: "",
  body: "",
  category: "official",
  image_url: "",
  destination_url: "",
  pinned: false,
  status: "draft",
  publish_at: "",
  expires_at: "",
};

const categories: Record<string, string> = {
  official: "Official News",
  updates: "Game Updates",
  shows: "Shows & Events",
  contests: "Contests",
  community: "Community",
};

const snapshot = (value: NewsForm) => JSON.stringify(value);
const dateInput = (value: string | null | undefined) => {
  if (!value) return "";
  const date = new Date(value), pad = (part: number) => String(part).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
};
const displayDate = (value: string | null | undefined) => value ? new Date(value).toLocaleDateString() : "";
const isScheduled = (post: Pick<Post, "status" | "publish_at">, now: number) => post.status === "scheduled" && Boolean(post.publish_at) && new Date(post.publish_at!).getTime() > now;
const statusLabel = (post: Pick<Post, "status" | "publish_at">, now: number) => post.status === "scheduled" ? (post.publish_at && new Date(post.publish_at).getTime() <= now ? "Publication overdue" : "Scheduled") : post.status === "published" ? "Published" : post.status === "unpublished" ? "Unpublished" : post.status === "archived" ? "Archived" : "Draft";
const displayDateTime = (value: string | null | undefined) => value ? new Intl.DateTimeFormat("en-US", { timeZone: "America/New_York", dateStyle: "medium", timeStyle: "short", timeZoneName: "short" }).format(new Date(value)) : "";

function toForm(post: Post): NewsForm {
  return {
    id: post.id,
    title: post.title,
    summary: post.summary,
    body: post.body,
    category: post.category,
    image_url: post.image_url ?? "",
    destination_url: post.destination_url ?? "",
    pinned: post.pinned,
    status: post.status,
    publish_at: dateInput(post.publish_at),
    expires_at: dateInput(post.expires_at),
  };
}

export function AdminNews({ notify }: { notify: (message: string) => void }) {
  const [posts, setPosts] = useState<Post[]>([]);
  const [form, setForm] = useState<NewsForm>(blank);
  const [savedSnapshot, setSavedSnapshot] = useState(snapshot(blank));
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<LibraryFilter>("all");
  const [busy, setBusy] = useState(false);
  const [confirmUnpublish, setConfirmUnpublish] = useState(false);
  const [renderNow] = useState(() => Date.now());
  const dirty = snapshot(form) !== savedSnapshot;

  const load = useCallback(async () => {
    const { data, error } = await supabase.rpc("admin_news_list");
    if (error) notify(error.message);
    else setPosts((data ?? []) as Post[]);
  }, [notify]);

  useEffect(() => { const timer = window.setTimeout(() => void load(), 0); return () => window.clearTimeout(timer); }, [load]);
  useEffect(() => {
    const guard = (event: BeforeUnloadEvent) => {
      if (!dirty) return;
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", guard);
    return () => window.removeEventListener("beforeunload", guard);
  }, [dirty]);

  const choose = (next: NewsForm) => {
    if (dirty && !window.confirm("You have unsaved changes.\n\nDiscard changes and continue?")) return;
    setForm(next);
    setSavedSnapshot(snapshot(next));
    setConfirmUnpublish(false);
  };

  const update = <K extends keyof NewsForm>(key: K, value: NewsForm[K]) => setForm(current => ({ ...current, [key]: value }));

  const quickAction = async (post: Post, action: "pin" | "unpin" | "publish" | "unpublish" | "archive") => {
    if (action === "archive" && !window.confirm(`Archive “${post.title}”? It will leave public News but remain in Admin history.`)) return;
    setBusy(true);
    const { error } = await supabase.rpc("admin_news_quick_action", { p_id: post.id, p_action: action });
    setBusy(false);
    if (error) return notify(error.message);
    const messages = { pin: "Primary pinned story updated.", unpin: "Article unpinned and still published.", publish: "Article published.", unpublish: "Article unpublished.", archive: "Article archived." };
    notify(messages[action]);
    if (form.id === post.id) {
      const next = { ...form, pinned: action === "pin" ? true : action === "unpin" || action === "archive" ? false : form.pinned, status: action === "publish" ? "published" : action === "unpublish" ? "unpublished" : action === "archive" ? "archived" : form.status };
      setForm(next); setSavedSnapshot(snapshot(next));
    }
    await load();
  };

  const save = async (status: "draft" | "scheduled" | "published" | "unpublished") => {
    if (!form.title.trim()) return notify("Add a title before saving.");
    setBusy(true);
    const { data, error } = await supabase.rpc("admin_save_news", {
      p_id: form.id,
      p_title: form.title,
      p_summary: form.summary,
      p_body: form.body,
      p_category: form.category,
      p_image_url: form.image_url || null,
      p_destination: form.destination_url || null,
      p_pinned: form.pinned,
      p_status: status,
      p_publish_at: form.publish_at ? new Date(form.publish_at).toISOString() : null,
      p_expires_at: form.expires_at ? new Date(form.expires_at).toISOString() : null,
    });
    setBusy(false);
    if (error) return notify(error.message);
    const saved = { ...form, id: (data as string) || form.id, status };
    setForm(saved);
    setSavedSnapshot(snapshot(saved));
    setConfirmUnpublish(false);
    notify(status === "scheduled" ? "News scheduled." : status === "published" ? "News published." : status === "unpublished" ? "News unpublished." : "Draft saved.");
    await load();
  };

  const filtered = useMemo(() => posts.filter(post => {
    const query = search.trim().toLowerCase();
    const matchesSearch = !query || `${post.title} ${post.summary} ${categories[post.category] ?? post.category}`.toLowerCase().includes(query);
    const label = statusLabel(post, renderNow).toLowerCase();
    return matchesSearch && (filter === "all" || label === filter);
  }), [posts, search, filter, renderNow]);

  const selectedWasPublished = posts.find(post => post.id === form.id)?.status === "published";
  const previewDate = form.publish_at ? new Date(form.publish_at) : new Date();

  return (
    <section className="adminnews newsroom">
      <header className="newsroom-header admin-section-header">
        <div>
          <p className="eyebrow">NEWS PUBLISHER</p>
          <h2>News Publisher</h2>
          <p>Create and manage Legacy Equine announcements, updates, events and community news.</p>
        </div>
        <button className="primary admin-section-action" onClick={() => choose(blank)}>+ New Article</button>
      </header>

      <div className="newsroom-workspace">
        <aside className="news-library" aria-label="News Library">
          <div className="newsroom-panel-title"><div><p className="eyebrow">LIBRARY</p><h3>News Library</h3></div><span>{filtered.length}</span></div>
          <label className="sr-only" htmlFor="news-search">Search articles</label>
          <input id="news-search" type="search" placeholder="Search articles..." value={search} onChange={event => setSearch(event.target.value)} />
          <div className="news-library-filters" aria-label="Filter news articles">
            {(["all", "draft", "published", "scheduled", "archived"] as LibraryFilter[]).map(value => <button key={value} className={filter === value ? "active" : ""} onClick={() => setFilter(value)}>{value[0].toUpperCase() + value.slice(1)}</button>)}
          </div>
          <div className="news-library-list">
            {filtered.map(post => <article key={post.id} className={form.id === post.id ? "active" : ""}>
              <button className="news-library-select" onClick={() => choose(toForm(post))}>
                <b>{post.title || "Untitled article"}</b>
                <span>{categories[post.category] ?? post.category}</span>
                <small>{statusLabel(post, renderNow)}{post.pinned ? " • Primary Pinned" : ""}</small>
                {(post.publish_at || post.published_at || post.created_at) && <time>{displayDate(post.publish_at || post.published_at || post.created_at)}</time>}
              </button>
              <details className="news-library-actions"><summary aria-label={`Actions for ${post.title}`}>•••</summary><div>
                <button onClick={() => choose(toForm(post))}>Edit</button>
                <button onClick={() => { choose(toForm(post)); requestAnimationFrame(() => document.querySelector(".news-public-preview")?.scrollIntoView({ behavior: "smooth", block: "center" })); }}>Preview</button>
                {post.status === "published" && <button onClick={() => void quickAction(post, post.pinned ? "unpin" : "pin")}>{post.pinned ? "Unpin" : "Pin as Primary"}</button>}
                {post.status === "published" ? <button onClick={() => void quickAction(post, "unpublish")}>Unpublish</button> : post.status !== "archived" && <button onClick={() => void quickAction(post, "publish")}>Publish</button>}
                {post.status !== "archived" && <button className="danger" onClick={() => void quickAction(post, "archive")}>Archive</button>}
              </div></details>
            </article>)}
            {!filtered.length && <p className="news-library-empty">No articles match this view.</p>}
          </div>
        </aside>

        <main className="news-article-editor">
          <div className="newsroom-panel-title">
            <div><p className="eyebrow">ARTICLE EDITOR</p><h3>{form.id ? "Edit Article" : "New Article"}</h3></div>
            <span className={dirty ? "dirty" : "saved"}>{dirty ? "Unsaved changes" : "Saved"}</span>
          </div>
          <div className="news-editor-fields">
            <label>Title<input value={form.title} maxLength={140} placeholder="Article title" onChange={event => update("title", event.target.value)} /></label>
            <label>Summary<textarea rows={3} value={form.summary} maxLength={300} placeholder="A concise description for News cards" onChange={event => update("summary", event.target.value)} /></label>
            <label>Category<select value={form.category} onChange={event => update("category", event.target.value)}>{Object.entries(categories).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
            <label className="news-body-field">Body
              <textarea rows={15} value={form.body} maxLength={10000} placeholder="Write the full announcement..." onChange={event => update("body", event.target.value)} />
              <small>Plain sanitized text. HTML, scripts, embeds and external destinations are not accepted.</small>
            </label>
          </div>

          <section className="news-media-link">
            <div><p className="eyebrow">SECONDARY CONTENT</p><h3>Media &amp; Link</h3></div>
            <label>Article Image<input type="url" placeholder="https://..." value={form.image_url} onChange={event => update("image_url", event.target.value)} /><small>Optional image URL. Existing News image storage remains unchanged.</small></label>
            <label>Internal Destination<input placeholder="/shows" pattern="/[A-Za-z0-9_?&=#./-]+" value={form.destination_url} onChange={event => update("destination_url", event.target.value)} /><small>Optional — where players go when they open this announcement.</small></label>
          </section>

          <PublicPreview form={form} date={previewDate} live={!dirty && form.status === "published" && !isScheduled(form, renderNow)} />
        </main>

        <aside className="news-publish-settings">
          <div className="newsroom-panel-title"><div><p className="eyebrow">PUBLICATION</p><h3>Publish</h3></div></div>
          <div className="publish-status"><span>Status</span><b data-status={statusLabel(form, renderNow).toLowerCase()}>{statusLabel(form, renderNow)}</b></div>
          <dl><div><dt>Category</dt><dd>{categories[form.category]}</dd></div>{form.publish_at&&<div><dt>{form.status==="published"?"Published":"Publishes"}</dt><dd>{displayDateTime(form.status==="published"?(posts.find(post=>post.id===form.id)?.published_at??form.publish_at):form.publish_at)}</dd></div>}</dl>
          <label>Publish Date &amp; Time<input type="datetime-local" value={form.publish_at} onChange={event => update("publish_at", event.target.value)} /><small>Leave blank to publish immediately.</small></label>
          <label>Expiration<input type="datetime-local" value={form.expires_at} onChange={event => update("expires_at", event.target.value)} /><small>Optional — automatically removes the article from the public feed.</small></label>
          <label className="news-feature-toggle"><input type="checkbox" checked={form.pinned} onChange={event => update("pinned", event.target.checked)} /><span><b>Featured / Important</b><small>Pin this article above the Latest News feed.</small></span></label>
          <div className="news-publish-actions">
            <button className="primary" disabled={busy || !form.title.trim()} onClick={() => void save(form.publish_at && new Date(form.publish_at).getTime() > Date.now() ? "scheduled" : "published")}>{busy ? "Saving..." : selectedWasPublished ? "Update Published Article" : form.publish_at && new Date(form.publish_at).getTime() > renderNow ? "Schedule Article" : "Publish"}</button>
            <button disabled={busy || !dirty} onClick={() => void save("draft")}>Save Draft</button>
            <button onClick={() => document.querySelector(".news-public-preview")?.scrollIntoView({ behavior: "smooth", block: "center" })}>Preview</button>
          </div>
          {form.id && selectedWasPublished && <div className="news-unpublish-zone"><p>Remove this article from the public News feed.</p><button className="danger" onClick={() => setConfirmUnpublish(true)}>Unpublish</button></div>}
        </aside>
      </div>

      <WeeklyDigestAdmin notify={notify}/>

      {confirmUnpublish && <div className="news-confirm-backdrop" role="presentation" onMouseDown={event => { if (event.target === event.currentTarget) setConfirmUnpublish(false); }}>
        <section role="alertdialog" aria-modal="true" aria-labelledby="unpublish-title">
          <p className="eyebrow">CONFIRM ACTION</p><h3 id="unpublish-title">Unpublish this article?</h3><p>Players will no longer see it in the public News feed. The article record and content will be preserved.</p>
          <div><button onClick={() => setConfirmUnpublish(false)}>Cancel</button><button className="danger" disabled={busy} onClick={() => void save("unpublished")}>Unpublish</button></div>
        </section>
      </div>}
    </section>
  );
}

function WeeklyDigestAdmin({notify}:{notify:(message:string)=>void}){
 const[data,setData]=useState<DigestData|null>(null),[enabled,setEnabled]=useState(false),[days,setDays]=useState(7),[max,setMax]=useState(8),[subject,setSubject]=useState("Legacy Equine Weekly"),[providerReady,setProviderReady]=useState(false),[busy,setBusy]=useState(false);
 const load=useCallback(async()=>{const[{data:value,error},{data:{session}}]=await Promise.all([supabase.rpc("admin_get_news_digest"),supabase.auth.getSession()]);if(error)return notify(error.message);const next=value as DigestData;setData(next);setEnabled(next.config.enabled);setDays(next.config.window_days);setMax(next.config.max_articles);setSubject(next.config.subject_prefix);if(session){const response=await fetch("/api/admin/news-digest/status",{headers:{Authorization:`Bearer ${session.access_token}`}});if(response.ok)setProviderReady(Boolean((await response.json()).provider_ready))}},[notify]);
 useEffect(()=>{const timer=setTimeout(()=>void load(),0);return()=>clearTimeout(timer)},[load]);
 const save=async()=>{setBusy(true);const{error}=await supabase.rpc("admin_save_news_digest_config",{p_enabled:enabled,p_window_days:days,p_max_articles:max,p_subject_prefix:subject});setBusy(false);if(error)return notify(error.message);notify(enabled?"Weekly Digest schedule enabled.":"Weekly Digest schedule disabled.");await load()};
 return <section className="news-digest-admin"><header><div><p className="eyebrow">PLAYER EMAILS</p><h2>Weekly Game Digest</h2><p>Build one consent-only weekly email from authoritative published News. Routine gameplay is never emailed automatically.</p></div><span className={enabled&&providerReady?"ready":"notready"}>{enabled?(providerReady?"READY":"PROVIDER SETUP REQUIRED"):"DISABLED"}</span></header><div className="digest-admin-grid"><div className="digest-config"><label className="news-feature-toggle"><input type="checkbox" checked={enabled} onChange={event=>setEnabled(event.target.checked)}/><span><b>Enable weekly delivery</b><small>Only players who explicitly opted in and have a verified login email are eligible.</small></span></label><label>News window<input type="number" min="1" max="30" value={days} onChange={event=>setDays(Number(event.target.value))}/><small>Published articles from the previous 1–30 days.</small></label><label>Maximum articles<input type="number" min="1" max="12" value={max} onChange={event=>setMax(Number(event.target.value))}/></label><label>Subject prefix<input maxLength={80} value={subject} onChange={event=>setSubject(event.target.value)}/></label><button className="primary" disabled={busy||!subject.trim()} onClick={()=>void save()}>{busy?"Saving…":"Save Digest Settings"}</button><p className="digest-schedule"><b>Schedule:</b> Sunday morning ET<br/><b>Subscribers:</b> {data?.subscriber_count??0}<br/><b>Privacy:</b> No open or click tracking.</p></div><div className="digest-preview"><p className="eyebrow">NEXT DIGEST PREVIEW</p><h3>{subject||"Legacy Equine Weekly"}</h3>{data?.preview_posts.map(post=><article key={post.id}><span>{categories[post.category]??post.category}</span><b>{post.title}</b><small>{post.summary}</small></article>)}{!data?.preview_posts.length&&<p>No eligible published News is currently available.</p>}</div><div className="digest-runs"><p className="eyebrow">DELIVERY HISTORY</p>{data?.recent_runs.map(run=><article key={run.week_key}><b>{new Date(`${run.week_key}T12:00:00Z`).toLocaleDateString()}</b><span>{run.status}</span><small>{run.sent_count} sent · {run.failed_count} failed · {run.eligible_count} eligible{run.skip_reason?` · ${run.skip_reason}`:""}</small></article>)}{!data?.recent_runs.length&&<p>No weekly digest has run yet.</p>}</div></div></section>
}

function PublicPreview({ form, date, live }: { form: NewsForm; date: Date; live: boolean }) {
  return <section className="news-public-preview">
    <div className="preview-label"><span>PUBLIC PREVIEW</span><b>{live ? "LIVE" : "PREVIEW — NOT LIVE"}</b></div>
    <article className="newscard">
      {form.image_url && <img src={form.image_url} alt="" />}
      <div>
        <p className="eyebrow">{categories[form.category]} • {date.toLocaleDateString()}</p>
        <h3>{form.title || "Untitled article"}</h3>
        <p>{form.summary || form.body || "Your article preview will appear here."}</p>
        {form.body && form.summary && <p className="news-preview-body">{form.body}</p>}
        {form.destination_url && <span className="news-preview-cta">VIEW DETAILS →</span>}
      </div>
    </article>
  </section>;
}
