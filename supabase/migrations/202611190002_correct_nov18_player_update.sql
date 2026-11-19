-- Correct the Nov. 18 player update: secondary barn organization is an
-- Owner Account #1 capability and must not be presented as a player launch.
do $$
declare updated_posts integer;
begin
 update public.news_posts
 set title='Legacy Equine™ — Reactions & Weekly News',
    summary='React to messages in Community chat and opt in to the optional weekly News digest.',
    body=$news$Two new Community and News features are now live.

COMMUNITY CHAT REACTIONS

Community chat messages now support Like, Love, Laugh, Celebrate, and Horse reactions. Reaction counts update in chat, and selecting the same reaction again removes it.

OPTIONAL WEEKLY NEWS DIGEST

You can now opt in to a weekly email roundup of major game updates, special Shows, contests, and meaningful community news. The digest is optional, separate from essential account and security emails, and can be enabled or disabled anytime in My Profile → Settings.

HELP & SUPPORT

If you encounter a bug or unexpected behavior, please use Help & Support → Report a Bug. Tell us what you were trying to do, what happened instead, and include a screenshot when helpful.

Legacy Equine™ — Breed Your Legacy.$news$,
     updated_at=now()
 where source_type='system'
   and source_key='daily-update-publisher-2026-11-18-post-roundup';
 get diagnostics updated_posts=row_count;
 if updated_posts<>1 then
   raise exception 'Expected one Nov. 18 News article, updated %',updated_posts;
 end if;
end$$;

do $$
declare
  target_message uuid;
  matching_messages integer;
begin
  select count(*)
  into matching_messages
  from public.chat_messages m
  join public.stables s on s.id=m.author_id
  where s.account_number=2
    and m.content like '🐴 LEGACY EQUINE™ — BARNS, REACTIONS & WEEKLY NEWS%';

  if matching_messages<>1 then
    raise exception 'Expected one Nov. 18 Community update, found %',matching_messages;
  end if;

  select m.id
  into target_message
  from public.chat_messages m
  join public.stables s on s.id=m.author_id
  where s.account_number=2
    and m.content like '🐴 LEGACY EQUINE™ — BARNS, REACTIONS & WEEKLY NEWS%';

  update public.chat_messages
  set content=$message$🐴 LEGACY EQUINE™ — REACTIONS & WEEKLY NEWS

💬 Chat reactions: React to Community messages with 👍 ❤️ 😂 🎉 or 🐴. Select the same reaction again to remove it.

📰 Weekly Digest: Opt in to an optional weekly roundup of major game updates, special Shows, contests, and community news. Manage it anytime in My Profile → Settings; it is separate from essential account and security emails.

Read the full details in News & Updates.
Legacy Equine™ — Breed Your Legacy.$message$,
      edited_at=now()
  where id=target_message;

  insert into public.community_audit_log(actor_id,action,target_type,target_id,reason,details)
  select s.id,'message_edited','chat_message',target_message,
         'Corrected player update to remove an Owner Account #1-only feature',
         jsonb_build_object('source','daily-legacy-equine-update-publisher')
  from public.stables s
  where s.account_number=2;
end$$;
