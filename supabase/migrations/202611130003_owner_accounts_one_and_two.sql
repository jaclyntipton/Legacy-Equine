-- Owner Accounts #1 and #2 are the same real-world Owner and retain identical
-- permanent Owner/Super Admin access. This is intentionally account-number
-- based so role/default migrations cannot silently remove the entitlement.
update public.stables
set is_admin=true,is_super_admin=true
where account_number in(1,2);

create or replace function public.is_owner_account(p_stable uuid default auth.uid())returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from stables where id=p_stable and account_number in(1,2))
$$;

create or replace function public.owner_set_admin_permissions(p_stable uuid,p_permissions text[])returns void
language plpgsql security definer set search_path=public as $$begin
 if not public.is_owner_account()then raise exception'Owner access required';end if;
 if exists(select 1 from stables where id=p_stable and account_number in(1,2))then raise exception'Owner permissions are implicit';end if;
 update stables set is_admin=true where id=p_stable;
 delete from admin_permission_grants where stable_id=p_stable;
 insert into admin_permission_grants(stable_id,permission,granted_by)select p_stable,p,auth.uid()from unnest(p_permissions)p;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'permissions.updated','accounts','stable',p_stable::text,jsonb_build_object('permissions',p_permissions));
end$$;

revoke all on function public.is_owner_account(uuid),public.owner_set_admin_permissions(uuid,text[])from public,anon;
grant execute on function public.is_owner_account(uuid),public.owner_set_admin_permissions(uuid,text[])to authenticated;
