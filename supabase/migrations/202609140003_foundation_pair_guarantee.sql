create or replace function public.purchase_foundation_horse()
returns public.horses language plpgsql security definer set search_path=public as $$
declare s stables; h horses; first_sex horse_sex; chosen_sex horse_sex; breeds text[]:=array['Thoroughbred','Arabian','Warmblood','Quarter Horse']; colors text[]:=array['Bay','Chestnut','Black','Gray','Palomino'];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into s from stables where id=auth.uid() for update;
  if not found then raise exception 'Create your stable first'; end if;
  if s.foundation_purchases>=3 then raise exception 'Foundation purchase limit reached'; end if;
  if s.balance<1000 then raise exception 'Insufficient funds'; end if;
  if s.foundation_purchases=1 then
    select sex into first_sex from horses where owner_id=auth.uid() and origin='Foundation' order by created_at limit 1;
    chosen_sex:=case when first_sex='Mare' then 'Stallion'::horse_sex else 'Mare'::horse_sex end;
  else chosen_sex:=case when random()<0.5 then 'Mare' else 'Stallion' end::horse_sex; end if;
  insert into horses(owner_id,name,breed,sex,color,origin,birth_date,stats,image_url)
  values(auth.uid(),'Unnamed Foundation Horse',breeds[1+floor(random()*array_length(breeds,1))::int],chosen_sex,colors[1+floor(random()*array_length(colors,1))::int],'Foundation',now()-(interval '1 day'*(49+floor(random()*49))),random_foundation_stats(),'/foundation-horse.png') returning * into h;
  update stables set balance=balance-1000,foundation_purchases=foundation_purchases+1 where id=auth.uid();
  insert into currency_ledger(stable_id,amount,reason,horse_id) values(auth.uid(),-1000,'Foundation horse purchase',h.id);
  return h;
end $$;
revoke all on function public.purchase_foundation_horse() from public;
grant execute on function public.purchase_foundation_horse() to authenticated;
