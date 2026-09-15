-- Paid Gateway credits are active; release provider-rate-limited artwork immediately.
update public.store_horse_image_jobs
set status='pending',attempts=0,next_attempt_at=now(),last_error=null
where status in ('pending','failed') and last_error ilike '%Free tier%';

update public.horses h set image_generation_status='pending'
from public.store_horse_image_jobs j
where j.horse_id=h.id and j.status='pending' and h.image_url='/foundation-horse.png';
