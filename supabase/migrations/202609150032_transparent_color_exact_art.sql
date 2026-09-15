-- Requeue generated horse portraits for the transparent, color-exact v10 art direction.
update public.horses set
 image_generation_status='pending',image_prompt_version='horse-v10',
 visual_phenotype=jsonb_set(jsonb_set(visual_phenotype,'{background}',to_jsonb('transparent empty background'::text),true),'{lighting}',to_jsonb('neutral color-accurate lighting with no color cast'::text),true)
where owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=horses.id and si.status='active');
insert into public.store_horse_image_jobs(horse_id,status,attempts,next_attempt_at,last_error,completed_at)
select id,'pending',0,now(),null,null from public.horses where owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=horses.id and si.status='active')
on conflict(horse_id) do update set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null;
