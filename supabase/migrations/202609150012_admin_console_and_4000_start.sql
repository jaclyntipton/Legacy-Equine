alter table public.stables alter column balance type bigint;
alter table public.currency_ledger alter column amount type bigint;
alter table public.horses add column species text not null default 'Horse';

-- Account #1 is the permanent owner account and the only initial administrator.
update public.stables set is_admin=(account_number=1) where account_number is not null;

-- Bring every current player to at least 4,000 LE and preserve an auditable ledger entry.
with targets as (select id,4000-balance as amount from public.stables where balance<4000), bumped as (
  update public.stables s set balance=4000 from targets t where s.id=t.id
  returning s.id,t.amount
)
insert into public.currency_ledger(stable_id,amount,reason)
select id,amount,'Alpha starting-balance increase to 4,000 LE' from bumped where amount>0;

create or replace function public.initialize_stable(stable_name text)
returns public.stables language plpgsql security definer set search_path=public as $$
declare result public.stables;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into result from stables where id=auth.uid();
  if found then return result; end if;
  if length(trim(stable_name)) not between 2 and 60 then raise exception 'Stable name must be 2–60 characters'; end if;
  insert into stables(id,name,balance) values(auth.uid(),trim(stable_name),4000) returning * into result;
  insert into currency_ledger(stable_id,amount,reason) values(auth.uid(),4000,'Starting funds');
  return result;
exception when unique_violation then select * into result from stables where id=auth.uid(); return result;
end $$;

create or replace function public.require_admin()
returns void language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from stables where id=auth.uid() and is_admin) then raise exception 'Administrator access required'; end if;
end $$;

create or replace function public.admin_list_stables()
returns table(id uuid,account_number bigint,name text,username text,balance bigint,is_admin boolean)
language plpgsql security definer set search_path=public as $$
begin perform require_admin(); return query select s.id,s.account_number,s.name,s.username,s.balance,s.is_admin from stables s where s.account_number is not null order by s.account_number; end $$;

create or replace function public.admin_adjust_balance(target_stable uuid,adjustment bigint,admin_reason text default 'Admin LE adjustment')
returns public.stables language plpgsql security definer set search_path=public as $$
declare result stables;
begin
  perform require_admin();
  if adjustment=0 then raise exception 'Adjustment cannot be zero'; end if;
  update stables set balance=balance+adjustment where id=target_stable and balance+adjustment>=0 returning * into result;
  if not found then raise exception 'Stable not found or adjustment would create a negative balance'; end if;
  insert into currency_ledger(stable_id,amount,reason) values(target_stable,adjustment,left(coalesce(nullif(trim(admin_reason),''),'Admin LE adjustment'),200));
  return result;
end $$;

create or replace function public.admin_create_custom_horse(target_owner uuid,horse_name text,horse_species text,horse_breed text,horse_sex text,horse_age_years numeric,horse_color text,horse_stats jsonb,horse_genetics jsonb default '{}',horse_image_url text default '',horse_traits jsonb default '[]')
returns public.horses language plpgsql security definer set search_path=public as $$
declare result horses;stat record;
begin
  perform require_admin();
  if not exists(select 1 from stables where id=target_owner) then raise exception 'Owner stable not found'; end if;
  if length(trim(horse_name)) not between 1 and 80 or length(trim(horse_breed)) not between 1 and 80 or length(trim(horse_species)) not between 1 and 80 then raise exception 'Name, species, and breed are required'; end if;
  if horse_sex not in ('Mare','Stallion') then raise exception 'Sex must be Mare or Stallion'; end if;
  if horse_age_years<0 or horse_age_years>100 then raise exception 'Age must be between 0 and 100'; end if;
  for stat in select key from stat_definitions where active loop
    if jsonb_typeof(horse_stats->stat.key)<>'number' or (horse_stats->>stat.key)::numeric<0 or (horse_stats->>stat.key)::numeric>1000000 then raise exception 'Every stat must be a number between 0 and 1,000,000'; end if;
  end loop;
  insert into horses(owner_id,name,species,breed,sex,color,origin,birth_date,stats,genetics,breed_composition,image_url,custom_traits,is_admin_custom)
  values(target_owner,trim(horse_name),trim(horse_species),trim(horse_breed),horse_sex::horse_sex,coalesce(nullif(trim(horse_color),''),'Custom'),'Admin Custom',now()-(interval '1 day'*(horse_age_years*365.25/30)),horse_stats,coalesce(horse_genetics,'{}'),jsonb_build_object(trim(horse_breed),1),left(coalesce(horse_image_url,''),2048),coalesce(horse_traits,'[]'),true)
  returning * into result;
  return result;
end $$;

create or replace function public.owner_set_admin(target_stable uuid,make_admin boolean)
returns public.stables language plpgsql security definer set search_path=public as $$
declare result stables;caller_number bigint;
begin
  select account_number into caller_number from stables where id=auth.uid();
  if caller_number<>1 then raise exception 'Only the Legacy Equine owner account can designate administrators'; end if;
  if target_stable=auth.uid() and not make_admin then raise exception 'The owner account cannot remove its own administrator access'; end if;
  update stables set is_admin=make_admin where id=target_stable returning * into result;
  if not found then raise exception 'Stable not found'; end if;
  return result;
end $$;

revoke all on function public.require_admin(),public.admin_list_stables(),public.admin_adjust_balance(uuid,bigint,text),public.admin_create_custom_horse(uuid,text,text,text,text,numeric,text,jsonb,jsonb,text,jsonb),public.owner_set_admin(uuid,boolean) from public;
grant execute on function public.admin_list_stables(),public.admin_adjust_balance(uuid,bigint,text),public.admin_create_custom_horse(uuid,text,text,text,text,numeric,text,jsonb,jsonb,text,jsonb),public.owner_set_admin(uuid,boolean) to authenticated;
