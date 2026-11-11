-- Community administration follows the same authoritative Admin flag used by
-- the application shell. Keep the display/community role synchronized while
-- preserving the unique Owner role for Account #1 and moderator-only accounts.
update public.stables
set community_role=case
  when account_number=1 then 'owner'::public.community_role
  else 'admin'::public.community_role
end
where is_admin
  and community_role not in('admin','owner');

create or replace function public.community_staff(required_role text default 'moderator')
returns boolean
language sql
stable
security definer
set search_path=public
as $$
 select exists(
  select 1
  from public.stables s
  where s.id=auth.uid()
    and case required_role
      when 'admin' then s.is_admin or s.account_number=1 or s.community_role in('admin','owner')
      else s.is_admin or s.account_number=1 or s.community_role in('moderator','admin','owner')
    end
 )
$$;

revoke all on function public.community_staff(text) from public,anon,authenticated;

