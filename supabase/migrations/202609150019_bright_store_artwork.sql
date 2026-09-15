update public.horses h
set visual_phenotype=jsonb_set(jsonb_set(h.visual_phenotype,'{background}','"bright warm ivory seamless studio, softly blending into the Legacy Equine cream page, never gray or charcoal"'::jsonb,true),'{lighting}','"high-key soft daylight with crisp coat detail, clean highlights, natural contrast and no gray haze"'::jsonb,true),image_generation_status='pending',image_prompt_version='store-horse-v3'
from public.store_inventory si where si.horse_id=h.id and si.status='active';

insert into public.store_horse_image_jobs(horse_id,status,attempts,next_attempt_at,last_error,completed_at)
select h.id,'pending',0,now(),null,null from public.horses h join public.store_inventory si on si.horse_id=h.id where si.status='active'
on conflict(horse_id) do update set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null;
