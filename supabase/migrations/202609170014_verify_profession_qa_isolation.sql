-- Post-deploy server verification. All QA calls are read-only; the normal-player
-- sequential-career rejection runs inside a subtransaction that is rolled back.
do $$
declare
  v_owner uuid;
  v_normal uuid;
  v_profession text;
  v_level integer;
  v_first text;
  v_second text;
  before_progress jsonb;
  after_progress jsonb;
  before_balance bigint;
  after_balance bigint;
  before_ledger bigint;
  after_ledger bigint;
  workspace jsonb;
begin
 select s.id,s.balance into v_owner,before_balance from stables s where s.account_number=1;
 if v_owner is null then raise exception 'Owner Account #1 not found';end if;
 perform set_config('request.jwt.claim.sub',v_owner::text,true);
 select coalesce(jsonb_agg(to_jsonb(pp)order by pp.profession_id),'[]'::jsonb)into before_progress from player_professions pp where pp.stable_id=v_owner;
 select count(*)into before_ledger from currency_ledger l where l.stable_id=v_owner;

 for v_profession in select p.id from professions p where p.active order by p.sort_order loop
  for v_level in 1..4 loop
   workspace:=open_profession_qa_career(v_profession,v_level);
   if workspace->>'profession'<>v_profession or(workspace->>'level')::integer<>v_level or not(workspace->>'read_only')::boolean then raise exception 'Invalid QA workspace for % level %',v_profession,v_level;end if;
   perform * from get_profession_qa_questions(v_profession,v_level);
  end loop;
 end loop;

 select coalesce(jsonb_agg(to_jsonb(pp)order by pp.profession_id),'[]'::jsonb)into after_progress from player_professions pp where pp.stable_id=v_owner;
 select s.balance into after_balance from stables s where s.id=v_owner;
 select count(*)into after_ledger from currency_ledger l where l.stable_id=v_owner;
 if before_progress<>after_progress or before_balance<>after_balance or before_ledger<>after_ledger then raise exception 'Profession QA changed permanent Owner progression or economy';end if;

 select s.id into v_normal from stables s where s.account_number<>1 order by s.account_number limit 1;
 select p.id into v_first from professions p where p.active order by p.sort_order limit 1;
 select p.id into v_second from professions p where p.active and p.id<>v_first order by p.sort_order limit 1;
 if v_normal is null or v_second is null then raise exception 'Normal-player sequential guard fixture unavailable';end if;
 perform set_config('request.jwt.claim.sub',v_normal::text,true);
 begin
  delete from player_professions where stable_id=v_normal and profession_id in(v_first,v_second);
  insert into player_professions(stable_id,profession_id,certification_level)values(v_normal,v_first,1);
  perform enroll_profession(v_second);
  raise exception 'Normal sequential-career guard did not reject a second career';
 exception when others then
  if sqlerrm<>'Complete your current career through Professional before enrolling in another' then raise;end if;
 end;
end$$;
