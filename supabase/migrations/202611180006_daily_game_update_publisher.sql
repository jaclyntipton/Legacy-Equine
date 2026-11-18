-- Daily Legacy Equine update publisher: confirmed player-facing changes deployed
-- after the Nov. 18, 2026 Game Update Roundup.
insert into public.news_posts(
  title,
  summary,
  body,
  category,
  author_source,
  pinned,
  status,
  publish_at,
  published_at,
  source_type,
  source_key
)
values(
  'Legacy Equine™ — Barns, Reactions & Weekly News',
  'Organize horses in a private General Barn, move groups at once, react in Community chat, and opt in to the weekly News digest.',
  $news$A new set of Stable and Community improvements is now live.

PRIVATE GENERAL BARN

My Stable now includes a Training Barn and a General Barn. Horses in your Training Barn appear on your Public Stable. The General Barn is private holding for horses outside your active group, while those horses remain available for breeding, Shows, care, and other gameplay.

BULK HORSE MOVES

Organizing a larger herd is faster. Select individual horses or use Select All Shown after applying filters, then move the selected group between your Training Barn and General Barn in one action.

COMMUNITY CHAT REACTIONS

Community chat messages now support Like, Love, Laugh, Celebrate, and Horse reactions. Reaction counts update in chat, and selecting the same reaction again removes it.

OPTIONAL WEEKLY NEWS DIGEST

You can now opt in to a weekly email roundup of major game updates, special Shows, contests, and meaningful community news. The digest is optional, separate from essential account and security emails, and can be enabled or disabled anytime in My Profile → Settings.

HELP & SUPPORT

If you encounter a bug or unexpected behavior, please use Help & Support → Report a Bug. Tell us what you were trying to do, what happened instead, and include a screenshot when helpful.

Legacy Equine™ — Breed Your Legacy.$news$,
  'updates',
  'Legacy Equine',
  false,
  'published',
  now(),
  now(),
  'system',
  'daily-update-publisher-2026-11-18-post-roundup'
)
on conflict(source_type,source_key) do update set
  title=excluded.title,
  summary=excluded.summary,
  body=excluded.body,
  category=excluded.category,
  author_source=excluded.author_source,
  pinned=false,
  status='published',
  publish_at=coalesce(public.news_posts.publish_at,excluded.publish_at),
  published_at=coalesce(public.news_posts.published_at,excluded.published_at),
  updated_at=now();
