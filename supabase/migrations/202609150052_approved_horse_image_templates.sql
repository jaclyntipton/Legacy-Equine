create table public.horse_image_templates(
 id uuid primary key default gen_random_uuid(),
 breed text not null,
 body_archetype text not null,
 sex public.horse_sex,
 pose_label text not null default 'balanced standing',
 image_url text not null,
 status text not null default 'pending' check(status in('pending','approved','rejected')),
 active boolean not null default false,
 review_notes text not null default '',
 created_by uuid references public.stables(id),
 approved_by uuid references public.stables(id),
 approved_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check(not active or status='approved')
);
create index horse_templates_selection on public.horse_image_templates(breed,sex,status,active);
alter table public.horse_image_templates enable row level security;
create policy "approved templates are public" on public.horse_image_templates for select using(status='approved' and active);

alter table public.horses add column if not exists image_template_id uuid references public.horse_image_templates(id);
alter table public.horses add column if not exists image_quality_status text not null default 'fallback' check(image_quality_status in('pending','generated','approved','needs_review','rejected','fallback'));

insert into public.horse_image_templates(breed,body_archetype,pose_label,image_url,status,active,review_notes,created_by,approved_by,approved_at)
select '*','Generic Foundation','Official balanced standing','/foundation-horse.png','approved',true,'Official Legacy Equine Foundation fallback',s.id,s.id,now()
from public.stables s where s.account_number=1
and not exists(select 1 from public.horse_image_templates where breed='*' and active);

create or replace function public.admin_list_horse_image_templates() returns setof public.horse_image_templates language plpgsql stable security definer set search_path=public as $$
begin perform require_admin();return query select * from horse_image_templates order by case status when 'pending' then 0 when 'approved' then 1 else 2 end,breed,created_at;end$$;

create or replace function public.admin_save_horse_image_template(target_template uuid,template_breed text,template_archetype text,template_sex text,template_pose text,template_url text) returns public.horse_image_templates language plpgsql security definer set search_path=public as $$
declare result horse_image_templates;begin perform require_admin();
 if length(trim(template_breed))<1 or length(trim(template_archetype))<2 or length(trim(template_url))<4 then raise exception 'Breed, archetype, and template image are required';end if;
 if target_template is null then insert into horse_image_templates(breed,body_archetype,sex,pose_label,image_url,status,active,created_by) values(trim(template_breed),trim(template_archetype),nullif(template_sex,'')::horse_sex,left(trim(template_pose),80),left(trim(template_url),2048),'pending',false,auth.uid()) returning * into result;
 else update horse_image_templates set breed=trim(template_breed),body_archetype=trim(template_archetype),sex=nullif(template_sex,'')::horse_sex,pose_label=left(trim(template_pose),80),image_url=left(trim(template_url),2048),status='pending',active=false,review_notes='',approved_by=null,approved_at=null,updated_at=now() where id=target_template returning * into result;end if;
 if result.id is null then raise exception 'Template not found';end if;return result;end$$;

create or replace function public.admin_review_horse_image_template(target_template uuid,new_status text,make_active boolean,notes text default '') returns public.horse_image_templates language plpgsql security definer set search_path=public as $$
declare result horse_image_templates;begin perform require_admin();if new_status not in('approved','rejected') then raise exception 'Review must approve or reject';end if;
 update horse_image_templates set status=new_status,active=(new_status='approved' and make_active),review_notes=left(coalesce(notes,''),500),approved_by=case when new_status='approved' then auth.uid() else null end,approved_at=case when new_status='approved' then now() else null end,updated_at=now() where id=target_template returning * into result;
 if result.id is null then raise exception 'Template not found';end if;return result;end$$;

create or replace function public.admin_batch_regenerate_foundation_images() returns integer language plpgsql security definer set search_path=public as $$
declare affected integer;begin perform require_admin();
 update horses set image_url='/foundation-horse.png',image_generation_status='pending',image_quality_status='pending',image_template_id=null,image_prompt_version='approved-template-v1' where origin='Foundation';get diagnostics affected=row_count;
 insert into store_horse_image_jobs(horse_id,status,attempts,next_attempt_at,last_error,completed_at) select id,'pending',0,now(),null,null from horses where origin='Foundation' on conflict(horse_id) do update set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null;
 return affected;end$$;

create or replace function public.admin_regenerate_horse_image(target_horse uuid) returns void language plpgsql security definer set search_path=public as $$begin perform require_admin();
 update horses set image_generation_status='pending',image_quality_status='pending',image_template_id=null,image_prompt_version='approved-template-v1' where id=target_horse;if not found then raise exception 'Horse not found';end if;
 insert into store_horse_image_jobs(horse_id,status,attempts,last_error,next_attempt_at,completed_at) values(target_horse,'pending',0,null,now(),null) on conflict(horse_id) do update set status='pending',attempts=0,last_error=null,next_attempt_at=now(),completed_at=null;end$$;

drop function if exists public.claim_store_horse_image_job();
create function public.claim_store_horse_image_job() returns table(job_id uuid,horse_id uuid,visual_phenotype jsonb,markings jsonb,image_url text,template_id uuid,template_url text,is_fallback boolean) language plpgsql security definer set search_path=public as $$
declare chosen uuid;begin
 update store_horse_image_jobs set status='pending',next_attempt_at=now() where status='processing' and completed_at is null and next_attempt_at<now()-interval '10 minutes';
 select j.id into chosen from store_horse_image_jobs j join horses h on h.id=j.horse_id where j.status='pending' and j.next_attempt_at<=now() order by case when h.owner_id is not null then 0 else 1 end,j.created_at for update of j skip locked limit 1;
 if chosen is null then return;end if;update store_horse_image_jobs set status='processing',attempts=attempts+1,next_attempt_at=now()+interval '5 minutes' where id=chosen;update horses set image_generation_status='processing',image_quality_status='pending' where id=(select horse_id from store_horse_image_jobs where id=chosen);
 return query select j.id,h.id,h.visual_phenotype,h.markings,h.image_url,t.id,t.image_url,(t.breed='*') from store_horse_image_jobs j join horses h on h.id=j.horse_id cross join lateral(select x.* from horse_image_templates x where x.status='approved' and x.active and(x.breed=h.breed or x.breed='*')and(x.sex is null or x.sex=h.sex) order by(x.breed=h.breed)desc,(x.sex=h.sex)desc,random() limit 1)t where j.id=chosen;
end$$;

-- Stop publishing malformed Alpha generations immediately. Player uploads are preserved.
update public.horses set image_url='/foundation-horse.png',image_generation_status='complete',image_quality_status='fallback',image_template_id=(select id from horse_image_templates where breed='*' and active limit 1),image_prompt_version='approved-template-fallback-v1'
where image_url like '%/generated/horses/%';
update public.store_horse_image_jobs set status='complete',completed_at=now(),last_error='Retired unconstrained generation; approved template required' where status in('pending','processing');

revoke all on function public.admin_list_horse_image_templates(),public.admin_save_horse_image_template(uuid,text,text,text,text,text),public.admin_review_horse_image_template(uuid,text,boolean,text),public.admin_batch_regenerate_foundation_images(),public.admin_regenerate_horse_image(uuid),public.claim_store_horse_image_job() from public;
grant execute on function public.admin_list_horse_image_templates(),public.admin_save_horse_image_template(uuid,text,text,text,text,text),public.admin_review_horse_image_template(uuid,text,boolean,text),public.admin_batch_regenerate_foundation_images(),public.admin_regenerate_horse_image(uuid) to authenticated;
grant execute on function public.claim_store_horse_image_job() to service_role;
