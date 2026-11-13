-- Deterministic horse artwork has two body stages: foal and mature.
-- This migration changes selection metadata only. It creates no artwork and
-- does not promote an incomplete visual set into production.
alter table public.horse_visual_assets
  add column if not exists life_stage text not null default 'mature';

alter table public.horse_visual_assets
  drop constraint if exists horse_visual_assets_life_stage_check;
alter table public.horse_visual_assets
  add constraint horse_visual_assets_life_stage_check
  check(life_stage in('foal','mature','any'));

update public.horse_visual_assets
set life_stage='any'
where not immutable_source and(asset_key='foundation_generic_01' or breed='*');

create index if not exists horse_visual_asset_stage_lookup
on public.horse_visual_assets(asset_type,breed,life_stage,sex,status,active);

create or replace function public.horse_visual_life_stage(p_birth_date timestamptz)
returns text
language sql
stable
set search_path=public
as $$
  select case when public.horse_game_age(p_birth_date)<2 then 'foal' else 'mature' end
$$;

create or replace function public.assign_horse_visual(p_horse_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
 h public.horses;
 chosen public.horse_visual_assets;
 fingerprint text;
 required_stage text;
begin
 select x.* into h from public.horses x where x.id=p_horse_id for update;
 if not found then return;end if;

 required_stage:=public.horse_visual_life_stage(h.birth_date);
 select a.* into chosen
 from public.horse_visual_assets a
 where a.asset_type='body_template'
   and a.status='approved'
   and a.active
   and a.life_stage in(required_stage,'any')
   and(a.breed=h.breed or a.breed='*')
   and(a.sex is null or a.sex=h.sex)
   and(
     a.breed='*'
     or(
       exists(select 1 from public.horse_visual_asset_requirements r where r.body_template_key=a.asset_key)
       and not exists(
         select 1 from public.horse_visual_asset_requirements r
         where r.body_template_key=a.asset_key and r.status<>'production'
       )
     )
   )
 order by
   (a.life_stage=required_stage)desc,
   (a.breed=h.breed)desc,
   (a.sex=h.sex)desc,
   md5(h.id::text||a.asset_key)
 limit 1;

 if chosen.id is null then
   update public.horses
   set visual_template_id=null,
       visual_fingerprint=md5(concat_ws('|','fallback',required_stage,h.id::text)),
       le_visual_url='/generic-horse-placeholder.png',
       image_url=coalesce(nullif(player_custom_image_url,''),'/generic-horse-placeholder.png'),
       image_generation_status='pending',
       image_quality_status='fallback',
       image_prompt_version='deterministic-layers-v2'
   where id=h.id;
   return;
 end if;

 fingerprint:=md5(concat_ws('|',chosen.asset_key,required_stage,h.color,
   h.visual_phenotype->>'pattern',h.markings->>'face',
   h.markings->>'left_front',h.markings->>'right_front',
   h.markings->>'left_hind',h.markings->>'right_hind',
   h.visual_phenotype->>'mane_tail'));

 update public.horses
 set visual_template_id=chosen.asset_key,
     visual_fingerprint=fingerprint,
     le_visual_url=case when chosen.breed='*' then '/generic-horse-placeholder.png' else coalesce(nullif(le_visual_url,''),'/generic-horse-placeholder.png') end,
     image_generation_status=case when chosen.breed='*' then 'pending' else 'complete' end,
     image_quality_status=case when chosen.breed='*' then 'fallback' else 'approved' end,
     image_prompt_version='deterministic-layers-v2',
     image_url=coalesce(nullif(player_custom_image_url,''),case when chosen.breed='*' then '/generic-horse-placeholder.png' else coalesce(nullif(le_visual_url,''),'/generic-horse-placeholder.png') end)
 where id=h.id;
end
$$;

create or replace function public.admin_set_visual_master_life_stage(
 p_asset uuid,
 p_life_stage text
)
returns public.horse_visual_assets
language plpgsql
security definer
set search_path=public
as $$
declare result public.horse_visual_assets;
begin
 perform require_super_admin();
 if p_life_stage not in('foal','mature')then
   raise exception 'Body stage must be foal or mature';
 end if;
 update public.horse_visual_assets
 set life_stage=p_life_stage,updated_at=now()
 where id=p_asset and asset_type='body_template' and not immutable_source
 returning * into result;
 if result.id is null then
   raise exception 'Editable body master not found';
 end if;
 return result;
end
$$;

create or replace function public.admin_visual_stage_coverage()
returns table(
 breed text,
 life_stage text,
 sex text,
 master_key text,
 master_status text,
 production_requirements bigint,
 incomplete_requirements bigint,
 display_ready boolean
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
 perform require_admin();
 return query
 with expected as(
   select b.name as breed,s.life_stage,x.sex
   from public.foundation_breeds b
   cross join(values('foal'),('mature'))s(life_stage)
   cross join(values('Mare'),('Stallion'))x(sex)
   where b.active
 ), masters as(
   select distinct on(a.breed,a.life_stage,coalesce(a.sex::text,''))
     a.breed,a.life_stage,a.sex::text as sex,a.asset_key,a.status,a.active
   from public.horse_visual_assets a
   where a.asset_type='body_template' and a.breed<>'*'
   order by a.breed,a.life_stage,coalesce(a.sex::text,''),a.active desc,a.approved_at desc nulls last,a.created_at desc
 ), requirement_counts as(
   select r.body_template_key,
     count(*)filter(where r.status='production') as production_count,
     count(*)filter(where r.status<>'production') as incomplete_count
   from public.horse_visual_asset_requirements r
   group by r.body_template_key
 )
 select e.breed,e.life_stage,e.sex,m.asset_key,
   coalesce(m.status,'missing'),coalesce(c.production_count,0),
   coalesce(c.incomplete_count,0),
   coalesce(m.status='approved' and m.active and c.production_count>0 and c.incomplete_count=0,false)
 from expected e
 left join masters m on m.breed=e.breed and m.life_stage=e.life_stage
   and(m.sex is null or m.sex=e.sex)
 left join requirement_counts c on c.body_template_key=m.asset_key
 order by e.breed,e.life_stage,e.sex;
end
$$;

revoke all on function public.admin_set_visual_master_life_stage(uuid,text),public.admin_visual_stage_coverage() from public;
grant execute on function public.horse_visual_life_stage(timestamptz) to authenticated;
grant execute on function public.admin_set_visual_master_life_stage(uuid,text),public.admin_visual_stage_coverage() to authenticated;

comment on column public.horse_visual_assets.life_stage is 'Foal or mature body stage. Any is reserved for a neutral fallback carrying no phenotype.';
comment on function public.admin_visual_stage_coverage() is 'Owner-only foal/mature coverage matrix. A set is display-ready only after every registered requirement is in Production.';
