-- Level 5 opens the player-to-player economy. Pre-Level-5 service spend cannot be laundered directly.
alter table public.progression_config add column if not exists restricted_service_provider_compensation integer not null default 50 check(restricted_service_provider_compensation>=0);

create or replace function public.has_full_economy_access(p_stable uuid default auth.uid()) returns boolean language sql stable security definer set search_path=public as $$
 select is_owner_account(p_stable) or account_level_for_xp(coalesce((select account_xp from stables where id=p_stable),0)) >= (select full_economy_level from progression_config where id=true)
$$;

create or replace function public.list_horse_for_sale(target_horse uuid,asking_price integer)
returns public.marketplace_listings language plpgsql security definer set search_path=public as $$
declare h horses;result marketplace_listings;begin
 if not has_full_economy_access() then raise exception 'The player Marketplace unlocks at Account Level 5';end if;
 if asking_price not between 1 and 1000000 then raise exception 'Price must be between 1 and 1,000,000 LE Dollars';end if;
 select * into h from horses where id=target_horse for update;if not found or h.owner_id<>auth.uid() then raise exception 'Horse not found or not owned';end if;
 insert into marketplace_listings(horse_id,seller_id,price) values(h.id,auth.uid(),asking_price) returning * into result;return result;
exception when unique_violation then raise exception 'That horse is already listed';end$$;

create or replace function public.buy_marketplace_horse(target_listing uuid) returns public.horses language plpgsql security definer set search_path=public as $$
declare item marketplace_listings;buyer stables;seller stables;h horses;begin
 if not has_full_economy_access() then raise exception 'Marketplace horse purchases unlock at Account Level 5';end if;
 select * into item from marketplace_listings where id=target_listing for update;if not found or item.status<>'active' then raise exception 'That horse is no longer available';end if;if item.seller_id=auth.uid() then raise exception 'You already own this horse';end if;
 select * into buyer from stables where id=auth.uid() for update;select * into seller from stables where id=item.seller_id for update;perform require_available_stall(buyer.id);if buyer.balance<item.price then raise exception 'Insufficient funds';end if;
 update horses set owner_id=buyer.id where id=item.horse_id and owner_id=item.seller_id and sanctuary_retired_at is null returning * into h;if not found then raise exception 'That horse is no longer available';end if;
 update horse_ownership_history set ended_at=now(),disposition='Private Sale' where horse_id=h.id and owner_id=seller.id and ended_at is null;insert into horse_ownership_history(horse_id,owner_id,acquired_at,acquisition_method,related_id) values(h.id,buyer.id,now(),'Private Sale',item.id);
 update stables set balance=balance-item.price where id=buyer.id;update stables set balance=balance+item.price where id=seller.id;update marketplace_listings set status='sold',buyer_id=buyer.id,closed_at=now() where id=item.id;
 insert into currency_ledger(stable_id,amount,reason,horse_id) values(buyer.id,-item.price,'Marketplace purchase: '||h.name,h.id),(seller.id,item.price,'Marketplace sale: '||h.name,h.id);return h;
end$$;

create or replace function public.purchase_professional_service(target_horse uuid,target_provider uuid,target_service text,request_key uuid)
returns public.horse_service_records language plpgsql security definer set search_path=public as $$
declare h horses;provider player_professions;svc service_catalog;offering player_service_offerings;client stables;result horse_service_records;last_at timestamptz;self boolean;quality text;credit numeric;provider_credit integer;restricted boolean;begin
 select * into h from horses where id=target_horse for update;if h.owner_id<>auth.uid() then raise exception 'You must own this horse';end if;select * into svc from service_catalog where id=target_service and active;
 select * into provider from player_professions where stable_id=target_provider and profession_id=svc.profession_id for update;select * into offering from player_service_offerings where stable_id=target_provider and service_id=target_service and enabled for update;
 if provider.certification_level<svc.minimum_level or not provider.available or offering.price is null then raise exception 'This service is not currently available';end if;
 select max(completed_at) into last_at from horse_service_records where horse_id=target_horse and service_id=target_service and status='completed';if last_at is not null and last_at>now()-make_interval(hours=>svc.cooldown_hours) then raise exception 'This horse is still in the service cooldown';end if;
 self:=target_provider=auth.uid();restricted:=not has_full_economy_access(auth.uid());
 if not self then
  select * into client from stables where id=auth.uid() for update;if client.balance<offering.price then raise exception 'Insufficient LED balance';end if;update stables set balance=balance-offering.price where id=auth.uid();
  provider_credit:=case when restricted then (select restricted_service_provider_compensation from progression_config where id=true) else offering.price end;
  if provider_credit>0 then update stables set balance=balance+provider_credit where id=target_provider;end if;
  insert into currency_ledger(stable_id,amount,reason,horse_id) values(auth.uid(),-offering.price,case when restricted then 'Game-controlled professional service: ' else 'Professional service: ' end||svc.name,h.id);
  if provider_credit>0 then insert into currency_ledger(stable_id,amount,reason,horse_id) values(target_provider,provider_credit,case when restricted then 'Controlled professional service compensation: ' else 'Professional service provided: ' end||svc.name,h.id);end if;
 end if;
 quality:=case provider.certification_level when 1 then 'Good' when 2 then 'Very Good' when 3 then 'Excellent' else 'Exceptional' end;credit:=case when self then .5 else 1 end;
 insert into horse_service_records(horse_id,client_id,provider_id,profession_id,service_id,provider_level,price,quality,effect,effect_expires_at,self_service,idempotency_key) values(h.id,auth.uid(),target_provider,svc.profession_id,svc.id,provider.certification_level,case when self then 0 else offering.price end,quality,svc.effect,case when svc.duration_hours>0 then now()+make_interval(hours=>svc.duration_hours) end,self,request_key) returning * into result;
 update player_professions set lifetime_client_services=lifetime_client_services+(case when self then 0 else 1 end),lifetime_self_services=lifetime_self_services+(case when self then 1 else 0 end),qualifying_credit=qualifying_credit+credit where stable_id=target_provider and profession_id=svc.profession_id;return result;
exception when unique_violation then select * into result from horse_service_records where idempotency_key=request_key;return result;end$$;

revoke all on function public.has_full_economy_access(uuid) from public;
grant execute on function public.has_full_economy_access(uuid) to authenticated;
