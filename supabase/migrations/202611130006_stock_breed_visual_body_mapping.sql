-- Quarter Horse conformation masters are shared by the stock-horse breeds.
-- This maps body shape only. Coat genetics, patterns and markings continue to
-- come from each horse's own breed and genotype.
create table if not exists public.horse_visual_body_breed_mappings(
 breed text primary key,
 master_breed text not null,
 notes text not null default '',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

alter table public.horse_visual_body_breed_mappings enable row level security;
drop policy if exists "visual body breed mappings are public" on public.horse_visual_body_breed_mappings;
create policy "visual body breed mappings are public"
on public.horse_visual_body_breed_mappings for select using(true);

insert into public.horse_visual_body_breed_mappings(breed,master_breed,notes)
values
 ('Quarter Horse','Quarter Horse','Approved Quarter Horse masters'),
 ('American Paint Horse','Quarter Horse','Uses Quarter Horse conformation; Paint genetics and markings remain distinct'),
 ('Paint Horse','Quarter Horse','Supported display alias for American Paint Horse'),
 ('Appaloosa','Quarter Horse','Uses Quarter Horse conformation; Appaloosa genetics and markings remain distinct')
on conflict(breed)do update set
 master_breed=excluded.master_breed,
 notes=excluded.notes,
 updated_at=now();

create or replace function public.horse_visual_master_breed(p_breed text)
returns text
language sql
stable
set search_path=public
as $$
 select coalesce((select m.master_breed from public.horse_visual_body_breed_mappings m where m.breed=p_breed),p_breed)
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
 required_master_breed text;
begin
 select x.* into h from public.horses x where x.id=p_horse_id for update;
 if not found then return;end if;

 required_stage:=public.horse_visual_life_stage(h.birth_date);
 required_master_breed:=public.horse_visual_master_breed(h.breed);
 select a.* into chosen
 from public.horse_visual_assets a
 where a.asset_type='body_template'
   and a.status='approved'
   and a.active
   and a.life_stage in(required_stage,'any')
   and(a.breed=required_master_breed or a.breed='*')
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
   (a.breed=required_master_breed)desc,
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

create or replace function public.get_horse_visual_layers(p_horse_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
 with h as(select * from public.horses where id=p_horse_id),assets as(
 select a.* from h join public.horse_visual_assets a on a.status='approved' and a.active and(
 (a.asset_type='body_template' and a.asset_key=h.visual_template_id)or
 (a.asset_type='base_coat' and a.phenotype_key=lower(h.visual_phenotype->>'coat'))or
 (a.asset_type='modifier' and a.phenotype_key=lower(h.color))or
 (a.asset_type='pattern' and a.marking_key=lower(h.visual_phenotype->>'pattern'))or
 (a.asset_type='face_marking' and a.marking_key=lower(h.markings->>'face'))or
 (a.asset_type='leg_marking' and a.leg_position is not null and a.marking_key=lower(h.markings->>a.leg_position))or
 (a.asset_type='mane_tail' and a.phenotype_key=lower(h.visual_phenotype->>'mane_tail')))
 where(a.body_template_key=h.visual_template_id or a.breed is null or a.breed='*' or a.breed=h.breed))
 select jsonb_build_object('horse_id',h.id,'template_id',h.visual_template_id,'fingerprint',h.visual_fingerprint,'custom_url',h.player_custom_image_url,'le_visual_url',h.le_visual_url,'layers',coalesce((select jsonb_agg(jsonb_build_object('asset_key',a.asset_key,'type',a.asset_type,'url',a.image_url,'z',a.z_index)order by a.z_index,a.asset_key)from assets a),'[]'::jsonb))from h
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
   select b.name as breed,public.horse_visual_master_breed(b.name)as master_breed,s.life_stage,x.sex
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
 left join masters m on m.breed=e.master_breed and m.life_stage=e.life_stage
   and(m.sex is null or m.sex=e.sex)
 left join requirement_counts c on c.body_template_key=m.asset_key
 order by e.breed,e.life_stage,e.sex;
end
$$;

revoke all on function public.horse_visual_master_breed(text) from public;
grant execute on function public.horse_visual_master_breed(text) to authenticated;

comment on table public.horse_visual_body_breed_mappings is 'Maps a horse breed to the approved conformation-master breed; genetics and markings remain those of the horse.';
