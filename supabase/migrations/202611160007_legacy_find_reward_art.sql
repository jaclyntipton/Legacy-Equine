alter table public.legacy_find_rewards add column if not exists image_url text;

update public.legacy_find_rewards set image_url=case id
 when 'worn_glove' then '/game-art/objects/riding-glove.png'
 when 'lucky_horseshoe' then '/game-art/objects/lucky-horseshoe.png'
 when 'boot_polish' then '/game-art/objects/boot-polish-tin.png'
 when 'peppermint' then '/game-art/objects/peppermint-treats.png'
 when 'vet_wrap' then '/game-art/objects/vet-wrap.png'
 when 'braided_crop' then '/game-art/objects/braided-riding-crop.png'
 when 'hay_sample' then '/game-art/objects/hay-bundle-sample.png'
 when 'leg_boots' then '/game-art/objects/quality-leg-boots.png'
 when 'led_small' then '/game-art/objects/led-coins-small.png'
 when 'led_medium' then '/game-art/objects/led-coin-pouch.png'
 when 'led_rare' then '/game-art/objects/led-treasure-box.png'
 else image_url end;

create or replace function public.try_legacy_find(p_location text,p_context_id uuid,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare cfg legacy_find_config;reward legacy_find_rewards;prior jsonb;answer jsonb;item uuid;amount integer;today_start timestamptz;last_award timestamptz;misses_since_award integer;allowed constant text[]:=array['news','my_stable','horse','public_stable','public_player','store','marketplace','shows','training','professions','community','bank','sanctuary'];
begin
 if auth.uid()is null then raise exception 'Sign in required';end if;if p_request is null then raise exception 'Request ID required';end if;if not(p_location=any(allowed))then raise exception 'This location does not support Legacy Finds';end if;perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,4319));select a.response into prior from legacy_find_attempts a where a.request_id=p_request and a.stable_id=auth.uid();if prior is not null then return prior;end if;select*into cfg from legacy_find_config where id=true;
 if not found or not cfg.enabled then answer:=jsonb_build_object('status','disabled');insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'disabled',answer);return answer;end if;
 if exists(select 1 from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='awarded'and a.created_at>now()-make_interval(mins=>cfg.cooldown_minutes))or exists(select 1 from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='not_found'and a.created_at>now()-make_interval(mins=>cfg.miss_cooldown_minutes))then answer:=jsonb_build_object('status','cooldown');insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'cooldown',answer);return answer;end if;
 today_start:=date_trunc('day',now()at time zone'America/New_York')at time zone'America/New_York';if(select count(*)from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='awarded'and a.created_at>=today_start)>=cfg.daily_award_limit then answer:=jsonb_build_object('status','daily_limit');insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'daily_limit',answer);return answer;end if;
 select max(a.created_at)into last_award from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='awarded';select count(*)into misses_since_award from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='not_found'and a.created_at>greatest(coalesce(last_award,'epoch'::timestamptz),today_start);if misses_since_award<cfg.guarantee_after_attempts-1 and random()>cfg.discovery_chance then answer:=jsonb_build_object('status','not_found');insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'not_found',answer);return answer;end if;
 select r.*into reward from legacy_find_rewards r where r.active order by-ln(greatest(random(),.0000001))/r.weight limit 1;if reward.reward_type='led'then amount:=reward.led_min+floor(random()*(reward.led_max-reward.led_min+1))::integer;update stables set balance=balance+amount where id=auth.uid();insert into currency_ledger(stable_id,amount,reason)values(auth.uid(),amount,'Legacy Find — '||reward.name);else insert into player_store_items(stable_id,product_id,purchased_price)values(auth.uid(),reward.product_id,0)returning id into item;end if;
 answer:=jsonb_build_object('status','awarded','reward_id',reward.id,'reward_type',reward.reward_type,'name',reward.name,'description',reward.description,'rarity',reward.rarity,'icon',reward.icon,'image_url',reward.image_url,'destination',reward.destination,'led_amount',amount,'item_id',item,'location',p_location);insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,reward_id,led_amount,item_id,response)values(p_request,auth.uid(),p_location,p_context_id,'awarded',reward.id,amount,item,answer);return answer;
end$$;

revoke all on function public.try_legacy_find(text,uuid,uuid)from public,anon;
grant execute on function public.try_legacy_find(text,uuid,uuid)to authenticated;
