do $$
declare article record; run record;
begin
 for article in
  select id,title,created_at,publish_at,published_at,status,pinned,expires_at,
   (expires_at is not null and expires_at<=now()) expired
  from public.news_posts
  where created_at>='2026-09-21 00:00:00+00'::timestamptz
  order by created_at
 loop
  raise notice 'NEWS_AUDIT|%|%|created=%|publish=%|published=%|status=%|pinned=%|expires=%|expired=%',
   article.id,article.title,article.created_at,article.publish_at,article.published_at,
   article.status,article.pinned,article.expires_at,article.expired;
 end loop;
 for run in select * from public.news_publish_runs order by started_at desc limit 10 loop
  raise notice 'NEWS_RUN|started=%|completed=%|due=%|published=%|ids=%|result=%',
   run.started_at,run.completed_at,run.due_count,run.published_count,run.article_ids,run.result;
 end loop;
end$$;
