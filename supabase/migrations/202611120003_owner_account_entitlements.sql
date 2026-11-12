-- Owner-managed Brand access and complimentary subscriber upgrades.
-- Paid subscriptions and complimentary grants converge in the same capability resolver.

create or replace function public.commerce_capabilities(p_account uuid default auth.uid())
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  s stables;
  paid_subscription boolean;
  legacy_subscription boolean;
  complimentary_subscription boolean;
  subscriber boolean;
  profession_slots integer;
  feed_bonus integer;
  stall_bonus bigint;
  owner_unlimited boolean;
  subscription_source text;
begin
  select * into s from stables where id=p_account;
  if not found then return null;end if;

  owner_unlimited:=s.account_number=1;
  paid_subscription:=exists(
    select 1 from commerce_subscriptions cs
    where cs.account_id=s.id and cs.mode='production' and cs.status='active'
      and cs.effective_at<=now() and(cs.end_at is null or cs.end_at>now())
  );
  legacy_subscription:=exists(
    select 1 from stable_subscriptions ss
    where ss.stable_id=s.id and ss.status='active' and ss.starts_at<=now()
      and(ss.ends_at is null or ss.ends_at>now())
  );
  complimentary_subscription:=exists(
    select 1 from account_entitlement_grants g
    where g.account_id=s.id and g.entitlement_key='subscription_active'
      and g.source_type='owner_grant' and g.status='active' and g.starts_at<=now()
      and(g.ends_at is null or g.ends_at>now())
      and coalesce((g.value->>'active')::boolean,true)
  );
  subscriber:=paid_subscription or legacy_subscription or complimentary_subscription;
  subscription_source:=case
    when paid_subscription then 'paid'
    when legacy_subscription then 'paid_or_legacy'
    when complimentary_subscription then 'owner_grant'
    else 'none'
  end;

  profession_slots:=case when owner_unlimited then null when subscriber then 2 else 1 end;
  feed_bonus:=case when subscriber then 5 else 0 end;
  select coalesce(sum(quantity),0) into stall_bonus
  from stable_capacity_allocations
  where stable_id=s.id and source='purchased' and status='active';

  return jsonb_build_object(
    'subscription_active',subscriber,
    'subscription_source',subscription_source,
    'paid_subscription_active',paid_subscription or legacy_subscription,
    'complimentary_subscription_active',complimentary_subscription,
    'subscription_status',case when subscriber then 'active' else coalesce(
      (select cs.status from commerce_subscriptions cs where cs.account_id=s.id and cs.mode='production' order by cs.updated_at desc limit 1),
      'expired'
    )end,
    'profession_career_slots',profession_slots,
    'profession_career_slots_unlimited',owner_unlimited,
    'feed_storage_bonus',feed_bonus,
    'feed_storage_unlimited',owner_unlimited,
    'permanent_purchased_stalls',stall_bonus,
    'owner_unlimited',owner_unlimited
  );
end$$;

create or replace function public.owner_account_entitlement_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  perform require_super_admin();
  return jsonb_build_object('accounts',coalesce((
    select jsonb_agg(jsonb_build_object(
      'stable_id',s.id,
      'account_number',s.account_number,
      'name',s.name,
      'username',s.username,
      'is_admin',s.is_admin,
      'brand_code',b.code,
      'brand_owner_granted',coalesce(bp.granted,false),
      'brand_permanent',coalesce(bp.permanent,false),
      'brand_effective',has_brand_privilege(s.id),
      'brand_source',case
        when s.account_number=1 then 'owner'
        when coalesce(bp.granted,false) then 'owner_grant'
        when is_active_subscriber(s.id) then 'paid_or_membership'
        else 'none'
      end,
      'membership_active',coalesce((commerce_capabilities(s.id)->>'subscription_active')::boolean,false),
      'membership_source',commerce_capabilities(s.id)->>'subscription_source',
      'paid_membership_active',coalesce((commerce_capabilities(s.id)->>'paid_subscription_active')::boolean,false),
      'complimentary_membership_active',coalesce((commerce_capabilities(s.id)->>'complimentary_subscription_active')::boolean,false),
      'complimentary_membership_ends_at',(
        select g.ends_at from account_entitlement_grants g
        where g.account_id=s.id and g.entitlement_key='subscription_active'
          and g.source_type='owner_grant' and g.status='active'
          and g.starts_at<=now() and(g.ends_at is null or g.ends_at>now())
        order by g.created_at desc limit 1
      )
    ) order by s.account_number)
    from stables s
    left join stable_brand_privileges bp on bp.stable_id=s.id
    left join stable_brands b on b.stable_id=s.id
  ),'[]'::jsonb));
end$$;

create or replace function public.owner_set_account_brand_access(
  p_stable uuid,p_granted boolean,p_reason text default 'Owner Brand access decision'
)returns void
language plpgsql
security definer
set search_path=public
as $$
declare account_no bigint;
begin
  perform require_super_admin();
  select account_number into account_no from stables where id=p_stable;
  if account_no is null then raise exception 'Account not found';end if;
  if account_no=1 and not p_granted then raise exception 'Owner Account #1 Brand access is permanent';end if;

  insert into stable_brand_privileges(stable_id,granted,permanent,reason,granted_by)
  values(p_stable,p_granted,p_granted,left(coalesce(nullif(trim(p_reason),''),'Owner Brand access decision'),300),auth.uid())
  on conflict(stable_id)do update set
    granted=excluded.granted,permanent=excluded.permanent,reason=excluded.reason,
    granted_by=auth.uid(),updated_at=now();
  insert into stable_brand_audit(stable_id,actor_id,action,new_values,reason)
  values(p_stable,auth.uid(),'brand_privilege_changed',jsonb_build_object('granted',p_granted,'permanent',p_granted),left(coalesce(p_reason,''),300));
  insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)
  values(auth.uid(),case when p_granted then 'account.brand_access_granted' else 'account.brand_access_revoked' end,'accounts','stable',p_stable,
    jsonb_build_object('granted',p_granted,'reason',left(coalesce(p_reason,''),300)));
end$$;

create or replace function public.owner_set_complimentary_membership(
  p_stable uuid,p_granted boolean,p_reason text default 'Owner complimentary membership',p_ends_at timestamptz default null
)returns void
language plpgsql
security definer
set search_path=public
as $$
declare grant_id uuid:=gen_random_uuid();before_value jsonb;after_value jsonb;
begin
  perform require_super_admin();
  if not exists(select 1 from stables where id=p_stable)then raise exception 'Account not found';end if;
  if p_granted and p_ends_at is not null and p_ends_at<=now()then raise exception 'Membership end date must be in the future';end if;

  select jsonb_build_object('active',true,'ends_at',g.ends_at) into before_value
  from account_entitlement_grants g
  where g.account_id=p_stable and g.entitlement_key='subscription_active'
    and g.source_type='owner_grant' and g.status='active'
  order by g.created_at desc limit 1;

  update account_entitlement_grants set status='reversed'
  where account_id=p_stable and entitlement_key='subscription_active'
    and source_type='owner_grant' and status='active';

  if p_granted then
    after_value:=jsonb_build_object('active',true,'membership','subscriber','ends_at',p_ends_at);
    insert into account_entitlement_grants(id,account_id,entitlement_key,grant_type,value,source_type,source_id,starts_at,ends_at,status)
    values(grant_id,p_stable,'subscription_active',case when p_ends_at is null then'permanent'else'temporary'end,
      after_value,'owner_grant',grant_id,now(),p_ends_at,'active');
  else
    after_value:=jsonb_build_object('active',false);
  end if;

  insert into commerce_entitlement_history(account_id,entitlement_key,action,grant_type,source_type,source_id,before_value,after_value,mode,actor_id)
  values(p_stable,'subscription_active',case when p_granted then'granted'else'revoked'end,
    case when p_ends_at is null then'permanent'else'temporary'end,'owner_grant',case when p_granted then grant_id else null end,
    before_value,after_value,'production',auth.uid());
  insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)
  values(auth.uid(),case when p_granted then'account.complimentary_membership_granted'else'account.complimentary_membership_revoked'end,
    'accounts','stable',p_stable,jsonb_build_object('ends_at',p_ends_at,'reason',left(coalesce(p_reason,''),300),'paid_subscription_unchanged',true));
end$$;

revoke all on function public.owner_account_entitlement_workspace(),public.owner_set_account_brand_access(uuid,boolean,text),public.owner_set_complimentary_membership(uuid,boolean,text,timestamptz) from public,anon;
grant execute on function public.owner_account_entitlement_workspace(),public.owner_set_account_brand_access(uuid,boolean,text),public.owner_set_complimentary_membership(uuid,boolean,text,timestamptz) to authenticated;

