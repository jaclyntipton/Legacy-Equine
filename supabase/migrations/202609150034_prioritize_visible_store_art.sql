-- Recover the currently visible herd first after the v10 full-art requeue.
update public.store_horse_image_jobs j set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null
from public.store_inventory si where si.horse_id=j.horse_id and si.status='active';
update public.horses h set image_generation_status='pending',image_prompt_version='horse-v10'
from public.store_inventory si where si.horse_id=h.id and si.status='active';

create or replace function public.claim_store_horse_image_job()
returns table(job_id uuid,horse_id uuid,visual_phenotype jsonb,markings jsonb) language plpgsql security definer set search_path=public as $$
declare chosen uuid;begin
 if auth.role()<>'service_role' then raise exception 'Service role required';end if;
 update store_horse_image_jobs set status='pending',next_attempt_at=now() where status='processing' and completed_at is null and next_attempt_at<now()-interval '10 minutes';
 select j.id into chosen from store_horse_image_jobs j join horses h on h.id=j.horse_id left join store_inventory si on si.horse_id=j.horse_id and si.status='active'
 where j.status='pending' and j.next_attempt_at<=now() and(si.id is not null or h.owner_id is not null or h.is_admin_custom)
 order by(si.id is not null) desc,j.created_at for update of j skip locked limit 1;
 if chosen is null then return;end if;
 update store_horse_image_jobs set status='processing',attempts=attempts+1,next_attempt_at=now() where id=chosen;
 update horses set image_generation_status='processing' where id=(select j.horse_id from store_horse_image_jobs j where j.id=chosen);
 return query select j.id,h.id,h.visual_phenotype,h.markings from store_horse_image_jobs j join horses h on h.id=j.horse_id where j.id=chosen;end $$;
revoke all on function public.claim_store_horse_image_job() from public;
grant execute on function public.claim_store_horse_image_job() to service_role;
