create table if not exists public.store_purchase_requests(
 id uuid primary key default gen_random_uuid(),
 stable_id uuid not null references public.stables(id),
 request_key uuid not null,
 product_id text not null references public.store_products(id),
 unit_price integer not null,
 quantity integer not null,
 total integer not null,
 item_ids uuid[] not null default '{}',
 created_at timestamptz not null default now(),
 unique(stable_id,request_key)
);

alter table public.store_purchase_requests enable row level security;
create policy "own store purchase requests" on public.store_purchase_requests for select using(stable_id=auth.uid());

create or replace function public.purchase_store_product_bulk(p_product text,p_quantity integer,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare product store_products;s stables;i integer;ids uuid[]:='{}';new_id uuid;total integer;prior store_purchase_requests;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if p_request is null then raise exception 'Purchase request ID is required';end if;
 select * into prior from store_purchase_requests where stable_id=auth.uid()and request_key=p_request;
 if found then return jsonb_build_object('items',prior.item_ids,'quantity',prior.quantity,'unit_price',prior.unit_price,'total',prior.total,'duplicate',true);end if;
 select * into product from store_products where id=p_product and active for update;
 if not found or product.department not in('feed','tack')then raise exception 'Product unavailable';end if;
 if p_quantity<1 or(product.department='feed'and p_quantity>50)or(product.department='tack'and p_quantity>10)then raise exception 'Quantity is outside the supported range';end if;
 total:=product.price*p_quantity;
 if total<0 then raise exception 'Invalid purchase total';end if;
 select * into s from stables where id=auth.uid() for update;
 if not found then raise exception 'Create your stable first';end if;
 insert into store_purchase_requests(stable_id,request_key,product_id,unit_price,quantity,total)values(s.id,p_request,product.id,product.price,p_quantity,total)
 on conflict(stable_id,request_key)do nothing;
 if not found then select * into prior from store_purchase_requests where stable_id=s.id and request_key=p_request;return jsonb_build_object('items',prior.item_ids,'quantity',prior.quantity,'unit_price',prior.unit_price,'total',prior.total,'duplicate',true);end if;
 if s.balance<total then raise exception 'Insufficient LED balance';end if;
 update stables set balance=balance-total where id=s.id;
 insert into currency_ledger(stable_id,amount,reason)values(s.id,-total,'LE Store — '||product.name||case when p_quantity>1 then ' ×'||p_quantity else ''end);
 for i in 1..p_quantity loop
  insert into player_store_items(stable_id,product_id,purchased_price)values(s.id,product.id,product.price)returning id into new_id;
  ids:=array_append(ids,new_id);
 end loop;
 update store_purchase_requests set item_ids=ids where stable_id=s.id and request_key=p_request;
 return jsonb_build_object('items',ids,'quantity',p_quantity,'unit_price',product.price,'total',total,'balance',s.balance-total,'duplicate',false);
end$$;

revoke all on function public.purchase_store_product_bulk(text,integer,uuid)from public;
grant execute on function public.purchase_store_product_bulk(text,integer,uuid)to authenticated;
