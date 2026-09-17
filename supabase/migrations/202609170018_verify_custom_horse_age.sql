-- Rollback-safe production verification for the four required creation ages and
-- the persisted Owner override. No QA horses or audit rows survive this block.
alter table public.horse_edit_audit alter column old_values set default '{}';
do $$
declare v_owner uuid;expected numeric;v_horse horses;stored_age numeric;unicorn_count integer;
begin
 select s.id into v_owner from stables s where s.account_number=1;
 if v_owner is null then raise exception 'Owner Account #1 missing';end if;
 select count(*)into unicorn_count from horses horse_row where horse_row.owner_id=v_owner and horse_row.origin='Admin Custom'and horse_row.is_admin_custom and lower(horse_row.breed)='unicorn'and abs(horse_game_age(horse_row.birth_date,horse_row.created_at)-3)<0.000001;
 if unicorn_count<>2 then raise exception 'Expected two corrected Age 3 Owner Unicorns, found %',unicorn_count;end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_owner,'role','authenticated')::text,true);
 begin
  foreach expected in array array[1::numeric,2::numeric,3::numeric,10::numeric]loop
   select * into v_horse from admin_create_visual_horse(v_owner,'Age QA '||expected,'Horse','Quarter Horse','Mare',expected,'Bay','Solid','{}','{"Agility":10,"Speed":10,"Endurance":10,"Temperament":10,"Strength":10,"Intelligence":10,"Conformation":10}','{}','');
   select horse_game_age(horse_row.birth_date,horse_row.created_at)into stored_age from horses horse_row where horse_row.id=v_horse.id;
   if abs(stored_age-expected)>0.000001 then raise exception 'Creation age % stored as %',expected,stored_age;end if;
  end loop;
  perform owner_set_horse_age(v_horse.id,3,'Rollback-safe production age verification');
  select horse_game_age(horse_row.birth_date)into stored_age from horses horse_row where horse_row.id=v_horse.id;
  if abs(stored_age-3)>0.0001 then raise exception 'Owner age override stored as %',stored_age;end if;
  select * into v_horse from owner_edit_horse(v_horse.id,'{"age_years":10}'::jsonb,'Rollback-safe direct editor age verification',false);
  if abs(horse_game_age(v_horse.birth_date)-10)>0.0001 then raise exception 'Direct Horse Editor age route stored incorrectly';end if;
  raise exception using errcode='PT003',message='rollback custom age QA';
 exception when sqlstate 'PT003'then null;
 end;
 raise notice 'CUSTOM AGE VERIFIED: ages 1, 2, 3, 10; Owner override; two corrected Unicorns';
end$$;
