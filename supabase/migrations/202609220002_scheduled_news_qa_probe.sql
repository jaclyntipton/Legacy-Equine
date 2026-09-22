insert into public.news_posts(
 title,summary,body,category,author_source,pinned,status,publish_at,expires_at,source_type,source_key
) values(
 'Scheduled News Publisher QA — 2026-09-22',
 'Temporary controlled verification of automatic scheduled News publishing.',
 'This temporary QA article verifies that future-dated News transitions through the production scheduler without Owner interaction.',
 'updates','Legacy Equine QA',false,'scheduled',
 date_trunc('minute',now())+interval '6 minutes',
 date_trunc('minute',now())+interval '30 minutes',
 'scheduler_qa','scheduled-news-2026-09-22'
) on conflict(source_type,source_key)do update set
 status='scheduled',publish_at=date_trunc('minute',now())+interval '6 minutes',
 expires_at=date_trunc('minute',now())+interval '30 minutes',published_at=null,updated_at=now();
