-- Provider-neutral commerce readiness. Live payment processing remains disabled.
create table if not exists public.commerce_config(
 id boolean primary key default true check(id),live_payments_enabled boolean not null default false,
 test_mode_enabled boolean not null default true,updated_at timestamptz not null default now(),updated_by uuid references public.stables(id)
);
insert into public.commerce_config(id,live_payments_enabled,test_mode_enabled)values(true,false,true)on conflict(id)do update set live_payments_enabled=false;

create table if not exists public.commerce_products(
 product_id text primary key,name text not null,description text not null default '',
 purchase_type text not null check(purchase_type in('one_time','recurring_subscription','consumable','permanent_entitlement')),
 price_minor integer not null check(price_minor>=0),currency text not null check(currency~'^[A-Z]{3}$'),active boolean not null default false,
 entitlement_effect jsonb not null default '{}',effective_at timestamptz not null default now(),version integer not null default 1 check(version>0),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
insert into public.commerce_products(product_id,name,description,purchase_type,price_minor,currency,active,entitlement_effect)values
 ('subscription_monthly','Legacy Equine Subscription','Future recurring subscription entitlement. Checkout is not active.','recurring_subscription',0,'USD',false,'{"subscription_active":true,"profession_career_slots":2,"feed_storage_bonus":5}'::jsonb),
 ('permanent_stalls_5','5 Permanent Stalls','Future permanent +5 Stable stall entitlement. Checkout is not active.','permanent_entitlement',0,'USD',false,'{"stall_capacity":5,"permanent":true}'::jsonb),
 ('led_package_future','LE Dollars Package','Future game-currency package. LED is never redeemable for cash.','consumable',0,'USD',false,'{"led_credit":0,"cash_redeemable":false}'::jsonb)
on conflict(product_id)do update set active=false,description=excluded.description,entitlement_effect=excluded.entitlement_effect,updated_at=now();

create table if not exists public.commerce_orders(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references public.stables(id),product_id text not null references public.commerce_products(product_id),
 amount_minor integer not null check(amount_minor>=0),currency text not null check(currency~'^[A-Z]{3}$'),provider text not null,
 external_transaction_ref text,external_subscription_ref text,status text not null default 'pending' check(status in('pending','confirmed','failed','refunded','reversed','review_required','test_confirmed')),
 mode text not null check(mode in('test','production')),idempotency_ref text not null,product_version integer not null,
 product_effect_snapshot jsonb not null,created_at timestamptz not null default now(),completed_at timestamptz,refunded_at timestamptz,
 unique(provider,mode,idempotency_ref),unique(provider,mode,external_transaction_ref)
);
create table if not exists public.commerce_provider_events(
 id uuid primary key default gen_random_uuid(),provider text not null,provider_event_ref text not null,mode text not null check(mode in('test','production')),
 event_type text not null,status text not null default 'received' check(status in('received','processed','failed','ignored')),
 order_id uuid references public.commerce_orders(id),payload_metadata jsonb not null default '{}',error_message text,received_at timestamptz not null default now(),processed_at timestamptz,
 unique(provider,mode,provider_event_ref)
);
create table if not exists public.commerce_subscriptions(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references public.stables(id),product_id text not null references public.commerce_products(product_id),
 provider text not null,external_subscription_ref text,mode text not null check(mode in('test','production')),
 status text not null check(status in('active','past_due','canceled','expired')),effective_at timestamptz not null,end_at timestamptz,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(provider,mode,external_subscription_ref)
);
create table if not exists public.account_entitlement_grants(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references public.stables(id),entitlement_key text not null,
 grant_type text not null check(grant_type in('permanent','temporary')),value jsonb not null,source_type text not null,
 source_id uuid,starts_at timestamptz not null default now(),ends_at timestamptz,status text not null default 'active' check(status in('active','expired','reversed')),
 created_at timestamptz not null default now(),unique(account_id,entitlement_key,source_type,source_id)
);
create table if not exists public.commerce_entitlement_history(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references public.stables(id),entitlement_key text not null,
 action text not null,grant_type text not null,source_type text not null,source_id uuid,before_value jsonb,after_value jsonb,
 mode text not null check(mode in('test','production')),actor_id uuid references public.stables(id),created_at timestamptz not null default now()
);
create table if not exists public.commerce_reversal_reviews(
 id uuid primary key default gen_random_uuid(),order_id uuid not null references public.commerce_orders(id),account_id uuid not null references public.stables(id),
 reason text not null,affected_entitlement text,status text not null default 'open' check(status in('open','resolved','dismissed')),
 resolution text,created_at timestamptz not null default now(),resolved_at timestamptz,resolved_by uuid references public.stables(id)
);
create table if not exists public.commerce_audit_log(
 id uuid primary key default gen_random_uuid(),account_id uuid references public.stables(id),order_id uuid references public.commerce_orders(id),
 event_id uuid references public.commerce_provider_events(id),action text not null,mode text not null check(mode in('test','production')),
 details jsonb not null default '{}',created_at timestamptz not null default now()
);

alter table public.commerce_config enable row level security;alter table public.commerce_products enable row level security;alter table public.commerce_orders enable row level security;
alter table public.commerce_provider_events enable row level security;alter table public.commerce_subscriptions enable row level security;alter table public.account_entitlement_grants enable row level security;
alter table public.commerce_entitlement_history enable row level security;alter table public.commerce_reversal_reviews enable row level security;alter table public.commerce_audit_log enable row level security;
create policy "inactive commerce catalog readable" on public.commerce_products for select using(true);
create policy "own commerce orders readable" on public.commerce_orders for select using(account_id=auth.uid());
create policy "own commerce subscriptions readable" on public.commerce_subscriptions for select using(account_id=auth.uid());
create policy "own entitlement grants readable" on public.account_entitlement_grants for select using(account_id=auth.uid());
create policy "own entitlement history readable" on public.commerce_entitlement_history for select using(account_id=auth.uid());

create or replace function public.commerce_capabilities(p_account uuid default auth.uid())returns jsonb language plpgsql stable security definer set search_path=public as $$
declare s stables;subscriber boolean;profession_slots integer;feed_bonus integer;stall_bonus bigint;owner_unlimited boolean;
begin
 select * into s from stables where id=p_account;if not found then return null;end if;owner_unlimited:=s.account_number=1;
 subscriber:=exists(select 1 from commerce_subscriptions cs where cs.account_id=s.id and cs.mode='production'and cs.status='active'and cs.effective_at<=now()and(cs.end_at is null or cs.end_at>now()))
  or exists(select 1 from stable_subscriptions ss where ss.stable_id=s.id and ss.status='active'and ss.starts_at<=now()and(ss.ends_at is null or ss.ends_at>now()));
 profession_slots:=case when owner_unlimited then null when subscriber then 2 else 1 end;feed_bonus:=case when subscriber then 5 else 0 end;
 select coalesce(sum(quantity),0)into stall_bonus from stable_capacity_allocations where stable_id=s.id and source='purchased'and status='active';
 return jsonb_build_object('subscription_active',subscriber,'subscription_status',coalesce((select cs.status from commerce_subscriptions cs where cs.account_id=s.id and cs.mode='production'order by cs.updated_at desc limit 1),case when subscriber then'active'else'expired'end),
  'profession_career_slots',profession_slots,'profession_career_slots_unlimited',owner_unlimited,'feed_storage_bonus',feed_bonus,'feed_storage_unlimited',owner_unlimited,
  'permanent_purchased_stalls',stall_bonus,'owner_unlimited',owner_unlimited);
end$$;

create or replace function public.is_active_subscriber(p_stable uuid,p_at timestamptz default now())returns boolean language sql stable security definer set search_path=public as $$
 select coalesce((commerce_capabilities(p_stable)->>'subscription_active')::boolean,false)
$$;
create or replace function public.profession_career_slot_limit(p_stable uuid default auth.uid())returns integer language sql stable security definer set search_path=public as $$
 select case when(coalesce((commerce_capabilities(p_stable)->>'profession_career_slots_unlimited')::boolean,false))then null else(commerce_capabilities(p_stable)->>'profession_career_slots')::integer end
$$;

create or replace function public.feed_storage_summary(p_stable uuid default auth.uid())returns jsonb language plpgsql stable security definer set search_path=public as $$
declare s stables;cfg feed_system_config;caps jsonb;lvl integer;used integer;cap integer;unlim boolean;bonus integer;
begin select * into s from stables where id=p_stable;if not found then return null;end if;select * into cfg from feed_system_config where id=true;caps:=commerce_capabilities(s.id);
 lvl:=account_level_for_xp(s.account_xp);unlim:=(caps->>'feed_storage_unlimited')::boolean;bonus:=(caps->>'feed_storage_bonus')::integer;
 select count(*)into used from player_store_items i join store_products p on p.id=i.product_id where i.stable_id=s.id and i.consumed_at is null and p.department='feed';
 cap:=cfg.base_storage+floor(lvl/5.0)::integer*cfg.storage_per_five_levels+bonus;
 return jsonb_build_object('used',used,'capacity',case when unlim then null else cap end,'unlimited',unlim,'over_capacity',not unlim and used>cap,'available',case when unlim then null else greatest(cap-used,0)end,'level',lvl,'subscriber',(caps->>'subscription_active')::boolean,'subscriber_bonus',bonus);
end$$;

create or replace function public.confirm_commerce_order(p_order uuid,p_provider text,p_event_ref text,p_external_transaction text,p_event_type text default 'payment.confirmed')returns jsonb language plpgsql security definer set search_path=public as $$
declare o commerce_orders;product commerce_products;cfg commerce_config;e commerce_provider_events;effect jsonb;qty integer;
begin select * into cfg from commerce_config where id=true;select * into o from commerce_orders where id=p_order for update;if not found then raise exception'Commerce order not found';end if;
 if o.provider<>p_provider then raise exception'Provider mismatch';end if;if o.mode='production'and not cfg.live_payments_enabled then raise exception'Live commerce is disabled';end if;if o.mode='test'and not cfg.test_mode_enabled then raise exception'Commerce Test Mode is disabled';end if;
 insert into commerce_provider_events(provider,provider_event_ref,mode,event_type,order_id)values(p_provider,p_event_ref,o.mode,p_event_type,o.id)on conflict(provider,mode,provider_event_ref)do nothing returning * into e;
 if not found then return jsonb_build_object('duplicate',true,'order_id',o.id,'status',o.status);end if;
 if o.status in('confirmed','test_confirmed')then update commerce_provider_events set status='ignored',processed_at=now()where id=e.id;return jsonb_build_object('duplicate',true,'order_id',o.id,'status',o.status);end if;
 if o.status<>'pending'then raise exception'Order is not pending';end if;effect:=o.product_effect_snapshot;
 if o.mode='test'then update commerce_orders set status='test_confirmed',external_transaction_ref=p_external_transaction,completed_at=now()where id=o.id;update commerce_provider_events set status='processed',processed_at=now()where id=e.id;insert into commerce_audit_log(account_id,order_id,event_id,action,mode,details)values(o.account_id,o.id,e.id,'test_confirmation_no_gameplay_effect','test',effect);return jsonb_build_object('duplicate',false,'test',true,'effects_applied',false);end if;
 select * into product from commerce_products where product_id=o.product_id;if not product.active then raise exception'Commerce product is inactive';end if;
 if product.purchase_type='recurring_subscription'then insert into commerce_subscriptions(account_id,product_id,provider,external_subscription_ref,mode,status,effective_at)values(o.account_id,o.product_id,o.provider,o.external_subscription_ref,'production','active',now());
 elsif coalesce((effect->>'stall_capacity')::integer,0)>0 then qty:=(effect->>'stall_capacity')::integer;insert into stable_capacity_allocations(stable_id,source,quantity,payment_reference,reason)values(o.account_id,'purchased',qty,o.id::text,'Commerce permanent stall entitlement');
 elsif coalesce((effect->>'led_credit')::integer,0)>0 then qty:=(effect->>'led_credit')::integer;update stables set balance=balance+qty where id=o.account_id;insert into currency_ledger(stable_id,amount,reason)values(o.account_id,qty,'Confirmed commerce LED purchase · '||o.id::text);end if;
 insert into commerce_entitlement_history(account_id,entitlement_key,action,grant_type,source_type,source_id,after_value,mode)values(o.account_id,o.product_id,'granted',case when product.purchase_type='permanent_entitlement'then'permanent'else'temporary'end,'commerce_order',o.id,effect,'production');
 update commerce_orders set status='confirmed',external_transaction_ref=p_external_transaction,completed_at=now()where id=o.id;update commerce_provider_events set status='processed',processed_at=now()where id=e.id;
 insert into commerce_audit_log(account_id,order_id,event_id,action,mode,details)values(o.account_id,o.id,e.id,'order_confirmed','production',effect);return jsonb_build_object('duplicate',false,'test',false,'effects_applied',true);
end$$;

create or replace function public.record_commerce_reversal(p_order uuid,p_event_ref text,p_reason text)returns void language plpgsql security definer set search_path=public as $$
declare o commerce_orders;effect jsonb;begin select * into o from commerce_orders where id=p_order for update;if not found then raise exception'Order not found';end if;if o.status in('refunded','reversed','review_required')then return;end if;effect:=o.product_effect_snapshot;
 if effect?'subscription_active'then update commerce_subscriptions set status='canceled',end_at=now(),updated_at=now()where account_id=o.account_id and product_id=o.product_id and status in('active','past_due');update commerce_orders set status='refunded',refunded_at=now()where id=o.id;
 else update commerce_orders set status='review_required',refunded_at=now()where id=o.id;insert into commerce_reversal_reviews(order_id,account_id,reason,affected_entitlement)values(o.id,o.account_id,left(p_reason,500),o.product_id);end if;
 insert into commerce_audit_log(account_id,order_id,action,mode,details)values(o.account_id,o.id,'refund_or_reversal_received',o.mode,jsonb_build_object('provider_event',p_event_ref,'reason',left(p_reason,500),'non_destructive',true));
end$$;

create or replace function public.admin_commerce_workspace()returns jsonb language plpgsql stable security definer set search_path=public as $$begin perform require_super_admin();return jsonb_build_object(
 'config',(select to_jsonb(c)from commerce_config c where id=true),'products',coalesce((select jsonb_agg(to_jsonb(p)order by p.product_id)from commerce_products p),'[]'::jsonb),
 'orders',coalesce((select jsonb_agg(to_jsonb(o)order by o.created_at desc)from(select * from commerce_orders order by created_at desc limit 100)o),'[]'::jsonb),
 'subscriptions',coalesce((select jsonb_agg(to_jsonb(s)order by s.updated_at desc)from(select * from commerce_subscriptions order by updated_at desc limit 100)s),'[]'::jsonb),
 'entitlements',coalesce((select jsonb_agg(to_jsonb(h)order by h.created_at desc)from(select * from commerce_entitlement_history order by created_at desc limit 100)h),'[]'::jsonb),
 'failures',coalesce((select jsonb_agg(to_jsonb(e)order by e.received_at desc)from(select * from commerce_provider_events where status='failed'order by received_at desc limit 100)e),'[]'::jsonb),
 'reversals',coalesce((select jsonb_agg(to_jsonb(r)order by r.created_at desc)from(select * from commerce_reversal_reviews order by created_at desc limit 100)r),'[]'::jsonb),
 'audit',coalesce((select jsonb_agg(to_jsonb(a)order by a.created_at desc)from(select * from commerce_audit_log order by created_at desc limit 100)a),'[]'::jsonb));end$$;

update public.stall_packages set active=false;
revoke all on function public.confirm_commerce_order(uuid,text,text,text,text),public.record_commerce_reversal(uuid,text,text)from public,anon,authenticated;
grant execute on function public.confirm_commerce_order(uuid,text,text,text,text),public.record_commerce_reversal(uuid,text,text)to service_role;
revoke all on function public.commerce_capabilities(uuid),public.profession_career_slot_limit(uuid),public.admin_commerce_workspace()from public;
grant execute on function public.commerce_capabilities(uuid),public.profession_career_slot_limit(uuid),public.admin_commerce_workspace()to authenticated;
