-- Restore the authoritative Owner #1 TFR brand and close the missing assignment,
-- administration, backfill, and display data paths without changing horse names.

do $$
declare v_owner uuid;v_conflict uuid;
begin
 select s.id into v_owner from public.stables s where s.account_number=1 for update;
 if v_owner is null then raise exception 'Owner Account #1 not found';end if;
 update public.stables set name='Twisted Fox Ranch' where id=v_owner and name<>'Twisted Fox Ranch';
 select b.stable_id into v_conflict from public.stable_brands b where b.normalized_code='TFR' and b.stable_id<>v_owner;
 if v_conflict is not null then raise exception 'TFR is incorrectly reserved by another Stable';end if;
 insert into public.stable_brand_privileges(stable_id,granted,permanent,reason,granted_by)
 values(v_owner,true,true,'Permanent Owner #1 Brand Privilege',v_owner)
 on conflict(stable_id)do update set granted=true,permanent=true,reason='Permanent Owner #1 Brand Privilege',granted_by=v_owner,updated_at=now();
 insert into public.stable_brands(stable_id,code,active,reserved)
 values(v_owner,'TFR',true,true)
 on conflict(stable_id)do update set code='TFR',active=true,reserved=true,updated_at=now();
end$$;

create or replace function public.assign_horse_brand(p_horse uuid,p_stable uuid,p_origin text)
returns boolean language plpgsql security definer set search_path=public as $$
declare b stable_brands;s stables;actor uuid:=coalesce(auth.uid(),p_stable);
begin
 select * into b from stable_brands where stable_id=p_stable and active;
 if not found or not has_brand_privilege(p_stable)then return false;end if;
 select * into s from stables where id=p_stable;
 update horses set horse_brand_id=b.id,brand_code_at_assignment=b.code,brand_mark_at_assignment=b.mark_url,brand_mark_version=b.mark_version,branded_by_account=s.account_number,brand_origin=p_origin,brand_assigned_at=now(),breeder_stable_id=case when p_origin='Foal Birth'then s.id else breeder_stable_id end,breeder_name_at_birth=case when p_origin='Foal Birth'then s.name else breeder_name_at_birth end,breeder_account_at_birth=case when p_origin='Foal Birth'then s.account_number else breeder_account_at_birth end
 where id=p_horse and horse_brand_id is null;
 if found then
  insert into stable_brand_audit(brand_id,horse_id,stable_id,actor_id,action,new_values,reason)
  values(b.id,p_horse,p_stable,actor,'horse_brand_assigned',jsonb_build_object('code',b.code,'mark',b.mark_url,'origin',p_origin),p_origin);
  return true;
 end if;
 return false;
end$$;

create or replace function public.brand_origin_horse_on_insert()returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.owner_id is not null and new.origin<>'Bred' and coalesce(current_setting('app.skip_origin_brand',true),'off')<>'on' then
  perform assign_horse_brand(new.id,new.owner_id,case when new.origin='Admin Custom'then'Owner Custom Creation'else new.origin::text end);
 end if;
 return new;
end$$;
drop trigger if exists assign_origin_brand_on_insert on public.horses;
create trigger assign_origin_brand_on_insert after insert on public.horses for each row execute function public.brand_origin_horse_on_insert();

create or replace function public.owner_correct_horse_brand(p_horse uuid,p_stable uuid,p_reason text)
returns public.horses language plpgsql security definer set search_path=public as $$
declare old_h horses;new_h horses;b stable_brands;s stables;
begin
 if not is_owner_account()then raise exception 'Owner Account #1 access required';end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'A Brand correction reason is required';end if;
 select * into old_h from horses where id=p_horse for update;if not found then raise exception 'Horse not found';end if;
 if p_stable is null then
  update horses set horse_brand_id=null,brand_code_at_assignment=null,brand_mark_at_assignment=null,brand_mark_version=null,branded_by_account=null,brand_origin=null,brand_assigned_at=null where id=p_horse returning * into new_h;
 else
  select * into b from stable_brands where stable_id=p_stable and active;if not found then raise exception 'Active Stable Brand not found';end if;
  select * into s from stables where id=p_stable;
  update horses set horse_brand_id=b.id,brand_code_at_assignment=b.code,brand_mark_at_assignment=b.mark_url,brand_mark_version=b.mark_version,branded_by_account=s.account_number,brand_origin='Owner Administrative Correction',brand_assigned_at=now()where id=p_horse returning * into new_h;
 end if;
 insert into stable_brand_audit(brand_id,horse_id,stable_id,actor_id,action,old_values,new_values,reason)
 values(new_h.horse_brand_id,p_horse,p_stable,auth.uid(),'horse_brand_corrected',jsonb_build_object('code',old_h.brand_code_at_assignment,'stable_id',old_h.breeder_stable_id),jsonb_build_object('code',new_h.brand_code_at_assignment,'stable_id',p_stable),left(p_reason,500));
 return new_h;
end$$;

create or replace function public.admin_list_stable_brands()
returns table(stable_id uuid,account_number bigint,stable_name text,brand_id uuid,code text,mark_url text,active boolean,privilege_granted boolean,permanent boolean,reason text,horse_count bigint)
language plpgsql stable security definer set search_path=public as $$
begin
 perform require_admin_permission('admin.brands.view');
 return query select s.id,s.account_number,s.name,b.id,b.code,b.mark_url,b.active,coalesce(p.granted,false),coalesce(p.permanent,false),coalesce(p.reason,''),count(h.id)
 from stables s left join stable_brand_privileges p on p.stable_id=s.id left join stable_brands b on b.stable_id=s.id left join horses h on h.horse_brand_id=b.id
 where b.id is not null or p.stable_id is not null group by s.id,b.id,p.stable_id,p.granted,p.permanent,p.reason order by s.account_number;
end$$;

-- Provenance-safe Alpha backfill: first Foundation/Admin acquisition by Owner #1,
-- explicit breeder snapshots/records, or dam ownership at the recorded foaling time.
do $$
declare v_owner uuid;v_horse uuid;v_origin text;
begin
 select id into v_owner from stables where account_number=1;
 for v_horse,v_origin in
  with first_acquisition as(
   select distinct on(oh.horse_id)oh.horse_id,oh.owner_id,oh.acquisition_method from horse_ownership_history oh order by oh.horse_id,oh.acquired_at,oh.id
  ),eligible as(
   select h.id,case when h.origin='Foundation'then'Foundation Purchase Backfill'when h.origin='Admin Custom'then'Owner Custom Creation Backfill'else'Foal Birth Backfill'end origin
   from horses h left join first_acquisition fa on fa.horse_id=h.id
   where h.horse_brand_id is null and(
    (h.origin='Foundation'and fa.owner_id=v_owner and fa.acquisition_method='Foundation Purchase')or
    (h.origin='Admin Custom'and fa.owner_id=v_owner and fa.acquisition_method='Admin Custom')or
    (h.origin='Bred'and(h.breeder_stable_id=v_owner or h.breeder_account_at_birth=1 or exists(select 1 from breeding_records br where br.foal_id=h.id and br.owner_id=v_owner)or exists(select 1 from horse_ownership_history dh where dh.horse_id=h.dam_id and dh.owner_id=v_owner and dh.acquired_at<=h.created_at and(dh.ended_at is null or dh.ended_at>h.created_at))))
   )
  )select id,origin from eligible
 loop perform assign_horse_brand(v_horse,v_owner,v_origin);end loop;
end$$;

drop function if exists public.get_marketplace();
create function public.get_marketplace()
returns table(listing_id uuid,horse_id uuid,name text,breed text,sex horse_sex,color text,birth_date timestamptz,stats jsonb,image_url text,price integer,seller_name text,seller_username text,created_at timestamptz,brand_code_at_assignment text,brand_mark_at_assignment text,brand_origin text)
language sql security definer set search_path=public as $$select l.id,h.id,h.name,h.breed,h.sex,h.color,h.birth_date,h.stats,h.image_url,l.price,s.name,s.username,l.created_at,h.brand_code_at_assignment,h.brand_mark_at_assignment,h.brand_origin from marketplace_listings l join horses h on h.id=l.horse_id join stables s on s.id=l.seller_id where l.status='active' order by l.created_at desc$$;

revoke all on function public.admin_list_stable_brands(),public.owner_correct_horse_brand(uuid,uuid,text) from public;
grant execute on function public.admin_list_stable_brands(),public.owner_correct_horse_brand(uuid,uuid,text),public.get_marketplace() to authenticated;
