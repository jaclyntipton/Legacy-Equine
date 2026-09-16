-- Granular, auditable Admin Control Center authorization.
create table if not exists public.admin_roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  created_by uuid references public.stables(id),
  created_at timestamptz not null default now()
);
create table if not exists public.admin_role_permissions (
  role_id uuid not null references public.admin_roles(id) on delete cascade,
  permission text not null,
  primary key(role_id,permission)
);
create table if not exists public.admin_role_members (
  role_id uuid not null references public.admin_roles(id) on delete cascade,
  stable_id uuid not null references public.stables(id) on delete cascade,
  granted_by uuid references public.stables(id),
  granted_at timestamptz not null default now(),
  primary key(role_id,stable_id)
);
create table if not exists public.admin_permission_grants (
  stable_id uuid not null references public.stables(id) on delete cascade,
  permission text not null,
  granted_by uuid references public.stables(id),
  granted_at timestamptz not null default now(),
  primary key(stable_id,permission)
);
create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.stables(id),
  action_type text not null,
  system text not null,
  target_type text,
  target_id text,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.admin_roles enable row level security;
alter table public.admin_role_permissions enable row level security;
alter table public.admin_role_members enable row level security;
alter table public.admin_permission_grants enable row level security;
alter table public.admin_audit_log enable row level security;

create or replace function public.is_owner_account(p_stable uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from stables where id=p_stable and account_number=1)
$$;
create or replace function public.has_admin_permission(p_permission text,p_user uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=public as $$
 select public.is_owner_account(p_user) or exists(
   select 1 from stables s where s.id=p_user and s.is_admin and (
    exists(select 1 from admin_permission_grants g where g.stable_id=p_user and g.permission=p_permission)
    or exists(select 1 from admin_role_members m join admin_role_permissions rp on rp.role_id=m.role_id where m.stable_id=p_user and rp.permission=p_permission)
   )
 )
$$;
create or replace function public.require_admin_permission(p_permission text) returns void
language plpgsql security definer set search_path=public as $$begin
 if not has_admin_permission(p_permission) then raise exception 'Administrator permission required'; end if;
end$$;

create or replace function public.admin_effective_permissions() returns table(permission text)
language plpgsql security definer set search_path=public as $$begin
 if public.is_owner_account() then
  return query select unnest(array[
   'admin.horses.view','admin.horses.edit','admin.visuals.view','admin.visuals.upload','admin.visuals.review','admin.visuals.approve','admin.visuals.production',
   'admin.store.view','admin.store.edit','admin.shows.view','admin.shows.edit','admin.shows.qa','admin.shows.run',
   'admin.professions.view','admin.professions.edit','admin.professions.qa','admin.accounts.view','admin.accounts.edit',
   'admin.economy.view','admin.economy.edit','admin.brands.view','admin.brands.edit','admin.balance.view','admin.balance.edit',
   'admin.system.view','admin.system.edit','admin.audit.view'
  ]::text[]);
 elsif exists(select 1 from stables where id=auth.uid() and is_admin) then
  return query select distinct p from (
   select g.permission p from admin_permission_grants g where g.stable_id=auth.uid()
   union all select rp.permission from admin_role_members m join admin_role_permissions rp on rp.role_id=m.role_id where m.stable_id=auth.uid()
  ) x order by p;
 else raise exception 'Administrator access required'; end if;
end$$;

create or replace function public.owner_set_admin_permissions(p_stable uuid,p_permissions text[]) returns void
language plpgsql security definer set search_path=public as $$begin
 if not public.is_owner_account() then raise exception 'Owner Account #1 access required'; end if;
 if exists(select 1 from stables where id=p_stable and account_number=1) then raise exception 'Owner permissions are implicit'; end if;
 update stables set is_admin=true where id=p_stable;
 delete from admin_permission_grants where stable_id=p_stable;
 insert into admin_permission_grants(stable_id,permission,granted_by) select p_stable,p,auth.uid() from unnest(p_permissions)p;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details) values(auth.uid(),'permissions.updated','accounts','stable',p_stable::text,jsonb_build_object('permissions',p_permissions));
end$$;

create or replace function public.admin_audit_feed(p_limit integer default 200) returns table(id bigint,actor text,action_type text,system text,target_type text,target_id text,details jsonb,created_at timestamptz)
language plpgsql security definer set search_path=public as $$begin
 perform require_admin_permission('admin.audit.view');
 return query select l.id,coalesce(s.name,'System'),l.action_type,l.system,l.target_type,l.target_id,l.details,l.created_at from admin_audit_log l left join stables s on s.id=l.actor_id order by l.created_at desc limit least(greatest(p_limit,1),500);
end$$;

create policy "permitted admins read roles" on public.admin_roles for select using(has_admin_permission('admin.accounts.view'));
create policy "permitted admins read role permissions" on public.admin_role_permissions for select using(has_admin_permission('admin.accounts.view'));
create policy "permitted admins read role members" on public.admin_role_members for select using(has_admin_permission('admin.accounts.view'));
create policy "permitted admins read grants" on public.admin_permission_grants for select using(has_admin_permission('admin.accounts.view') or stable_id=auth.uid());
create policy "audit admins read logs" on public.admin_audit_log for select using(has_admin_permission('admin.audit.view'));

revoke all on function public.owner_set_admin_permissions(uuid,text[]) from public;
revoke all on function public.admin_effective_permissions() from public;
revoke all on function public.admin_audit_feed(integer) from public;
grant execute on function public.owner_set_admin_permissions(uuid,text[]),public.admin_effective_permissions(),public.admin_audit_feed(integer) to authenticated;
