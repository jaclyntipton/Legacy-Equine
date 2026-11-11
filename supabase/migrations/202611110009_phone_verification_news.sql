-- Publish the player-facing announcement as the current primary News story.
update public.news_posts set pinned=false,updated_at=now()where pinned and status='published';
insert into public.news_posts(title,summary,body,category,author_source,destination_url,pinned,status,publish_at,published_at,source_type,source_key)
values(
 'Action Required: Verify Your Phone Number',
 'All Legacy Equine player accounts must complete private phone verification to continue gameplay.',
 'Legacy Equine now requires private phone verification to protect player accounts and prevent duplicate registrations. Sign in and follow the verification prompt to receive a one-time SMS code. Your phone number remains private and is never displayed to other players. Accounts that cannot complete verification will be restricted and placed into Administrative Review; no horses, artwork, LED, inventory, records, or history will be automatically deleted or transferred.',
 'official','Legacy Equine','/profile/settings',true,'published',now(),now(),'system','mandatory-phone-verification-2026'
)
on conflict(source_type,source_key)do update set title=excluded.title,summary=excluded.summary,body=excluded.body,category=excluded.category,author_source=excluded.author_source,destination_url=excluded.destination_url,pinned=true,status='published',publish_at=now(),published_at=now(),updated_at=now();
