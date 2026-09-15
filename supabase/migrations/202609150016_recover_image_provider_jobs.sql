-- Provider configuration failures are recoverable and must not permanently strand artwork.
update public.store_horse_image_jobs set status='pending',attempts=0,next_attempt_at=now(),last_error=null
where status='failed' and (last_error ilike '%credit card%' or last_error ilike '%gateway%' or last_error ilike '%authentication%');
update public.horses h set image_generation_status='pending' from public.store_horse_image_jobs j
where j.horse_id=h.id and j.status='pending' and h.image_generation_status='failed';
