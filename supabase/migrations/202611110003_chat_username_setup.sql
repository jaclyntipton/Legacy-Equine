create or replace function public.set_my_community_username(new_username text)
returns text
language plpgsql
security definer
set search_path=public
as $$
declare normalized text:=trim(coalesce(new_username,''));
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if normalized !~ '^[A-Za-z0-9_]{3,24}$' then
  raise exception 'Username must be 3–24 letters, numbers, or underscores';
 end if;
 update public.stables set username=normalized where id=auth.uid();
 if not found then raise exception 'Player account not found'; end if;
 return normalized;
exception when unique_violation then
 raise exception 'That username is already taken';
end$$;

revoke all on function public.set_my_community_username(text) from public,anon;
grant execute on function public.set_my_community_username(text) to authenticated;
