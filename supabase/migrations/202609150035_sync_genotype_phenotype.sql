create or replace function public.sync_horse_genetic_phenotype()
returns trigger language plpgsql set search_path=public as $$
declare age_years numeric;rebuilt jsonb;begin
 age_years:=greatest(0,extract(epoch from(now()-new.birth_date))/31557600);new.color:=genetic_color(new.genetics);
 rebuilt:=build_visual_phenotype(new.breed,new.sex,age_years,new.genetics,new.markings);
 if new.mature_height_hands is not null then rebuilt:=jsonb_set(rebuilt,'{height_hands}',to_jsonb(new.mature_height_hands),true);end if;
 rebuilt:=jsonb_set(jsonb_set(rebuilt,'{background}',to_jsonb('transparent or Legacy Equine cream #f8f5ff'::text),true),'{lighting}',to_jsonb('neutral color-accurate lighting with no color cast'::text),true);new.visual_phenotype:=rebuilt;return new;end $$;
create trigger sync_horse_genetic_phenotype_before_write before insert or update of genetics,markings,breed,sex,birth_date on public.horses for each row execute function public.sync_horse_genetic_phenotype();
update public.horses set genetics=genetics;
update public.horses set image_generation_status='pending',image_prompt_version='horse-v11' where owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=horses.id and si.status='active');
insert into public.store_horse_image_jobs(horse_id,status,attempts,next_attempt_at,last_error,completed_at)
select id,'pending',0,now(),null,null from public.horses where owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=horses.id and si.status='active')
on conflict(horse_id) do update set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null;
comment on column public.horses.color is 'Authoritative visible phenotype derived from horses.genetics; synchronized by database trigger.';
