create or replace function public.update_stable_profile(new_name text,new_username text,new_bio text)
returns public.stables language plpgsql security definer set search_path=public as $$
declare result stables; normalized_username text:=nullif(trim(coalesce(new_username,'')),'');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if length(trim(new_name)) not between 2 and 60 then raise exception 'Stable name must be 2–60 characters'; end if;
  if normalized_username is not null and normalized_username !~ '^[A-Za-z0-9_]{3,24}$' then raise exception 'Username must be 3–24 letters, numbers, or underscores'; end if;
  update stables set name=trim(new_name),username=normalized_username,bio=left(trim(coalesce(new_bio,'')),500) where id=auth.uid() returning * into result;
  if not found then raise exception 'Stable not found'; end if; return result;
exception when unique_violation then raise exception 'That username is already taken';
end $$;
