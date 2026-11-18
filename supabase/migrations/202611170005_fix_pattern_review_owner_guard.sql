-- Repair the pattern-review RPC to use Legacy Equine's authoritative Owner
-- entitlement. Owner Accounts #1 and #2 are both covered by is_owner_account().
create or replace function public.admin_review_pattern_standard(
 p_pattern_key text,
 p_family text,
 p_display_name text,
 p_sex text,
 p_decision text,
 p_notes text default ''
)returns void
language plpgsql
security definer
set search_path=public
as $$
begin
 if not public.is_owner_account() then
  raise exception 'Owner access required';
 end if;
 if p_sex not in ('mare','stallion') or p_decision not in ('approved','needs_correction') then
  raise exception 'Invalid pattern review';
 end if;
 insert into horse_pattern_standard_reviews(pattern_key,family,display_name,sex,decision,notes,reviewed_by)
 values(left(p_pattern_key,80),left(p_family,40),left(p_display_name,100),p_sex,p_decision,left(trim(coalesce(p_notes,'')),2000),auth.uid())
 on conflict(pattern_key,sex) do update set
  family=excluded.family,
  display_name=excluded.display_name,
  decision=excluded.decision,
  notes=excluded.notes,
  reviewed_by=excluded.reviewed_by,
  reviewed_at=now();
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)
 values(auth.uid(),'visual.pattern_'||p_decision,'horse_visuals','pattern_standard',left(p_pattern_key,80)||':'||p_sex,jsonb_build_object('family',left(p_family,40),'display_name',left(p_display_name,100),'notes',left(trim(coalesce(p_notes,'')),2000)));
end
$$;

revoke all on function public.admin_review_pattern_standard(text,text,text,text,text,text) from public,anon;
grant execute on function public.admin_review_pattern_standard(text,text,text,text,text,text) to authenticated;
