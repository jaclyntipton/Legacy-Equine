-- Deployment-time verification of the repaired Owner Brand paths. Test writes run
-- inside rolled-back subtransactions and leave no QA horses, purchases, or ledger rows.
do $$
declare
 v_owner uuid;v_other uuid;v_brand uuid;v_horse horses;v_inventory uuid;
 v_count bigint;v_audits bigint;v_function text;
begin
 select id into v_owner from stables where account_number=1;
 if v_owner is null then raise exception 'TFR verification: Account #1 missing';end if;
 select id into v_brand from stable_brands where stable_id=v_owner and code='TFR'and active and reserved;
 if v_brand is null then raise exception 'TFR verification: active reserved Brand missing';end if;
 if not exists(select 1 from stable_brand_privileges where stable_id=v_owner and granted and permanent)then raise exception 'TFR verification: permanent privilege missing';end if;
 select count(*)into v_count from horses where horse_brand_id=v_brand and branded_by_account=1;
 select count(*)into v_audits from stable_brand_audit where stable_id=v_owner and action='horse_brand_assigned';
 if v_count=0 then raise exception 'TFR verification: no provenance-supported Owner horses were backfilled';end if;
 if v_audits=0 then raise exception 'TFR verification: assignment audit missing';end if;

 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_owner,'role','authenticated')::text,true);

 begin
  select * into v_horse from admin_create_visual_horse(v_owner,'TFR Brand QA Custom','Horse','Quarter Horse','Mare',2,'Bay','Solid','{}','{"Agility":10,"Speed":10,"Endurance":10,"Temperament":10,"Strength":10,"Intelligence":10,"Conformation":10}','{}','');
  if v_horse.brand_code_at_assignment<>'TFR'or v_horse.brand_origin<>'Owner Custom Creation'then raise exception 'Custom horse did not receive TFR';end if;
  select id into v_other from stables where account_number<>1 order by account_number limit 1;
  if v_other is not null then
   update horses set owner_id=v_other where id=v_horse.id returning * into v_horse;
   if v_horse.brand_code_at_assignment<>'TFR'or v_horse.horse_brand_id<>v_brand then raise exception 'Sale/transfer changed permanent TFR provenance';end if;
  end if;
  raise exception using errcode='PT001',message='rollback custom Brand QA';
 exception when sqlstate 'PT001'then null;
 end;

 begin
  select id into v_inventory from store_inventory where status='active'order by generated_at limit 1;
  if v_inventory is null then perform refresh_store_inventory();select id into v_inventory from store_inventory where status='active'order by generated_at limit 1;end if;
  if v_inventory is null then raise exception 'No Foundation inventory available for TFR verification';end if;
  select * into v_horse from purchase_store_horse(v_inventory);
  if v_horse.brand_code_at_assignment<>'TFR'or v_horse.brand_origin<>'Foundation Purchase'then raise exception 'Foundation purchase did not receive TFR';end if;
  raise exception using errcode='PT002',message='rollback Foundation Brand QA';
 exception when sqlstate 'PT002'then null;
 end;

 select pg_get_functiondef('public.brand_new_foal()'::regprocedure)into v_function;
 if v_function!~*'select\s+owner_id\s+into\s+dam_owner\s+from\s+horses\s+where\s+id\s*=\s*new\.dam_id'then raise exception 'Foal Brand is not derived from dam owner';end if;
 select pg_get_functiondef('public.brand_origin_horse_on_insert()'::regprocedure)into v_function;
 if v_function!~*'new\.origin\s*<>\s*''Bred'''then raise exception 'General origin hook can override foal Brand';end if;
 raise notice 'TFR VERIFIED: owner %, brand %, existing eligible horses %, assignment audits %, custom/foundation/dam-owner/sale paths pass',v_owner,v_brand,v_count,v_audits;
end$$;
