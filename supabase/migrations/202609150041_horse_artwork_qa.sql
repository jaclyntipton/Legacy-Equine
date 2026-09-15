-- QA history is separate from immutable horse gameplay identity and genetics.
create table public.horse_image_qa_reviews(id uuid primary key default gen_random_uuid(),horse_id uuid not null references public.horses(id),job_id uuid references public.store_horse_image_jobs(id),approved boolean not null,checks jsonb not null,created_at timestamptz not null default now());
alter table public.horse_image_qa_reviews enable row level security;

-- Regenerate every current system image under the no-marks prompt and QA gate.
update public.store_horse_image_jobs j set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null
from public.horses h left join public.store_inventory si on si.horse_id=h.id and si.status='active'
where h.id=j.horse_id and (h.owner_id is not null or si.id is not null) and h.image_url like '%/generated/%';
update public.horses h set image_generation_status='pending',image_prompt_version='horse-v13-qa'
where (h.owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=h.id and si.status='active')) and h.image_url like '%/generated/%';
