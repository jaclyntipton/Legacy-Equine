alter table public.stables add column ranch_image_url text not null default '';
alter table public.stables add column avatar_url text not null default '';

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('legacy-equine-media','legacy-equine-media',true,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=excluded.allowed_mime_types;

create policy "LE media public reading" on storage.objects for select using(bucket_id='legacy-equine-media');
create policy "LE players upload own media" on storage.objects for insert to authenticated with check(bucket_id='legacy-equine-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "LE players update own media" on storage.objects for update to authenticated using(bucket_id='legacy-equine-media' and owner_id=auth.uid()::text) with check(bucket_id='legacy-equine-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "LE players delete own media" on storage.objects for delete to authenticated using(bucket_id='legacy-equine-media' and owner_id=auth.uid()::text);

create or replace function public.update_stable_images(new_ranch_image_url text,new_avatar_url text)
returns public.stables language plpgsql security definer set search_path=public as $$
declare result stables;
begin
  update stables set ranch_image_url=left(coalesce(new_ranch_image_url,''),2048),avatar_url=left(coalesce(new_avatar_url,''),2048) where id=auth.uid() returning * into result;
  if not found then raise exception 'Stable not found'; end if; return result;
end $$;
revoke all on function public.update_stable_images(text,text) from public;
grant execute on function public.update_stable_images(text,text) to authenticated;

drop function public.get_forum_posts();
create function public.get_forum_posts()
returns table(id uuid,parent_id uuid,body text,created_at timestamptz,stable_name text,username text,account_number bigint,avatar_url text)
language sql security definer set search_path=public as $$ select p.id,p.parent_id,p.body,p.created_at,s.name,s.username,s.account_number,s.avatar_url from forum_posts p join stables s on s.id=p.stable_id order by p.created_at desc limit 100 $$;
revoke all on function public.get_forum_posts() from public;
grant execute on function public.get_forum_posts() to authenticated;
