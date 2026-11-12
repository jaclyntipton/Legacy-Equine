-- Accelerate horse aging prospectively while preserving every existing horse's
-- precise game age at the instant this migration is applied.
do $$
declare
  anchor timestamptz := clock_timestamp();
  old_days numeric;
begin
  select real_days_per_horse_year into old_days
  from public.horse_game_config
  where id=true
  for update;

  if old_days is null then
    raise exception 'Horse aging configuration is unavailable';
  end if;

  if old_days <> 14 then
    update public.horses h
    set birth_date=anchor-make_interval(
      secs => (greatest(0,extract(epoch from(anchor-h.birth_date))/86400/old_days)*14*86400)::double precision
    );

    update public.horse_game_config
    set real_days_per_horse_year=14
    where id=true;
  end if;
end
$$;

-- Keep the live Player Handbook aligned with the authoritative rate.
update public.handbook_articles
set body=E'# Horses\n\nEach horse has one authoritative profile containing ownership, pedigree, permanent stats, Effective Stats, Show records, and development history. Ownership transfers move the horse and its horse-specific records together.\n\n## Continuous aging\n\nOne horse-year passes every 14 real days. Age is calculated continuously from the horse''s authoritative age-origin timestamp rather than from a rounded display age. Existing horses kept their exact game age when this faster rate began; only future aging accelerated. Training and breeding begin at exact age 2. Breeding ends at exact age 26, while training may continue.',
    summary='Read a horse profile and understand ownership, permanent records, and the 14-day horse year.',
    keywords=array['horse','profile','ownership','pedigree','age','aging','14 days'],
    updated_at=now()
where slug='horses';

-- Publish a player-facing announcement without displacing an existing pinned
-- operational notice.
insert into public.news_posts(
  title,summary,body,category,author_source,destination_url,pinned,status,
  publish_at,published_at,source_type,source_key
)
values(
  'Horse Aging Updated: 14-Day Horse Years',
  'Legacy Equine horses now age one game year every 14 real days.',
  'Horse age progression has been accelerated for testing. One horse-year now passes every 14 real days. Existing horses retained their exact game age when the change took effect, so no horse suddenly became older or crossed an eligibility boundary because of the update itself. From this point forward, ages will advance at the new rate. Training still begins at exact age 2. Breeding remains available from exact age 2 until age 26, and horses age 26 or older may continue training.',
  'updates','Legacy Equine','/how-to-play/horses',false,'published',
  now(),now(),'system','horse-aging-14-day-year-2026'
)
on conflict(source_type,source_key)do update set
  title=excluded.title,
  summary=excluded.summary,
  body=excluded.body,
  category=excluded.category,
  author_source=excluded.author_source,
  destination_url=excluded.destination_url,
  status='published',
  publish_at=coalesce(public.news_posts.publish_at,now()),
  published_at=coalesce(public.news_posts.published_at,now()),
  updated_at=now();
