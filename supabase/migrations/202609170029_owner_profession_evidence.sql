-- Read-only Owner profession evidence for production data-integrity diagnosis.
create or replace function public.admin_owner_profession_evidence()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare owner_id uuid;
begin
 if not (public.is_owner_account() or public.has_admin_permission('admin.professions.view')) then raise exception 'Profession administration permission required';end if;
 select id into owner_id from stables where account_number=1;
 return jsonb_build_object(
  'owner_id',owner_id,
  'career',(select to_jsonb(pp) from player_professions pp where pp.stable_id=owner_id and pp.profession_id='farrier'),
  'study',coalesce((select jsonb_agg(to_jsonb(x)order by x.level)from player_study_progress x where x.stable_id=owner_id and x.profession_id='farrier'),'[]'::jsonb),
  'attempts',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'level',x.level,'score',x.score,'passed',x.passed,'created_at',x.created_at)order by x.created_at)from certification_attempts x where x.stable_id=owner_id and x.profession_id='farrier'),'[]'::jsonb),
  'certificates',coalesce((select jsonb_agg(to_jsonb(x)order by x.level)from player_profession_certifications x where x.stable_id=owner_id and x.profession_id='farrier'),'[]'::jsonb),
  'advancements',coalesce((select jsonb_agg(to_jsonb(x)order by x.target_level)from profession_career_advancements x where x.stable_id=owner_id and x.profession_id='farrier'),'[]'::jsonb),
  'rate_setups',coalesce((select jsonb_agg(to_jsonb(x)order by x.level)from profession_rate_setups x where x.stable_id=owner_id and x.profession_id='farrier'),'[]'::jsonb),
  'offerings',coalesce((select jsonb_agg(jsonb_build_object('service_id',o.service_id,'name',sc.name,'minimum_level',sc.minimum_level,'price',o.price,'enabled',o.enabled,'valid',o.price between sc.min_price and sc.max_price)order by sc.minimum_level,o.service_id)from player_service_offerings o join service_catalog sc on sc.id=o.service_id where o.stable_id=owner_id and sc.profession_id='farrier'),'[]'::jsonb),
  'services',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'service_id',r.service_id,'provider_level',r.provider_level,'price',r.price,'self_service',r.self_service,'status',r.status,'completed_at',r.completed_at)order by r.completed_at)from horse_service_records r where r.provider_id=owner_id and r.profession_id='farrier'),'[]'::jsonb),
  'reconciliation',coalesce((select jsonb_agg(jsonb_build_object('evidence',a.evidence,'reconciled_at',a.reconciled_at)order by a.reconciled_at)from profession_persistence_audit a where a.stable_id=owner_id),'[]'::jsonb)
 );
end$$;
revoke all on function public.admin_owner_profession_evidence() from public;
grant execute on function public.admin_owner_profession_evidence() to authenticated;
