-- Deterministic approved-layer visuals replace all per-horse production AI generation.
alter table public.horses add column if not exists visual_template_id text;
alter table public.horses add column if not exists player_custom_image_url text;
alter table public.horses add column if not exists le_visual_url text not null default '/foundation-horse.png';
alter table public.horses add column if not exists visual_fingerprint text;

create table public.horse_visual_assets(
 id uuid primary key default gen_random_uuid(),asset_key text not null unique,
 asset_type text not null check(asset_type in('body_template','base_coat','modifier','pattern','face_marking','leg_marking','mane_tail')),
 breed text,sex public.horse_sex,phenotype_key text,marking_key text,leg_position text check(leg_position is null or leg_position in('left_front','right_front','left_hind','right_hind')),
 image_url text not null,z_index integer not null default 0,status text not null default 'pending' check(status in('pending','approved','rejected')),active boolean not null default false,
 review_notes text not null default '',created_by uuid references public.stables(id),approved_by uuid references public.stables(id),approved_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(not active or status='approved')
);
create index horse_visual_asset_lookup on public.horse_visual_assets(asset_type,breed,sex,phenotype_key,marking_key,leg_position,status,active);
alter table public.horse_visual_assets enable row level security;
create policy "approved visual assets are public" on public.horse_visual_assets for select using(status='approved' and active);

insert into public.horse_visual_assets(asset_key,asset_type,breed,image_url,z_index,status,active,review_notes,created_by,approved_by,approved_at)
select 'foundation_generic_01','body_template','*','/foundation-horse.png',0,'approved',true,'Official safe Foundation fallback',s.id,s.id,now() from public.stables s where s.account_number=1
on conflict(asset_key) do nothing;

create or replace function public.assign_horse_visual(p_horse_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare h public.horses;chosen public.horse_visual_assets;fingerprint text;begin
 select x.* into h from public.horses x where x.id=p_horse_id for update;if not found then return;end if;
 select a.* into chosen from public.horse_visual_assets a where a.asset_type='body_template' and a.status='approved' and a.active and(a.breed=h.breed or a.breed='*')and(a.sex is null or a.sex=h.sex)
 order by(a.breed=h.breed)desc,(a.sex=h.sex)desc,md5(h.id::text||a.asset_key) limit 1;
 fingerprint:=md5(concat_ws('|',chosen.asset_key,h.color,h.visual_phenotype->>'pattern',h.markings->>'face',h.markings->>'left_front',h.markings->>'right_front',h.markings->>'left_hind',h.markings->>'right_hind',h.visual_phenotype->>'mane_tail'));
 update public.horses set visual_template_id=chosen.asset_key,visual_fingerprint=fingerprint,le_visual_url=case when chosen.asset_key='foundation_generic_01' then '/foundation-horse.png' else coalesce(le_visual_url,'/foundation-horse.png') end,image_generation_status='complete',image_quality_status=case when chosen.asset_key='foundation_generic_01' then 'fallback' else 'approved' end,image_prompt_version='deterministic-layers-v1',image_url=coalesce(nullif(player_custom_image_url,''),case when chosen.asset_key='foundation_generic_01' then '/foundation-horse.png' else coalesce(le_visual_url,'/foundation-horse.png') end) where id=h.id;
end$$;

-- Preserve recognizable player uploads, but discard all old generated production artwork.
update public.horses set player_custom_image_url=image_url where image_url like '%/legacy-equine-media/%/horses/%' and image_url not like '%/generated/%';
update public.horses set player_custom_image_url=null,le_visual_url='/foundation-horse.png',image_url='/foundation-horse.png' where image_url like '%/generated/%';
do $$declare horse_row record;begin for horse_row in select id from public.horses loop perform public.assign_horse_visual(horse_row.id);end loop;end$$;
update public.store_horse_image_jobs set status='complete',completed_at=now(),last_error='Production AI generation permanently disabled; deterministic approved layers only' where status in('pending','processing');

create or replace function public.update_horse_profile(target_horse uuid,new_name text,new_biography text,new_image_url text) returns public.horses language plpgsql security definer set search_path=public as $$
declare result public.horses;custom_url text:=nullif(trim(coalesce(new_image_url,'')),'');begin
 if length(trim(new_name))<1 or length(trim(new_name))>80 then raise exception 'Horse name must be 1–80 characters';end if;
 update public.horses h set name=trim(new_name),biography=left(coalesce(new_biography,''),1000),player_custom_image_url=case when custom_url is null or custom_url=h.le_visual_url or custom_url='/foundation-horse.png' then null else left(custom_url,2048) end,image_url=case when custom_url is null or custom_url=h.le_visual_url or custom_url='/foundation-horse.png' then coalesce(h.le_visual_url,'/foundation-horse.png') else left(custom_url,2048) end where h.id=target_horse and h.owner_id=auth.uid() returning * into result;
 if result.id is null then raise exception 'Horse not found or not owned by you';end if;return result;end$$;

create or replace function public.get_horse_visual_layers(p_horse_id uuid) returns jsonb language sql stable security definer set search_path=public as $$
 with h as(select * from public.horses where id=p_horse_id),assets as(
 select a.* from h join public.horse_visual_assets a on a.status='approved' and a.active and(
 (a.asset_type='body_template' and a.asset_key=h.visual_template_id)or
 (a.asset_type='base_coat' and a.phenotype_key=lower(h.visual_phenotype->>'coat'))or
 (a.asset_type='modifier' and a.phenotype_key=lower(h.color))or
 (a.asset_type='pattern' and a.marking_key=lower(h.visual_phenotype->>'pattern'))or
 (a.asset_type='face_marking' and a.marking_key=lower(h.markings->>'face'))or
 (a.asset_type='leg_marking' and a.leg_position is not null and a.marking_key=lower(h.markings->>a.leg_position))or
 (a.asset_type='mane_tail' and a.phenotype_key=lower(h.visual_phenotype->>'mane_tail')))
 where(a.breed is null or a.breed='*' or a.breed=h.breed)and(a.sex is null or a.sex=h.sex))
 select jsonb_build_object('horse_id',h.id,'template_id',h.visual_template_id,'fingerprint',h.visual_fingerprint,'custom_url',h.player_custom_image_url,'le_visual_url',h.le_visual_url,'layers',coalesce((select jsonb_agg(jsonb_build_object('asset_key',a.asset_key,'type',a.asset_type,'url',a.image_url,'z',a.z_index)order by a.z_index,a.asset_key)from assets a),'[]'::jsonb))from h
$$;

create or replace function public.admin_list_horse_visual_assets() returns setof public.horse_visual_assets language plpgsql stable security definer set search_path=public as $$begin perform require_admin();return query select * from public.horse_visual_assets order by asset_type,breed,sex,asset_key;end$$;
create or replace function public.admin_save_horse_visual_asset(p_id uuid,p_asset_key text,p_asset_type text,p_breed text,p_sex text,p_phenotype_key text,p_marking_key text,p_leg_position text,p_image_url text,p_z_index integer) returns public.horse_visual_assets language plpgsql security definer set search_path=public as $$declare result public.horse_visual_assets;begin perform require_admin();if p_asset_type not in('body_template','base_coat','modifier','pattern','face_marking','leg_marking','mane_tail')then raise exception 'Choose a supported visual layer type';end if;if p_id is null then insert into public.horse_visual_assets(asset_key,asset_type,breed,sex,phenotype_key,marking_key,leg_position,image_url,z_index,created_by)values(trim(p_asset_key),p_asset_type,nullif(p_breed,''),nullif(p_sex,'')::horse_sex,nullif(lower(p_phenotype_key),''),nullif(lower(p_marking_key),''),nullif(p_leg_position,''),left(p_image_url,2048),p_z_index,auth.uid())returning * into result;else update public.horse_visual_assets set asset_key=trim(p_asset_key),asset_type=p_asset_type,breed=nullif(p_breed,''),sex=nullif(p_sex,'')::horse_sex,phenotype_key=nullif(lower(p_phenotype_key),''),marking_key=nullif(lower(p_marking_key),''),leg_position=nullif(p_leg_position,''),image_url=left(p_image_url,2048),z_index=p_z_index,status='pending',active=false,updated_at=now()where id=p_id returning * into result;end if;return result;end$$;
create or replace function public.admin_review_horse_visual_asset(p_id uuid,p_status text,p_active boolean,p_notes text default '') returns public.horse_visual_assets language plpgsql security definer set search_path=public as $$declare result public.horse_visual_assets;begin perform require_admin();if p_status not in('approved','rejected')then raise exception 'Review must approve or reject';end if;update public.horse_visual_assets set status=p_status,active=(p_status='approved'and p_active),review_notes=left(coalesce(p_notes,''),500),approved_by=case when p_status='approved'then auth.uid()else null end,approved_at=case when p_status='approved'then now()else null end,updated_at=now()where id=p_id returning * into result;return result;end$$;

create or replace function public.claim_store_horse_image_job() returns table(job_id uuid,horse_id uuid,visual_phenotype jsonb,markings jsonb,image_url text,template_id uuid,template_url text,is_fallback boolean) language sql security definer set search_path=public as $$select null::uuid,null::uuid,'{}'::jsonb,'{}'::jsonb,null::text,null::uuid,null::text,true where false$$;
create or replace function public.admin_regenerate_horse_image(target_horse uuid) returns void language plpgsql security definer set search_path=public as $$begin perform require_admin();perform public.assign_horse_visual(target_horse);end$$;
create or replace function public.admin_batch_regenerate_foundation_images() returns integer language plpgsql security definer set search_path=public as $$declare horse_row record;affected integer:=0;begin perform require_admin();for horse_row in select id from public.horses where origin='Foundation' loop perform public.assign_horse_visual(horse_row.id);affected:=affected+1;end loop;return affected;end$$;
revoke all on function public.admin_list_horse_visual_assets(),public.admin_save_horse_visual_asset(uuid,text,text,text,text,text,text,text,text,integer),public.admin_review_horse_visual_asset(uuid,text,boolean,text) from public;
grant execute on function public.get_horse_visual_layers(uuid),public.admin_list_horse_visual_assets(),public.admin_save_horse_visual_asset(uuid,text,text,text,text,text,text,text,text,integer),public.admin_review_horse_visual_asset(uuid,text,boolean,text) to authenticated;
