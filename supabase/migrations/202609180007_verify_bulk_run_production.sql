-- Production integration check: three isolated QA Shows through the deployed bulk RPC.
-- The transaction aborts on any failure and removes every fixture before completion.
do $$
declare
 v_owner uuid;
 v_discipline text;
 v_tier text;
 v_show_ids uuid[];
 v_request_key uuid:=gen_random_uuid();
 v_first jsonb;
 v_retry jsonb;
 v_batch_id uuid;
 v_audit_count integer;
begin
 select s.id into strict v_owner from stables as s where s.account_number=1;
 select sd.id into strict v_discipline from show_disciplines as sd where sd.active order by sd.id limit 1;
 select st.id into strict v_tier from show_tiers as st where st.active order by st.sort_order limit 1;

 with inserted as(
  insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,maximum_per_owner,description,is_private,is_admin_qa)
  select v_owner,'Bulk Runner Production QA '||n,v_discipline,v_tier,current_date,now()+interval '1 day',0,10,10,'Temporary isolated Bulk Run RPC verification',true,true
  from generate_series(1,3)as n returning id
 )select array_agg(i.id)into v_show_ids from inserted as i;

 perform set_config('request.jwt.claim.sub',v_owner::text,true);
 v_first:=admin_bulk_run_shows(v_show_ids,v_request_key,true);
 if (v_first->>'completed')::integer<>3 or (v_first->>'skipped')::integer<>0 then raise exception 'Three-show Bulk Run QA failed: %',v_first;end if;
 v_batch_id:=(v_first->>'batch_id')::uuid;

 v_retry:=admin_bulk_run_shows(v_show_ids,v_request_key,true);
 if coalesce((v_retry->>'idempotent')::boolean,false)is not true or (v_retry->>'completed')::integer<>3 then raise exception 'Bulk Run retry was not idempotent: %',v_retry;end if;

 select count(*) into v_audit_count from show_admin_audit as saa where saa.action='bulk_qa_preview'and(saa.details->>'batch_id')::uuid=v_batch_id;
 if v_audit_count<>3 then raise exception 'Expected exactly three per-Show QA executions, found %',v_audit_count;end if;

 delete from show_admin_audit as saa where saa.show_id=any(v_show_ids)or saa.details->>'batch_id'=v_batch_id::text;
 delete from show_bulk_runs as sbr where sbr.id=v_batch_id;
 delete from player_shows as ps where ps.id=any(v_show_ids);
end$$;
