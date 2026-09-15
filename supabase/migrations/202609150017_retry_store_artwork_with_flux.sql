update public.store_horse_image_jobs set status='pending',attempts=0,next_attempt_at=now(),last_error=null
where status in ('failed','pending') and last_error is not null;
update public.horses h set image_generation_status='pending' from public.store_horse_image_jobs j
where j.horse_id=h.id and j.status='pending' and h.image_url='/foundation-horse.png';
