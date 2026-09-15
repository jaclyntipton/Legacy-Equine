-- Finish the remaining mare first; its paired stallion portrait can retry on
-- the normal lease after the player-visible sex correction is complete.
update public.store_horse_image_jobs j set status='pending',next_attempt_at=now(),last_error=null
from public.horses h join public.store_inventory si on si.horse_id=h.id and si.status='active'
where h.id=j.horse_id and h.breed='Tennessee Walking Horse' and h.sex='Mare' and not (h.image_url like '%-v7.%');

update public.store_horse_image_jobs j set status='pending',next_attempt_at=now()+interval '10 minutes'
from public.horses h join public.store_inventory si on si.horse_id=h.id and si.status='active'
where h.id=j.horse_id and h.breed='Thoroughbred' and h.sex='Stallion' and not (h.image_url like '%-v7.%');
