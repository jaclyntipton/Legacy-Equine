create or replace function public.report_missing_horse_image(target_horse uuid, failed_url text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from horses h where h.id=target_horse and h.owner_id=auth.uid() and h.image_url=failed_url) then return; end if;
  update horses set image_generation_status='failed' where id=target_horse and image_url=failed_url;
end $$;

create or replace function public.admin_regenerate_horse_image(target_horse uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  perform require_admin();
  if not exists(select 1 from horses where id=target_horse) then raise exception 'Horse not found'; end if;
  update horses set image_generation_status='pending',image_prompt_version='horse-v13-qa' where id=target_horse;
  insert into store_horse_image_jobs(horse_id,status,attempts,last_error,next_attempt_at,completed_at)
  values(target_horse,'pending',0,null,now(),null)
  on conflict(horse_id) do update set status='pending',attempts=0,last_error=null,next_attempt_at=now(),completed_at=null;
end $$;

revoke all on function public.report_missing_horse_image(uuid,text),public.admin_regenerate_horse_image(uuid) from public;
grant execute on function public.report_missing_horse_image(uuid,text),public.admin_regenerate_horse_image(uuid) to authenticated;
