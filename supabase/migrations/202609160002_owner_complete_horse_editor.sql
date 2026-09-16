-- Owner/Super Admin complete horse editor. Every mutation is server-authorized,
-- transactional, and immutably audited.
alter type public.horse_sex add value if not exists 'Gelding';

alter table public.horses
  add column if not exists phenotype_override jsonb,
  add column if not exists breeding_available boolean not null default true;

create table public.staff_permissions(
 stable_id uuid not null references public.stables(id),
 permission text not null,
 granted_by uuid not null references public.stables(id),
 granted_at timestamptz not null default now(),
 primary key(stable_id,permission),
 check(permission in('horse_editor'))
);
alter table public.staff_permissions enable row level security;

create or replace function public.has_horse_editor_permission()
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from stables s where s.id=auth.uid() and s.account_number=1)
 or exists(select 1 from staff_permissions p where p.stable_id=auth.uid() and p.permission='horse_editor')
$$;

create or replace function public.require_horse_editor()
returns void language plpgsql stable security definer set search_path=public as $$
begin if not has_horse_editor_permission() then raise exception 'Horse Editor access required';end if;end$$;

create or replace function public.owner_set_horse_editor_permission(target_stable uuid,grant_permission boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from stables where id=auth.uid() and account_number=1) then raise exception 'Only Owner Account #1 can manage Horse Editor permission';end if;
 if grant_permission then insert into staff_permissions(stable_id,permission,granted_by) values(target_stable,'horse_editor',auth.uid()) on conflict(stable_id,permission) do update set granted_by=excluded.granted_by,granted_at=now();
 else delete from staff_permissions where stable_id=target_stable and permission='horse_editor';end if;
end$$;

drop function if exists public.admin_list_stables();
create function public.admin_list_stables()
returns table(id uuid,account_number bigint,name text,username text,balance bigint,is_admin boolean,stable_occupied bigint,stable_capacity bigint,unlimited_capacity boolean,can_edit_horses boolean)
language plpgsql stable security definer set search_path=public as $$begin perform require_admin();return query
 select s.id,s.account_number,s.name,s.username,s.balance,s.is_admin,c.occupied,c.total_capacity,c.unlimited,
 (s.account_number=1 or exists(select 1 from staff_permissions p where p.stable_id=s.id and p.permission='horse_editor'))
 from stables s cross join lateral stable_capacity(s.id)c where s.account_number is not null order by s.account_number;end$$;

create table public.horse_edit_audit(
 id uuid primary key default gen_random_uuid(),horse_id uuid not null references public.horses(id),
 horse_name text not null,actor_id uuid not null references public.stables(id),actor_account bigint,
 action text not null default 'horse_edit',changed_fields text[] not null default '{}',
 old_values jsonb not null,new_values jsonb not null,reason text not null default '',
 created_at timestamptz not null default now()
);
alter table public.horse_edit_audit enable row level security;

create or replace function public.protect_horse_edit_audit() returns trigger language plpgsql as $$begin raise exception 'Horse edit audit records are immutable';end$$;
create trigger horse_edit_audit_immutable before update or delete on public.horse_edit_audit for each row execute function public.protect_horse_edit_audit();

create table public.horse_trait_definitions(
 id uuid primary key default gen_random_uuid(),trait_key text not null unique,
 display_name text not null,description text not null default '',badge_color text not null default '#6f45a5',
 active boolean not null default true,is_system boolean not null default false,
 created_by uuid references public.stables(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.horse_trait_assignments(
 horse_id uuid not null references public.horses(id) on delete cascade,
 trait_id uuid not null references public.horse_trait_definitions(id),
 assigned_by uuid not null references public.stables(id),assigned_at timestamptz not null default now(),
 primary key(horse_id,trait_id)
);
alter table public.horse_trait_definitions enable row level security;
alter table public.horse_trait_assignments enable row level security;
create policy "active horse traits are public" on public.horse_trait_definitions for select using(active);
create policy "horse trait assignments are public" on public.horse_trait_assignments for select using(true);
insert into public.horse_trait_definitions(trait_key,display_name,is_system)
values('foundation','Foundation',true),('custom','Custom',true),('limited_edition','Limited Edition',true),('champion','Champion',true),('event_horse','Event Horse',true),('historical','Historical',true),('admin_created','Admin Created',true)
on conflict(trait_key) do nothing;

create or replace function public.owner_save_horse_trait(p_id uuid,p_key text,p_name text,p_description text,p_color text,p_active boolean)
returns public.horse_trait_definitions language plpgsql security definer set search_path=public as $$
declare result horse_trait_definitions;begin perform require_horse_editor();
 if p_id is null then insert into horse_trait_definitions(trait_key,display_name,description,badge_color,active,created_by) values(lower(regexp_replace(trim(p_key),'[^a-zA-Z0-9]+','_','g')),left(trim(p_name),60),left(coalesce(p_description,''),300),left(coalesce(p_color,'#6f45a5'),20),p_active,auth.uid()) returning * into result;
 else update horse_trait_definitions set display_name=left(trim(p_name),60),description=left(coalesce(p_description,''),300),badge_color=left(coalesce(p_color,'#6f45a5'),20),active=p_active,updated_at=now() where id=p_id returning * into result;end if;return result;end$$;

create or replace function public.get_horse_editor_data(p_horse_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;begin perform require_horse_editor();
 select jsonb_build_object(
  'horse',to_jsonb(h),'calculated_age',greatest(0,extract(epoch from(now()-h.birth_date))/86400*30/365.25),
  'owner',case when s.id is null then null else jsonb_build_object('id',s.id,'name',s.name,'account_number',s.account_number)end,
  'stables',(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'name',x.name,'account_number',x.account_number)order by x.account_number),'[]')from stables x where x.account_number is not null),
  'templates',(select coalesce(jsonb_agg(jsonb_build_object('asset_key',a.asset_key,'breed',a.breed,'sex',a.sex,'image_url',a.image_url)order by a.asset_key),'[]')from horse_visual_assets a where a.asset_type='body_template' and a.status='approved' and a.active),
  'traits',(select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'key',t.trait_key,'name',t.display_name,'description',t.description,'color',t.badge_color,'active',t.active,'assigned',ta.horse_id is not null)order by t.display_name),'[]')from horse_trait_definitions t left join horse_trait_assignments ta on ta.trait_id=t.id and ta.horse_id=h.id),
  'audit',(select coalesce(jsonb_agg(z order by z.created_at desc),'[]')from(select id,action,changed_fields,reason,actor_account,created_at from horse_edit_audit where horse_id=h.id order by created_at desc limit 50)z)
 ) into result from horses h left join stables s on s.id=h.owner_id where h.id=p_horse_id;
 if result is null then raise exception 'Horse not found';end if;return result;
end$$;

create or replace function public.owner_edit_horse(p_horse_id uuid,p_changes jsonb,p_reason text default '',p_confirm_high_impact boolean default false)
returns public.horses language plpgsql security definer set search_path=public as $$
declare old_h horses;new_h horses;actor_no bigint;fields text[];high_impact boolean:=false;
 new_birth jsonb;new_stats jsonb;stat_item record;parent_id uuid;target_owner uuid;template_record horse_visual_assets;
begin
 perform require_horse_editor();select account_number into actor_no from stables where id=auth.uid();
 select * into old_h from horses where id=p_horse_id for update;if not found then raise exception 'Horse not found';end if;
 fields:=array(select jsonb_object_keys(coalesce(p_changes,'{}')));
 high_impact:=fields&&array['sex','breed','genetics','sire_id','dam_id','owner_id','restore_from_sanctuary','career_points'];
 if high_impact and not p_confirm_high_impact then raise exception 'Confirm this high-impact horse change';end if;
 if high_impact and length(trim(coalesce(p_reason,'')))<3 then raise exception 'An audit reason is required for high-impact changes';end if;
 if p_changes?'sire_id' or p_changes?'dam_id' then
  foreach parent_id in array array[nullif(p_changes->>'sire_id','')::uuid,nullif(p_changes->>'dam_id','')::uuid] loop
   if parent_id is not null then
    if parent_id=p_horse_id then raise exception 'A horse cannot be its own parent';end if;
    if exists(with recursive ancestry(id)as(select parent_id union select parent.id from ancestry a join horses h on h.id=a.id cross join lateral unnest(array[h.sire_id,h.dam_id])parent(id)where parent.id is not null)select 1 from ancestry where id=p_horse_id) then raise exception 'Pedigree change would create a circular ancestry';end if;
   end if;
  end loop;
 end if;
 new_birth:=old_h.birth_stats;new_stats:=old_h.stats;
 if p_changes?'stat_values' then
  for stat_item in select d.key from stat_definitions d where d.active loop
   if p_changes->'stat_values'?stat_item.key then
    if jsonb_typeof(p_changes->'stat_values'->stat_item.key->'birth')<>'number' or jsonb_typeof(p_changes->'stat_values'->stat_item.key->'development')<>'number' then raise exception 'Birth and development must be numeric for %',stat_item.key;end if;
    if (p_changes->'stat_values'->stat_item.key->>'birth')::numeric<0 or (p_changes->'stat_values'->stat_item.key->>'development')::numeric<0 then raise exception 'Stats cannot be negative';end if;
    new_birth:=jsonb_set(new_birth,array[stat_item.key],to_jsonb((p_changes->'stat_values'->stat_item.key->>'birth')::numeric),true);
    new_stats:=jsonb_set(new_stats,array[stat_item.key],to_jsonb((p_changes->'stat_values'->stat_item.key->>'birth')::numeric+(p_changes->'stat_values'->stat_item.key->>'development')::numeric),true);
   end if;
  end loop;
 end if;
 perform set_config('app.horse_editor','on',true);
 update horses h set
  name=case when p_changes?'name' then left(trim(p_changes->>'name'),80)else h.name end,
  breed=case when p_changes?'breed' then left(trim(p_changes->>'breed'),80)else h.breed end,
  sex=case when p_changes?'sex' then(p_changes->>'sex')::horse_sex else h.sex end,
  birth_date=case when p_changes?'birth_date' then(p_changes->>'birth_date')::timestamptz when p_changes?'age_years' then now()-(interval '1 day'*((p_changes->>'age_years')::numeric*365.25/30))else h.birth_date end,
  mature_height_hands=case when p_changes?'mature_height_hands' then(p_changes->>'mature_height_hands')::numeric else h.mature_height_hands end,
  biography=case when p_changes?'biography' then left(coalesce(p_changes->>'biography',''),1000)else h.biography end,
  origin=case when p_changes?'origin' then(p_changes->>'origin')::horse_origin else h.origin end,
  generation=case when p_changes?'generation' then(p_changes->>'generation')::integer else h.generation end,
  owner_id=case when p_changes?'owner_id' then nullif(p_changes->>'owner_id','')::uuid else h.owner_id end,
  sire_id=case when p_changes?'sire_id' then nullif(p_changes->>'sire_id','')::uuid else h.sire_id end,
  dam_id=case when p_changes?'dam_id' then nullif(p_changes->>'dam_id','')::uuid else h.dam_id end,
  birth_stats=new_birth,stats=new_stats,
  genetics=case when p_changes?'genetics' then p_changes->'genetics' else h.genetics end,
  markings=case when p_changes?'markings' then p_changes->'markings' else h.markings end,
  phenotype_override=case when p_changes?'phenotype_override' then nullif(p_changes->'phenotype_override','null'::jsonb)else h.phenotype_override end,
  color=case when p_changes?'genetics' then genetic_color(p_changes->'genetics') when p_changes?'color' and p_changes?'phenotype_override' then left(p_changes->>'color',120)else h.color end,
  visual_phenotype=case when p_changes?'genetics' or p_changes?'markings' or p_changes?'breed' or p_changes?'sex' or p_changes?'birth_date' or p_changes?'age_years' then build_visual_phenotype(case when p_changes?'breed'then p_changes->>'breed'else h.breed end,case when p_changes?'sex'then(p_changes->>'sex')::horse_sex else h.sex end,greatest(0,extract(epoch from(now()-(case when p_changes?'birth_date'then(p_changes->>'birth_date')::timestamptz when p_changes?'age_years'then now()-(interval '1 day'*((p_changes->>'age_years')::numeric*365.25/30))else h.birth_date end)))/86400*30/365.25),case when p_changes?'genetics'then p_changes->'genetics'else h.genetics end,case when p_changes?'markings'then p_changes->'markings'else h.markings end)else h.visual_phenotype end,
  player_custom_image_url=case when p_changes?'custom_artwork_url'then nullif(left(trim(p_changes->>'custom_artwork_url'),2048),'')else h.player_custom_image_url end,
  visual_template_id=case when p_changes?'visual_template_id'then nullif(p_changes->>'visual_template_id','')else h.visual_template_id end,
  stud_fee=case when p_changes?'stud_fee'then(p_changes->>'stud_fee')::integer else h.stud_fee end,
  last_bred_at=case when p_changes?'last_bred_at'then nullif(p_changes->>'last_bred_at','')::timestamptz else h.last_bred_at end,
  breeding_available=case when p_changes?'breeding_available'then(p_changes->>'breeding_available')::boolean else h.breeding_available end,
  retired=case when p_changes?'retired'then(p_changes->>'retired')::boolean else h.retired end,
  career_points=case when p_changes?'career_points'then(p_changes->>'career_points')::integer else h.career_points end
 where h.id=p_horse_id returning * into new_h;
 if length(new_h.name)<1 or new_h.generation<0 or new_h.stud_fee<0 or new_h.career_points<0 then raise exception 'Horse values are outside allowed administrative ranges';end if;
 if p_changes?'visual_template_id' and new_h.visual_template_id is not null then
  select * into template_record from horse_visual_assets where asset_key=new_h.visual_template_id and asset_type='body_template' and status='approved' and active;
  if not found or(template_record.breed not in('*',new_h.breed))or(template_record.sex is not null and template_record.sex<>new_h.sex)then update horses set visual_template_id=null,le_visual_url='/foundation-horse.png',image_url=coalesce(player_custom_image_url,'/foundation-horse.png')where id=new_h.id returning * into new_h;end if;
 elsif(p_changes?'sex' or p_changes?'breed')and new_h.visual_template_id is not null and not exists(select 1 from horse_visual_assets a where a.asset_key=new_h.visual_template_id and a.status='approved' and a.active and(a.breed in('*',new_h.breed))and(a.sex is null or a.sex=new_h.sex))then update horses set visual_template_id=null,le_visual_url='/foundation-horse.png',image_url=coalesce(player_custom_image_url,'/foundation-horse.png')where id=new_h.id returning * into new_h;
 end if;
 if p_changes?'custom_artwork_url'then update horses set image_url=coalesce(player_custom_image_url,le_visual_url,'/foundation-horse.png')where id=new_h.id returning * into new_h;end if;
 if p_changes?'owner_id' then
  target_owner:=nullif(p_changes->>'owner_id','')::uuid;
  update horse_ownership_history set ended_at=now(),disposition='Administrative Transfer' where horse_id=p_horse_id and ended_at is null;
  if target_owner is not null then insert into horse_ownership_history(horse_id,owner_id,acquired_at,acquisition_method)values(p_horse_id,target_owner,now(),'Administrative Transfer');end if;
 end if;
 if coalesce((p_changes->>'restore_from_sanctuary')::boolean,false) then
  if actor_no<>1 then raise exception 'Only Owner Account #1 may restore a Sanctuary horse';end if;
  target_owner:=coalesce(nullif(p_changes->>'owner_id','')::uuid,old_h.sanctuary_former_owner_id,auth.uid());
  update horses set owner_id=target_owner,sanctuary_retired_at=null,sanctuary_reason='',sanctuary_former_owner_id=null,retired=false where id=p_horse_id returning * into new_h;
  insert into horse_ownership_history(horse_id,owner_id,acquired_at,acquisition_method)values(p_horse_id,target_owner,now(),'Administrative Sanctuary Restoration');
 end if;
 if p_changes?'trait_ids' then
  delete from horse_trait_assignments where horse_id=p_horse_id;
  insert into horse_trait_assignments(horse_id,trait_id,assigned_by)select p_horse_id,value::uuid,auth.uid() from jsonb_array_elements_text(p_changes->'trait_ids')where exists(select 1 from horse_trait_definitions t where t.id=value::uuid and t.active);
 end if;
 select * into new_h from horses where id=p_horse_id;
 insert into horse_edit_audit(horse_id,horse_name,actor_id,actor_account,changed_fields,old_values,new_values,reason)values(p_horse_id,old_h.name,auth.uid(),actor_no,fields,to_jsonb(old_h),to_jsonb(new_h),left(coalesce(p_reason,''),1000));
 return new_h;
end$$;

create or replace function public.owner_correct_show_result(p_result_id uuid,p_action text,p_values jsonb,p_reason text,p_confirm boolean)
returns void language plpgsql security definer set search_path=public as $$
declare r player_show_results;old_values jsonb;actor_no bigint;cp_delta integer:=0;led_delta bigint:=0;begin
 select account_number into actor_no from stables where id=auth.uid();if actor_no<>1 then raise exception 'Only Owner Account #1 may correct completed show history';end if;
 if not p_confirm or length(trim(coalesce(p_reason,'')))<3 then raise exception 'Confirmation and audit reason are required';end if;
 select * into r from player_show_results where id=p_result_id for update;if not found then raise exception 'Show result not found';end if;old_values:=to_jsonb(r);
 if p_action='delete_duplicate' then cp_delta:=-r.career_points_awarded;led_delta:=-r.led_winnings;delete from player_show_results where id=r.id;
 elsif p_action='correct' then cp_delta:=coalesce((p_values->>'career_points_awarded')::integer,r.career_points_awarded)-r.career_points_awarded;led_delta:=coalesce((p_values->>'led_winnings')::bigint,r.led_winnings)-r.led_winnings;update player_show_results set placement=coalesce((p_values->>'placement')::integer,placement),career_points_awarded=career_points_awarded+cp_delta,led_winnings=led_winnings+led_delta where id=r.id;
 else raise exception 'Unsupported career correction';end if;
 update horses set career_points=greatest(0,career_points+cp_delta)where id=r.horse_id;
 if led_delta<>0 then update stables set balance=greatest(0,balance+led_delta)where id=r.owner_id;insert into currency_ledger(stable_id,amount,reason,horse_id)values(r.owner_id,led_delta,'Owner show-result correction: '||left(p_reason,140),r.horse_id);end if;
 insert into horse_edit_audit(horse_id,horse_name,actor_id,actor_account,action,changed_fields,old_values,new_values,reason)select h.id,h.name,auth.uid(),actor_no,'show_result_correction',array['show_history'],old_values,coalesce((select to_jsonb(x)from player_show_results x where x.id=p_result_id),'null'::jsonb),left(p_reason,1000)from horses h where h.id=r.horse_id;
end$$;

create or replace function public.protect_horse_birth_stats() returns trigger language plpgsql set search_path=public as $$
begin
 if tg_op='INSERT' and coalesce(new.birth_stats,'{}'::jsonb)='{}'::jsonb then new.birth_stats:=new.stats;
 elsif tg_op='UPDATE' and new.birth_stats is distinct from old.birth_stats and coalesce(current_setting('app.horse_editor',true),'off')<>'on' then raise exception 'Birth stats are permanent historical values';end if;
 return new;
end$$;

revoke all on function public.has_horse_editor_permission(),public.require_horse_editor(),public.owner_set_horse_editor_permission(uuid,boolean),public.owner_save_horse_trait(uuid,text,text,text,text,boolean),public.get_horse_editor_data(uuid),public.owner_edit_horse(uuid,jsonb,text,boolean),public.owner_correct_show_result(uuid,text,jsonb,text,boolean) from public;
grant execute on function public.has_horse_editor_permission(),public.get_horse_editor_data(uuid),public.owner_edit_horse(uuid,jsonb,text,boolean),public.owner_save_horse_trait(uuid,text,text,text,text,boolean) to authenticated;
grant execute on function public.owner_set_horse_editor_permission(uuid,boolean),public.owner_correct_show_result(uuid,text,jsonb,text,boolean) to authenticated;
grant execute on function public.admin_list_stables() to authenticated;
