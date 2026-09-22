alter table public.news_posts drop constraint if exists news_posts_status_check;
alter table public.news_posts add constraint news_posts_status_check check(status in('draft','scheduled','published','unpublished'));

create table if not exists public.news_publish_runs(
 id uuid primary key default gen_random_uuid(),
 started_at timestamptz not null default now(),
 completed_at timestamptz not null default now(),
 due_count integer not null default 0,
 published_count integer not null default 0,
 article_ids uuid[] not null default '{}',
 result text not null default 'success'
);
alter table public.news_publish_runs enable row level security;

create or replace function public.process_due_news() returns jsonb
language plpgsql security definer set search_path=public as $$
declare due_ids uuid[]; published_rows integer:=0; started timestamptz:=clock_timestamp();
begin
 select coalesce(array_agg(n.id order by n.publish_at),'{}') into due_ids
 from news_posts n
 where n.publish_at<=now()
   and(n.expires_at is null or n.expires_at>now())
   and(n.status='scheduled' or(n.status='published' and n.published_at is not null and n.published_at<n.publish_at));

 update news_posts n set status='published',published_at=now(),updated_at=now()
 where n.id=any(due_ids) and(n.status='scheduled' or n.published_at<n.publish_at);
 get diagnostics published_rows=row_count;

 insert into news_publish_runs(started_at,completed_at,due_count,published_count,article_ids)
 values(started,clock_timestamp(),coalesce(cardinality(due_ids),0),published_rows,due_ids);
 return jsonb_build_object('due_count',coalesce(cardinality(due_ids),0),'published_count',published_rows,'article_ids',to_jsonb(due_ids));
end$$;

create or replace function public.admin_save_news(p_id uuid,p_title text,p_summary text,p_body text,p_category text,p_image_url text,p_destination text,p_pinned boolean,p_status text,p_publish_at timestamptz,p_expires_at timestamptz)returns uuid
language plpgsql security definer set search_path=public as $$
declare target uuid:=coalesce(p_id,gen_random_uuid());
begin
 if not can_manage_news()then raise exception'News management permission required';end if;
 if p_category not in('official','updates','shows','contests','community')or p_status not in('draft','scheduled','published','unpublished')then raise exception'Invalid News category or status';end if;
 if p_status='scheduled'and(p_publish_at is null or p_publish_at<=now())then raise exception'Scheduled publication must be in the future';end if;
 insert into news_posts(id,title,summary,body,category,author_id,author_source,image_url,destination_url,pinned,status,publish_at,expires_at,published_at)
 values(target,news_safe_text(p_title,140),news_safe_text(p_summary,300),news_safe_text(p_body,10000),p_category,auth.uid(),'Legacy Equine',nullif(p_image_url,''),news_safe_destination(p_destination),p_pinned,p_status,coalesce(p_publish_at,case when p_status='published'then now()end),p_expires_at,case when p_status='published'then now()end)
 on conflict(id)do update set title=excluded.title,summary=excluded.summary,body=excluded.body,category=excluded.category,image_url=excluded.image_url,destination_url=excluded.destination_url,pinned=excluded.pinned,status=excluded.status,publish_at=excluded.publish_at,expires_at=excluded.expires_at,published_at=case when excluded.status='published'then coalesce(news_posts.published_at,now())when excluded.status='scheduled'then null else news_posts.published_at end,updated_at=now();
 return target;
end$$;

revoke all on function public.process_due_news() from public,anon,authenticated;
grant execute on function public.process_due_news() to service_role;
revoke all on table public.news_publish_runs from public,anon,authenticated;
grant select,insert on table public.news_publish_runs to service_role;
