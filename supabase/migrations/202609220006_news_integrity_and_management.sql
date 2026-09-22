alter table public.news_posts drop constraint if exists news_posts_status_check;
alter table public.news_posts add constraint news_posts_status_check
 check(status in('draft','scheduled','published','unpublished','archived'));

-- Keep the newest eligible pin as the single primary story. Older pinned stories
-- remain published and continue to appear chronologically in Latest News.
with ranked as(
 select id,row_number()over(order by coalesce(published_at,publish_at,created_at)desc,id desc)as position
 from public.news_posts where pinned and status='published'
)
update public.news_posts n set pinned=false,updated_at=now()
from ranked r where n.id=r.id and r.position>1;

update public.news_posts set pinned=false,updated_at=now()
where pinned and status<>'published';

create unique index if not exists news_one_primary_pin_idx
 on public.news_posts((pinned)) where pinned and status='published';

create or replace function public.admin_save_news(p_id uuid,p_title text,p_summary text,p_body text,p_category text,p_image_url text,p_destination text,p_pinned boolean,p_status text,p_publish_at timestamptz,p_expires_at timestamptz)returns uuid
language plpgsql security definer set search_path=public as $$
declare target uuid:=coalesce(p_id,gen_random_uuid()); effective_pin boolean:=coalesce(p_pinned,false)and p_status='published';
begin
 if not can_manage_news()then raise exception'News management permission required';end if;
 if p_category not in('official','updates','shows','contests','community')or p_status not in('draft','scheduled','published','unpublished')then raise exception'Invalid News category or status';end if;
 if p_status='scheduled'and(p_publish_at is null or p_publish_at<=now())then raise exception'Scheduled publication must be in the future';end if;
 if effective_pin then update news_posts set pinned=false,updated_at=now()where pinned and id<>target;end if;
 insert into news_posts(id,title,summary,body,category,author_id,author_source,image_url,destination_url,pinned,status,publish_at,expires_at,published_at)
 values(target,news_safe_text(p_title,140),news_safe_text(p_summary,300),news_safe_text(p_body,10000),p_category,auth.uid(),'Legacy Equine',nullif(p_image_url,''),news_safe_destination(p_destination),effective_pin,p_status,coalesce(p_publish_at,case when p_status='published'then now()end),p_expires_at,case when p_status='published'then now()end)
 on conflict(id)do update set title=excluded.title,summary=excluded.summary,body=excluded.body,category=excluded.category,image_url=excluded.image_url,destination_url=excluded.destination_url,pinned=excluded.pinned,status=excluded.status,publish_at=excluded.publish_at,expires_at=excluded.expires_at,published_at=case when excluded.status='published'then coalesce(news_posts.published_at,now())when excluded.status='scheduled'then null else news_posts.published_at end,updated_at=now();
 return target;
end$$;

create or replace function public.admin_news_quick_action(p_id uuid,p_action text)returns jsonb
language plpgsql security definer set search_path=public as $$
declare article news_posts%rowtype;
begin
 if not can_manage_news()then raise exception'News management permission required';end if;
 if p_action not in('pin','unpin','publish','unpublish','archive')then raise exception'Invalid News action';end if;
 select * into article from news_posts where id=p_id for update;
 if not found then raise exception'News article not found';end if;
 if p_action='pin' then
  if article.status<>'published'then raise exception'Only published News can be pinned';end if;
  update news_posts set pinned=false,updated_at=now()where pinned and id<>p_id;
  update news_posts set pinned=true,updated_at=now()where id=p_id;
 elsif p_action='unpin'then update news_posts set pinned=false,updated_at=now()where id=p_id;
 elsif p_action='publish'then
  update news_posts set status='published',pinned=false,publish_at=now(),published_at=coalesce(published_at,now()),updated_at=now()where id=p_id;
 elsif p_action='unpublish'then update news_posts set status='unpublished',pinned=false,updated_at=now()where id=p_id;
 else update news_posts set status='archived',pinned=false,updated_at=now()where id=p_id;
 end if;
 return(select jsonb_build_object('id',n.id,'status',n.status,'pinned',n.pinned)from news_posts n where n.id=p_id);
end$$;

create or replace function public.get_home_news(p_category text default null,p_offset integer default 0,p_limit integer default 20)returns jsonb
language plpgsql security definer set search_path=public as $$
declare viewed timestamptz;
begin
 select last_viewed_at into viewed from news_reader_state where stable_id=auth.uid();
 return jsonb_build_object(
  'last_viewed_at',viewed,
  'published_count',(select count(*)from news_posts n where n.status='published'and(p_category is null or n.category=p_category)),
  'eligible_count',(select count(*)from news_posts n where n.status='published'and coalesce(n.publish_at,n.published_at,n.created_at)<=now()and(n.expires_at is null or n.expires_at>now())and(p_category is null or n.category=p_category)),
  'new_count',(select count(*)from news_posts n where n.status='published'and coalesce(n.publish_at,n.published_at,n.created_at)<=now()and(n.expires_at is null or n.expires_at>now())and coalesce(n.published_at,n.publish_at,n.created_at)>coalesce(viewed,'epoch')),
  'primary_pinned',(select to_jsonb(x)from(
   select id,title,summary,body,category,author_source,image_url,destination_url,pinned,source_type,coalesce(publish_at,published_at,created_at)published_at
   from news_posts n where n.status='published'and n.pinned and coalesce(n.publish_at,n.published_at,n.created_at)<=now()and(n.expires_at is null or n.expires_at>now())
   order by coalesce(n.publish_at,n.published_at,n.created_at)desc limit 1
  )x),
  'posts',coalesce((select jsonb_agg(to_jsonb(x))from(
   select id,title,summary,body,category,author_source,image_url,destination_url,pinned,source_type,coalesce(publish_at,published_at,created_at)published_at
   from news_posts n
   where n.status='published'and coalesce(n.publish_at,n.published_at,n.created_at)<=now()and(n.expires_at is null or n.expires_at>now())and(p_category is null or n.category=p_category)
   order by coalesce(n.publish_at,n.published_at,n.created_at)desc,n.id desc
   offset greatest(p_offset,0)limit least(greatest(p_limit,1),50)
  )x),'[]'::jsonb)
 );
end$$;

revoke all on function public.admin_news_quick_action(uuid,text)from public,anon;
grant execute on function public.admin_news_quick_action(uuid,text)to authenticated;
revoke all on function public.get_home_news(text,integer,integer)from public;
grant execute on function public.get_home_news(text,integer,integer)to authenticated;
