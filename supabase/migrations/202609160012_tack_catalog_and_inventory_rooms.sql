alter table public.store_products add column if not exists icon_url text;
alter table public.store_products add column if not exists stackable boolean not null default false;

insert into public.store_products(id,department,name,description,price,active,tack_slot,quality,tack_bonuses,discipline_orientation,sort_order) values
('bridle_basic','tack','Basic Bridle','A dependable everyday bridle.',150,true,'bridle','Basic','{"Temperament":1}','{}',100),
('bridle_quality_english','tack','Quality English Bridle','Balanced contact for English work.',300,true,'bridle','Quality','{"Temperament":1,"Intelligence":1}','{"Hunter"}',110),
('bridle_performance_hunter','tack','Performance Hunter Bridle','Performance tack oriented toward hunter competition.',550,true,'bridle','Performance','{"Agility":1,"Temperament":2}','{"Hunter"}',120),
('bridle_elite_competition','tack','Elite Competition Bridle','Top-tier competition bridle.',900,true,'bridle','Elite','{"Agility":2,"Temperament":2}','{"Hunter","Dressage"}',130),
('saddle_basic','tack','Basic Saddle','A practical general-purpose saddle.',250,true,'saddle','Basic','{"Strength":1}','{}',200),
('saddle_quality_hunter','tack','Quality Hunter Saddle','Quality saddle for balanced hunter work.',500,true,'saddle','Quality','{"Agility":1,"Strength":1}','{"Hunter"}',210),
('saddle_performance_jumper','tack','Performance Jumper Saddle','Performance saddle supporting power and agility.',850,true,'saddle','Performance','{"Agility":2,"Strength":1}','{"Jumping"}',220),
('saddle_elite_dressage','tack','Elite Dressage Saddle','Elite saddle for precision and responsiveness.',1300,true,'saddle','Elite','{"Agility":2,"Intelligence":2}','{"Dressage"}',230),
('pad_basic','tack','Basic Saddle Pad','Simple protective saddle pad.',100,true,'saddle_pad','Basic','{"Endurance":1}','{}',300),
('pad_quality_show','tack','Quality Show Pad','Polished show pad with added comfort.',225,true,'saddle_pad','Quality','{"Temperament":1,"Endurance":1}','{}',310),
('pad_performance','tack','Performance Discipline Pad','Performance pad for demanding work.',425,true,'saddle_pad','Performance','{"Endurance":2,"Recovery":0}','{}',320),
('pad_elite','tack','Elite Competition Pad','Elite show-day saddle pad.',700,true,'saddle_pad','Elite','{"Endurance":2,"Temperament":2}','{}',330),
('legs_basic_wraps','tack','Basic Leg Wraps','Everyday leg protection.',125,true,'leg_protection','Basic','{"Strength":1}','{}',400),
('legs_quality_boots','tack','Quality Boots','Quality protective boots.',275,true,'leg_protection','Quality','{"Strength":1,"Agility":1}','{}',410),
('legs_performance_sport','tack','Performance Sport Boots','Sport boots for athletic competition.',475,true,'leg_protection','Performance','{"Strength":2,"Agility":1}','{"Jumping","Barrel Racing"}',420),
('legs_elite_competition','tack','Elite Competition Boots','Elite protection for demanding competition.',775,true,'leg_protection','Elite','{"Strength":2,"Agility":2}','{}',430)
on conflict(id)do update set name=excluded.name,description=excluded.description,price=excluded.price,tack_slot=excluded.tack_slot,quality=excluded.quality,tack_bonuses=excluded.tack_bonuses,discipline_orientation=excluded.discipline_orientation,sort_order=excluded.sort_order;

create or replace function public.unequip_tack(p_horse uuid,p_slot text) returns jsonb language plpgsql security definer set search_path=public as $$begin if not exists(select 1 from horses where id=p_horse and owner_id=auth.uid())then raise exception 'Choose a horse you own';end if;delete from horse_equipment where horse_id=p_horse and slot=p_slot;return recalculate_horse_tack(p_horse);end$$;
grant execute on function public.unequip_tack(uuid,text) to authenticated;
