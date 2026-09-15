update public.horses h set name='Unnamed Foundation Horse'
from public.store_inventory si where si.horse_id=h.id and si.status='active';

create or replace function public.generate_store_horse(p_rotation timestamptz,p_preferred_breed text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare h_id uuid; breed_name text; colors text[]:=array['Bay','Chestnut','Black','Gray','Palomino'];
begin
  select coalesce(p_preferred_breed,(select name from foundation_breeds where active order by random() limit 1)) into breed_name;
  insert into horses(owner_id,name,breed,sex,color,origin,birth_date,stats,image_url)
  values(null,'Unnamed Foundation Horse',breed_name,(case when random()<0.5 then 'Mare' else 'Stallion' end)::horse_sex,colors[1+floor(random()*array_length(colors,1))::int],'Foundation',now()-(interval '1 day'*(49+floor(random()*49))),random_foundation_stats(),'/foundation-horse.png') returning id into h_id;
  return h_id;
end $$;
revoke all on function public.generate_store_horse(timestamptz,text) from public;

