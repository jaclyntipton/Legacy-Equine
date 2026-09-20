create or replace function public.preview_eligible_show_entries(p_show_ids uuid[],p_horse_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare v_pairs jsonb;v_preview jsonb;v_reasons jsonb;v_already integer;v_excluded integer;v_eligible_shows integer;
begin
 select coalesce(jsonb_agg(jsonb_build_object('show_id',s.show_id,'horse_id',h.horse_id)),'[]'::jsonb) into v_pairs
 from unnest(coalesce(p_show_ids,'{}'::uuid[]))as s(show_id) cross join unnest(coalesce(p_horse_ids,'{}'::uuid[]))as h(horse_id);
 v_preview:=preview_show_entries(v_pairs);
 select coalesce(jsonb_object_agg(reason,total),'{}'::jsonb) into v_reasons from(select item->>'reason' reason,count(*)::integer total from jsonb_array_elements(coalesce(v_preview->'skipped','[]'::jsonb))as skipped(item)group by item->>'reason')grouped;
 v_already:=coalesce((v_reasons->>'Already entered')::integer,0);v_excluded:=jsonb_array_length(coalesce(v_preview->'skipped','[]'::jsonb));
 select count(distinct item->>'show_id')into v_eligible_shows from jsonb_array_elements(coalesce(v_preview->'eligible','[]'::jsonb))as eligible(item);
 return(v_preview-'skipped')||jsonb_build_object('shows_available',coalesce(cardinality(p_show_ids),0),'horses_selected',coalesce(cardinality(p_horse_ids),0),'entries_to_create',jsonb_array_length(coalesce(v_preview->'eligible','[]'::jsonb)),'eligible_show_count',coalesce(v_eligible_shows,0),'already_entered',v_already,'ineligible',greatest(0,v_excluded-v_already),'excluded_by_reason',v_reasons);
end$$;
revoke all on function public.preview_eligible_show_entries(uuid[],uuid[])from public;
grant execute on function public.preview_eligible_show_entries(uuid[],uuid[])to authenticated;
comment on function public.preview_eligible_show_entries(uuid[],uuid[])is'Builds the authoritative eligible horse/show pair set from selected horses and Shows. Excluded combinations are summarized, never selected or charged.';
