-- Consent-first weekly News email digest. Auth email remains in Supabase Auth;
-- public gameplay tables store preference and delivery state only.
create table if not exists public.news_email_preferences(
  stable_id uuid primary key references public.stables(id) on delete cascade,
  subscribed boolean not null default false,
  consented_at timestamptz,
  unsubscribed_at timestamptz,
  updated_at timestamptz not null default now(),
  check(not subscribed or consented_at is not null)
);

create table if not exists public.news_digest_config(
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false,
  window_days integer not null default 7 check(window_days between 1 and 30),
  max_articles integer not null default 8 check(max_articles between 1 and 12),
  subject_prefix text not null default 'Legacy Equine Weekly',
  updated_at timestamptz not null default now(),
  updated_by uuid references public.stables(id)
);
insert into public.news_digest_config(singleton) values(true) on conflict(singleton) do nothing;

create table if not exists public.news_digest_runs(
  id uuid primary key default gen_random_uuid(),
  week_key date not null unique,
  status text not null default 'processing' check(status in('processing','complete','partial','skipped','failed')),
  article_ids uuid[] not null default '{}',
  eligible_count integer not null default 0,
  sent_count integer not null default 0,
  failed_count integer not null default 0,
  skip_reason text,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.news_digest_deliveries(
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.news_digest_runs(id) on delete cascade,
  stable_id uuid not null references public.stables(id) on delete cascade,
  status text not null default 'processing' check(status in('processing','sent','failed','skipped')),
  provider text not null default 'resend',
  provider_message_id text,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(run_id,stable_id)
);

alter table public.news_email_preferences enable row level security;
alter table public.news_digest_config enable row level security;
alter table public.news_digest_runs enable row level security;
alter table public.news_digest_deliveries enable row level security;
revoke all on table public.news_email_preferences,public.news_digest_config,public.news_digest_runs,public.news_digest_deliveries from public,anon,authenticated;
grant select,insert,update on table public.news_email_preferences,public.news_digest_config,public.news_digest_runs,public.news_digest_deliveries to service_role;

create or replace function public.get_news_email_preference() returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare pref news_email_preferences;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 select * into pref from news_email_preferences where stable_id=auth.uid();
 return jsonb_build_object(
  'subscribed',coalesce(pref.subscribed,false),
  'consented_at',pref.consented_at,
  'unsubscribed_at',pref.unsubscribed_at,
  'frequency','weekly'
 );
end$$;

create or replace function public.save_news_email_preference(p_subscribed boolean) returns jsonb
language plpgsql security definer set search_path=public as $$
declare pref news_email_preferences;
begin
 if auth.uid() is null or not exists(select 1 from stables where id=auth.uid())then raise exception 'Authentication required';end if;
 insert into news_email_preferences(stable_id,subscribed,consented_at,unsubscribed_at,updated_at)
 values(auth.uid(),p_subscribed,case when p_subscribed then now()end,case when not p_subscribed then now()end,now())
 on conflict(stable_id)do update set
  subscribed=excluded.subscribed,
  consented_at=case when excluded.subscribed then coalesce(news_email_preferences.consented_at,now())else news_email_preferences.consented_at end,
  unsubscribed_at=case when excluded.subscribed then null else now()end,
  updated_at=now()
 returning * into pref;
 return jsonb_build_object('subscribed',pref.subscribed,'consented_at',pref.consented_at,'unsubscribed_at',pref.unsubscribed_at,'frequency','weekly');
end$$;

create or replace function public.admin_get_news_digest() returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare cfg news_digest_config;
begin
 if not can_manage_news()then raise exception 'News management permission required';end if;
 select * into cfg from news_digest_config where singleton;
 return jsonb_build_object(
  'config',to_jsonb(cfg),
  'subscriber_count',(select count(*) from news_email_preferences where subscribed),
  'preview_posts',coalesce((select jsonb_agg(to_jsonb(x))from(
    select id,title,summary,category,destination_url,coalesce(published_at,publish_at,created_at)published_at
    from news_posts where status='published'
      and coalesce(publish_at,published_at,created_at)<=now()
      and coalesce(published_at,publish_at,created_at)>=now()-make_interval(days=>cfg.window_days)
      and(expires_at is null or expires_at>now())
    order by pinned desc,coalesce(published_at,publish_at,created_at)desc limit cfg.max_articles
  )x),'[]'::jsonb),
  'recent_runs',coalesce((select jsonb_agg(to_jsonb(x))from(
    select week_key,status,eligible_count,sent_count,failed_count,skip_reason,started_at,completed_at
    from news_digest_runs order by started_at desc limit 8
  )x),'[]'::jsonb)
 );
end$$;

create or replace function public.admin_save_news_digest_config(
 p_enabled boolean,p_window_days integer,p_max_articles integer,p_subject_prefix text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare cfg news_digest_config;
begin
 if not can_manage_news()then raise exception 'News management permission required';end if;
 if p_window_days not between 1 and 30 or p_max_articles not between 1 and 12 then raise exception 'Invalid digest limits';end if;
 insert into news_digest_config(singleton,enabled,window_days,max_articles,subject_prefix,updated_at,updated_by)
 values(true,p_enabled,p_window_days,p_max_articles,news_safe_text(p_subject_prefix,80),now(),auth.uid())
 on conflict(singleton)do update set enabled=excluded.enabled,window_days=excluded.window_days,max_articles=excluded.max_articles,subject_prefix=excluded.subject_prefix,updated_at=now(),updated_by=auth.uid()
 returning * into cfg;
 return to_jsonb(cfg);
end$$;

revoke all on function public.get_news_email_preference(),public.save_news_email_preference(boolean),public.admin_get_news_digest(),public.admin_save_news_digest_config(boolean,integer,integer,text) from public,anon;
grant execute on function public.get_news_email_preference(),public.save_news_email_preference(boolean),public.admin_get_news_digest(),public.admin_save_news_digest_config(boolean,integer,integer,text) to authenticated;
