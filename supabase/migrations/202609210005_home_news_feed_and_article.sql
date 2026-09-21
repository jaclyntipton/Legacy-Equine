-- Keep Home diagnostics and article views on the authoritative News source.
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
  'posts',coalesce((select jsonb_agg(to_jsonb(x))from(
   select id,title,summary,body,category,author_source,image_url,destination_url,pinned,source_type,coalesce(publish_at,published_at,created_at)published_at
   from news_posts n
   where n.status='published'and coalesce(n.publish_at,n.published_at,n.created_at)<=now()and(n.expires_at is null or n.expires_at>now())and(p_category is null or n.category=p_category)
   order by n.pinned desc,coalesce(n.publish_at,n.published_at,n.created_at)desc
   offset greatest(p_offset,0)limit least(greatest(p_limit,1),50)
  )x),'[]'::jsonb)
 );
end$$;

create or replace function public.get_news_article(p_id uuid)returns jsonb
language sql stable security definer set search_path=public as $$
 select to_jsonb(x)from(
  select id,title,summary,body,category,author_source,image_url,destination_url,pinned,source_type,coalesce(publish_at,published_at,created_at)published_at
  from news_posts n
  where n.id=p_id and n.status='published'and coalesce(n.publish_at,n.published_at,n.created_at)<=now()and(n.expires_at is null or n.expires_at>now())
 )x
$$;

revoke all on function public.get_home_news(text,integer,integer),public.get_news_article(uuid)from public;
grant execute on function public.get_home_news(text,integer,integer),public.get_news_article(uuid)to authenticated;
