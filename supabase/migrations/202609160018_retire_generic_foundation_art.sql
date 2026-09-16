-- Permanently retire the obsolete generic Foundation horse illustration.
-- Immutable QH masters and deterministic production assets are untouched.
update public.horses
set image_url='', le_visual_url='', image_quality_status='pending', image_generation_status='pending', visual_template_id=null, image_template_id=null
where image_url='/foundation-horse.png' or le_visual_url='/foundation-horse.png';

update public.horse_image_templates set active=false,status='rejected',review_notes=concat_ws(' · ',nullif(review_notes,''),'Obsolete generic Foundation artwork permanently retired')
where image_url='/foundation-horse.png';

update public.horse_visual_assets set active=false,status='rejected',review_notes=concat_ws(' · ',nullif(review_notes,''),'Obsolete generic Foundation artwork permanently retired') where image_url='/foundation-horse.png';

alter table public.horses alter column image_url set default '';
