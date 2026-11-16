-- Owner Accounts #1 and #2 receive a private Legacy Finds testing cadence.
-- This is account-specific and is not inherited through Admin or moderator roles.

alter table public.legacy_find_config
 add column if not exists owner_discovery_chance numeric not null default .60 check(owner_discovery_chance between 0 and 1),
 add column if not exists owner_award_cooldown_minutes integer not null default 0 check(owner_award_cooldown_minutes between 0 and 1440),
 add column if not exists owner_miss_cooldown_minutes integer not null default 1 check(owner_miss_cooldown_minutes between 1 and 1440),
 add column if not exists owner_daily_award_limit integer not null default 20 check(owner_daily_award_limit between 1 and 100),
 add column if not exists owner_guarantee_after_attempts integer not null default 3 check(owner_guarantee_after_attempts between 1 and 100);

update public.legacy_find_config set owner_discovery_chance=.60,owner_award_cooldown_minutes=0,owner_miss_cooldown_minutes=1,owner_daily_award_limit=20,owner_guarantee_after_attempts=3,updated_at=now()where id=true;

create or replace function public.try_legacy_find(p_location text,p_context_id uuid,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 cfg legacy_find_config;reward legacy_find_rewards;prior jsonb;answer jsonb;item uuid;amount integer;
 today_start timestamptz;last_award timestamptz;misses_since_award integer;is_owner_account boolean;
 effective_chance numeric;effective_award_cooldown integer;effective_miss_cooldown integer;effective_daily_limit integer;effective_guarantee integer;
 allowed constant text[]:=array['news','my_stable','horse','public_stable','public_player','store','marketplace','shows','training','professions','community','bank','sanctuary'];
begin
 if auth.uid()is null then raise exception 'Sign in required';end if;
 if p_request is null then raise exception 'Request ID required';end if;
 if not(p_location=any(allowed))then raise exception 'This location does not support Legacy Finds';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,4319));
 select a.response into prior from legacy_find_attempts a where a.request_id=p_request and a.stable_id=auth.uid();
 if prior is not null then return prior;end if;
 select*into cfg from legacy_find_config where id=true;
 if not found or not cfg.enabled then
  answer:=jsonb_build_object('status','disabled');
  insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'disabled',answer);
  return answer;
 end if;
 select exists(select 1 from stables s where s.id=auth.uid()and s.account_number in(1,2))into is_owner_account;
 effective_chance:=case when is_owner_account then cfg.owner_discovery_chance else cfg.discovery_chance end;
 effective_award_cooldown:=case when is_owner_account then cfg.owner_award_cooldown_minutes else cfg.cooldown_minutes end;
 effective_miss_cooldown:=case when is_owner_account then cfg.owner_miss_cooldown_minutes else cfg.miss_cooldown_minutes end;
 effective_daily_limit:=case when is_owner_account then cfg.owner_daily_award_limit else cfg.daily_award_limit end;
 effective_guarantee:=case when is_owner_account then cfg.owner_guarantee_after_attempts else cfg.guarantee_after_attempts end;
 if(effective_award_cooldown>0 and exists(select 1 from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='awarded'and a.created_at>now()-make_interval(mins=>effective_award_cooldown)))or exists(select 1 from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='not_found'and a.created_at>now()-make_interval(mins=>effective_miss_cooldown))then
  answer:=jsonb_build_object('status','cooldown');
  insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'cooldown',answer);
  return answer;
 end if;
 today_start:=date_trunc('day',now()at time zone'America/New_York')at time zone'America/New_York';
 if(select count(*)from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='awarded'and a.created_at>=today_start)>=effective_daily_limit then
  answer:=jsonb_build_object('status','daily_limit');
  insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'daily_limit',answer);
  return answer;
 end if;
 select max(a.created_at)into last_award from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='awarded';
 select count(*)into misses_since_award from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='not_found'and a.created_at>greatest(coalesce(last_award,'epoch'::timestamptz),today_start);
 if misses_since_award<effective_guarantee-1 and random()>effective_chance then
  answer:=jsonb_build_object('status','not_found');
  insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'not_found',answer);
  return answer;
 end if;
 select r.*into reward from legacy_find_rewards r where r.active order by-ln(greatest(random(),.0000001))/r.weight limit 1;
 if reward.reward_type='led'then
  amount:=reward.led_min+floor(random()*(reward.led_max-reward.led_min+1))::integer;
  update stables set balance=balance+amount where id=auth.uid();
  insert into currency_ledger(stable_id,amount,reason)values(auth.uid(),amount,'Legacy Find — '||reward.name);
 else
  insert into player_store_items(stable_id,product_id,purchased_price)values(auth.uid(),reward.product_id,0)returning id into item;
 end if;
 answer:=jsonb_build_object('status','awarded','reward_id',reward.id,'reward_type',reward.reward_type,'name',reward.name,'description',reward.description,'rarity',reward.rarity,'icon',reward.icon,'destination',reward.destination,'led_amount',amount,'item_id',item,'location',p_location);
 insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,reward_id,led_amount,item_id,response)values(p_request,auth.uid(),p_location,p_context_id,'awarded',reward.id,amount,item,answer);
 return answer;
end$$;

revoke all on function public.try_legacy_find(text,uuid,uuid)from public,anon;
grant execute on function public.try_legacy_find(text,uuid,uuid)to authenticated;
