-- Make image claims self-healing when a serverless invocation ends between
-- claiming and completing a job. The five-minute lease prevents double work.
create or replace function public.claim_store_horse_image_job()
returns table(job_id uuid,horse_id uuid,visual_phenotype jsonb,markings jsonb) language plpgsql security definer set search_path=public as $$
declare chosen uuid;begin
 if auth.role()<>'service_role' then raise exception 'Service role required';end if;
 select j.id into chosen
 from store_horse_image_jobs j
 join horses h on h.id=j.horse_id
 left join store_inventory si on si.horse_id=j.horse_id and si.status='active'
 where ((j.status='pending' and j.next_attempt_at<=now()) or (j.status='processing' and j.next_attempt_at<=now()))
 and (h.owner_id is not null or si.id is not null)
 order by case when j.status='processing' then 0 else 1 end,case when h.owner_id is not null then 0 else 1 end,j.created_at
 for update of j skip locked limit 1;
 if chosen is null then return;end if;
 update store_horse_image_jobs set status='processing',attempts=attempts+1,next_attempt_at=now()+interval '5 minutes' where id=chosen;
 update horses set image_generation_status='processing' where id=(select j.horse_id from store_horse_image_jobs j where j.id=chosen);
 return query select j.id,h.id,h.visual_phenotype,h.markings from store_horse_image_jobs j join horses h on h.id=j.horse_id where j.id=chosen;
end $$;

update public.store_horse_image_jobs j set status='pending',next_attempt_at=now()
from public.horses h
where h.id=j.horse_id and j.status='processing' and h.image_prompt_version='horse-v7'
and not (h.image_url like '%-v7.%');

revoke all on function public.claim_store_horse_image_job() from public;
grant execute on function public.claim_store_horse_image_job() to service_role;
