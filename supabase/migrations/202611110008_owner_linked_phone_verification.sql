-- Private linked-owner verification group. No phone number is duplicated or exposed.
create table if not exists public.account_phone_verification_group_members(
 group_id uuid not null,
 account_id uuid primary key references public.stables(id)on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.account_phone_verification_group_members enable row level security;
alter table public.account_phone_verification_group_members force row level security;
revoke all on public.account_phone_verification_group_members from public,anon,authenticated;

insert into public.account_phone_verification_group_members(group_id,account_id)
select'00000000-0000-4000-8000-000000000012'::uuid,id from public.stables where account_number in(1,2)
on conflict(account_id)do update set group_id=excluded.group_id;

create or replace function public.get_my_phone_verification_status()returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object(
  'verified',coalesce(me.phone_verified_at is not null,false)or exists(
   select 1 from account_phone_verification_group_members mine
   join account_phone_verification_group_members sibling on sibling.group_id=mine.group_id
   join stables linked on linked.id=sibling.account_id
   where mine.account_id=auth.uid()and linked.phone_verified_at is not null
  ),
  'verified_at',coalesce(me.phone_verified_at,(
   select max(linked.phone_verified_at)from account_phone_verification_group_members mine
   join account_phone_verification_group_members sibling on sibling.group_id=mine.group_id
   join stables linked on linked.id=sibling.account_id
   where mine.account_id=auth.uid()
  ))
 )from stables me where me.id=auth.uid()
$$;
revoke all on function public.get_my_phone_verification_status()from public;
grant execute on function public.get_my_phone_verification_status()to authenticated;
comment on table public.account_phone_verification_group_members is 'Private, explicitly approved accounts that inherit verified-phone status from one another without duplicating or exposing the phone number.';
