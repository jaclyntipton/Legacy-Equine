-- Lightweight, server-authoritative reactions for Community chat messages.
create table public.chat_message_reactions(
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  reactor_id uuid not null references public.stables(id) on delete cascade,
  reaction text not null check(reaction in('like','love','laugh','celebrate','horse')),
  created_at timestamptz not null default now(),
  primary key(message_id,reactor_id,reaction)
);

create index chat_message_reactions_room_idx
  on public.chat_message_reactions(room_id,message_id);

alter table public.chat_message_reactions enable row level security;

create policy "eligible players read visible chat reactions"
on public.chat_message_reactions for select to authenticated
using(
  public.account_social_eligible()
  and exists(
    select 1
    from public.chat_messages m
    join public.chat_rooms r on r.id=m.room_id
    where m.id=message_id
      and m.room_id=room_id
      and m.moderation_status='visible'
      and r.archived_at is null
      and (r.read_permission='players' or public.community_staff())
  )
);

create or replace function public.get_chat_message_reactions(target_room uuid)
returns table(
  message_id uuid,
  reaction text,
  reaction_count bigint,
  reacted_by_me boolean
)
language plpgsql
security definer
set search_path=public
stable
as $$
begin
  perform require_social_eligibility();
  if not exists(
    select 1 from chat_rooms r
    where r.id=target_room
      and r.archived_at is null
      and (r.read_permission='players' or community_staff())
  ) then
    raise exception 'Chat room is unavailable';
  end if;

  return query
  select cr.message_id,
         cr.reaction,
         count(*)::bigint,
         bool_or(cr.reactor_id=auth.uid())
  from chat_message_reactions cr
  join chat_messages m on m.id=cr.message_id
  where cr.room_id=target_room
    and m.room_id=target_room
    and m.moderation_status='visible'
  group by cr.message_id,cr.reaction;
end
$$;

create or replace function public.toggle_chat_message_reaction(
  target_message uuid,
  reaction_name text
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  target chat_messages;
  target_room chat_rooms;
begin
  perform require_social_eligibility();
  if reaction_name not in('like','love','laugh','celebrate','horse') then
    raise exception 'Unsupported reaction';
  end if;

  select * into target from chat_messages where id=target_message;
  if not found or target.moderation_status<>'visible' then
    raise exception 'Message is unavailable';
  end if;

  select * into target_room from chat_rooms where id=target.room_id;
  if not found or target_room.archived_at is not null
     or (target_room.read_permission<>'players' and not community_staff()) then
    raise exception 'Chat room is unavailable';
  end if;

  delete from chat_message_reactions
  where message_id=target_message
    and reactor_id=auth.uid()
    and reaction=reaction_name;
  if found then
    return false;
  end if;

  insert into chat_message_reactions(message_id,room_id,reactor_id,reaction)
  values(target_message,target.room_id,auth.uid(),reaction_name)
  on conflict do nothing;
  return true;
end
$$;

revoke all on function public.get_chat_message_reactions(uuid),
  public.toggle_chat_message_reaction(uuid,text) from public;
grant execute on function public.get_chat_message_reactions(uuid),
  public.toggle_chat_message_reaction(uuid,text) to authenticated;

alter publication supabase_realtime add table public.chat_message_reactions;
