create table if not exists public.admin_player_led_gifts(
 id uuid primary key default gen_random_uuid(),
 request_id uuid not null unique,
 sender_id uuid not null references public.stables(id),
 recipient_id uuid not null references public.stables(id),
 amount bigint not null check(amount>0),
 public_reason text not null,
 internal_note text,
 created_at timestamptz not null default now(),
 check(sender_id<>recipient_id)
);
alter table public.admin_player_led_gifts enable row level security;
revoke all on table public.admin_player_led_gifts from public,anon,authenticated;

create or replace function public.admin_gift_player_led(
 p_recipient uuid,
 p_amount bigint,
 p_request_id uuid,
 p_reason text,
 p_internal_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_sender public.stables;v_recipient public.stables;v_existing public.admin_player_led_gifts;v_reason text:=left(trim(coalesce(p_reason,'')),200);v_sender_ledger uuid;v_recipient_ledger uuid;
begin
 perform public.require_admin();
 if p_amount is null or p_amount<=0 then raise exception 'Gift amount must be positive';end if;
 if p_request_id is null then raise exception 'Gift request id is required';end if;
 if p_recipient is null or p_recipient=auth.uid() then raise exception 'Choose another player as the gift recipient';end if;
 if length(v_reason)<3 then raise exception 'A public gift reason is required';end if;
 perform pg_advisory_xact_lock(hashtextextended('admin_player_led_gift:'||p_request_id::text,0));
 select * into v_sender from public.stables s where s.id=auth.uid() for update;
 if not found then raise exception 'Admin player account not found';end if;
 select * into v_existing from public.admin_player_led_gifts g where g.request_id=p_request_id;
 if found then
  if v_existing.sender_id<>auth.uid() then raise exception 'Gift request belongs to another account';end if;
  return jsonb_build_object('idempotent',true,'gift_id',v_existing.id,'amount',v_existing.amount,'sender_balance_after',v_sender.balance);
 end if;
 select * into v_recipient from public.stables s where s.id=p_recipient for update;
 if not found then raise exception 'Gift recipient not found';end if;
 if v_sender.balance<p_amount then raise exception 'Your personal account has insufficient LED';end if;
 update public.stables set balance=balance-p_amount where id=v_sender.id;
 update public.stables set balance=balance+p_amount where id=v_recipient.id;
 insert into public.currency_ledger(stable_id,amount,reason) values(v_sender.id,-p_amount,'LED gift to '||coalesce(v_recipient.username,v_recipient.name)||': '||v_reason) returning id into v_sender_ledger;
 insert into public.currency_ledger(stable_id,amount,reason) values(v_recipient.id,p_amount,'LED gift from '||coalesce(v_sender.username,v_sender.name)||': '||v_reason) returning id into v_recipient_ledger;
 insert into public.admin_player_led_gifts(request_id,sender_id,recipient_id,amount,public_reason,internal_note) values(p_request_id,v_sender.id,v_recipient.id,p_amount,v_reason,nullif(left(trim(coalesce(p_internal_note,'')),500),'')) returning * into v_existing;
 insert into public.admin_audit_log(actor_id,action_type,system,target_type,target_id,details) values(v_sender.id,'economy.player_led_gift','economy','stable',v_recipient.id::text,jsonb_build_object('gift_id',v_existing.id,'request_id',p_request_id,'amount',p_amount,'sender_ledger_id',v_sender_ledger,'recipient_ledger_id',v_recipient_ledger,'sender_balance_before',v_sender.balance,'sender_balance_after',v_sender.balance-p_amount,'recipient_balance_before',v_recipient.balance,'recipient_balance_after',v_recipient.balance+p_amount,'reason',v_reason));
 return jsonb_build_object('idempotent',false,'gift_id',v_existing.id,'amount',p_amount,'sender_balance_after',v_sender.balance-p_amount,'recipient_balance_after',v_recipient.balance+p_amount);
end$$;

revoke all on function public.admin_gift_player_led(uuid,bigint,uuid,text,text) from public,anon;
grant execute on function public.admin_gift_player_led(uuid,bigint,uuid,text,text) to authenticated;
