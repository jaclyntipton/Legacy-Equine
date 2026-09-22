update public.news_posts
set status = 'unpublished',
    updated_at = now()
where source_type = 'scheduler_qa'
  and source_key = 'scheduled-news-publisher-qa-2026-09-22'
  and title = 'Scheduled News Publisher QA — 2026-09-22';
