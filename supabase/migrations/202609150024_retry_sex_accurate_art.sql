update public.horses h set image_generation_status='pending',image_prompt_version='horse-v7'
where (h.owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=h.id and si.status='active'))
and (coalesce(h.image_url,'') in ('','/foundation-horse.png') or h.image_url like '%/generated/store/%' or h.image_url like '%/generated/horses/%');

insert into public.store_horse_image_jobs(horse_id,status,attempts,next_attempt_at,last_error,completed_at)
select h.id,'pending',0,now(),null,null from public.horses h
where (h.owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=h.id and si.status='active'))
and (coalesce(h.image_url,'') in ('','/foundation-horse.png') or h.image_url like '%/generated/store/%' or h.image_url like '%/generated/horses/%')
on conflict(horse_id) do update set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null;
