update public.store_horse_image_jobs j set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null
from public.horses h join public.store_inventory si on si.horse_id=h.id and si.status='active'
where h.id=j.horse_id and h.breed='Tennessee Walking Horse' and h.sex='Mare' and not (h.image_url like '%-v7.%');
