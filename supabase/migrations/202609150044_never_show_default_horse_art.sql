-- The Foundation reference image is never an individual horse portrait.
-- Prioritize every visible horse that still needs unique artwork.
update public.store_horse_image_jobs j
set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null
from public.horses h
where h.id=j.horse_id
and (coalesce(h.image_url,'') in ('','/foundation-horse.png') or h.image_generation_status='failed')
and (h.owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=h.id and si.status='active'));

insert into public.store_horse_image_jobs(horse_id,status,attempts,next_attempt_at)
select h.id,'pending',0,now()
from public.horses h
where coalesce(h.image_url,'') in ('','/foundation-horse.png')
and (h.owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=h.id and si.status='active'))
on conflict(horse_id) do update set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null;

update public.horses h set image_generation_status='pending',image_prompt_version='horse-v13-qa'
where coalesce(h.image_url,'') in ('','/foundation-horse.png')
and (h.owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=h.id and si.status='active'));

drop function if exists public.claim_store_horse_image_job();
create function public.claim_store_horse_image_job()
returns table(job_id uuid,horse_id uuid,visual_phenotype jsonb,markings jsonb,image_url text)
language plpgsql security definer set search_path=public as $$
declare chosen uuid;
begin
  if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
  update store_horse_image_jobs set status='pending',next_attempt_at=now()
  where status='processing' and completed_at is null and next_attempt_at<now()-interval '10 minutes';
  select j.id into chosen
  from store_horse_image_jobs j
  join horses h on h.id=j.horse_id
  left join store_inventory si on si.horse_id=j.horse_id and si.status='active'
  where j.status='pending' and j.next_attempt_at<=now() and (h.owner_id is not null or si.id is not null)
  order by
    (h.owner_id is not null and coalesce(h.image_url,'') in ('','/foundation-horse.png')) desc,
    (coalesce(h.image_url,'') in ('','/foundation-horse.png')) desc,
    (si.id is not null) desc,
    j.created_at
  for update of j skip locked limit 1;
  if chosen is null then return; end if;
  update store_horse_image_jobs set status='processing',attempts=attempts+1,next_attempt_at=now() where id=chosen;
  update horses set image_generation_status='processing' where id=(select j.horse_id from store_horse_image_jobs j where j.id=chosen);
  return query select j.id,h.id,h.visual_phenotype,h.markings,h.image_url
  from store_horse_image_jobs j join horses h on h.id=j.horse_id where j.id=chosen;
end $$;

revoke all on function public.claim_store_horse_image_job() from public;
grant execute on function public.claim_store_horse_image_job() to service_role;
