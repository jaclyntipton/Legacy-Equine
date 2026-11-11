-- Moderators and Admins may moderate messages and suspend chat participation.
-- Only Admins retain room creation/management through manage_chat_room.
alter table public.chat_mutes alter column expires_at drop not null;

do $$
declare definition text;
begin
 select pg_get_functiondef('public.send_chat_message(uuid,text,jsonb)'::regprocedure) into definition;
 if definition not like '%m.expires_at IS NULL%' then
  definition:=replace(definition,'m.expires_at > now()','(m.expires_at is null or m.expires_at > now())');
  definition:=replace(definition,'m.expires_at>now()','(m.expires_at is null or m.expires_at>now())');
  execute definition;
 end if;
end$$;

create or replace function public.mute_chat_user(target_stable uuid,target_room uuid,mute_minutes integer,reason text)
returns uuid language plpgsql security definer set search_path=public as $$
declare result uuid;indefinite boolean:=mute_minutes=0;
begin
 if not community_staff() then raise exception 'Community moderation access required';end if;
 if mute_minutes<0 or mute_minutes>43200 then raise exception 'Choose 0 for indefinite or 1 minute–30 days';end if;
 if length(trim(coalesce(reason,'')))<5 then raise exception 'A moderation reason is required';end if;
 insert into chat_mutes(stable_id,room_id,muted_by,reason,expires_at)
 values(target_stable,target_room,auth.uid(),left(trim(reason),500),case when indefinite then null else now()+make_interval(mins=>mute_minutes)end)
 returning id into result;
 insert into community_audit_log(actor_id,action,target_type,target_id,reason,details)
 values(auth.uid(),case when indefinite then 'user_chat_suspended' else 'user_muted' end,'stable',target_stable,left(trim(reason),500),jsonb_build_object('room_id',target_room,'minutes',case when indefinite then null else mute_minutes end,'indefinite',indefinite));
 return result;
end$$;

create or replace function public.unmute_chat_user(target_stable uuid,target_room uuid,reason text)
returns integer language plpgsql security definer set search_path=public as $$
declare removed integer;
begin
 if not community_staff() then raise exception 'Community moderation access required';end if;
 if length(trim(coalesce(reason,'')))<5 then raise exception 'A moderation reason is required';end if;
 delete from chat_mutes m
 where m.stable_id=target_stable
   and(target_room is null or m.room_id=target_room)
   and(m.expires_at is null or m.expires_at>now());
 get diagnostics removed=row_count;
 insert into community_audit_log(actor_id,action,target_type,target_id,reason,details)
 values(auth.uid(),'user_chat_suspension_lifted','stable',target_stable,left(trim(reason),500),jsonb_build_object('room_id',target_room,'removed',removed));
 return removed;
end$$;

revoke all on function public.mute_chat_user(uuid,uuid,integer,text),public.unmute_chat_user(uuid,uuid,text) from public,anon;
grant execute on function public.mute_chat_user(uuid,uuid,integer,text),public.unmute_chat_user(uuid,uuid,text) to authenticated;
