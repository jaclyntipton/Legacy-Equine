create table if not exists public.horse_visual_render_reviews(
 signature text primary key,
 sample_horse_id uuid references public.horses(id) on delete set null,
 decision text not null check(decision in('approved','needs_correction')),
 notes text not null default'',
 reviewed_by uuid not null references public.stables(id),
 reviewed_at timestamptz not null default now()
);
alter table public.horse_visual_render_reviews enable row level security;
revoke all on public.horse_visual_render_reviews from public,anon,authenticated;

create or replace function public.horse_visual_render_signature(p_horse public.horses)returns text language sql immutable set search_path=public as $$select md5(concat_ws('|',p_horse.breed,p_horse.sex,p_horse.color,coalesce(p_horse.visual_phenotype,'{}'::jsonb)::text,coalesce(p_horse.markings,'{}'::jsonb)::text,coalesce(p_horse.genetics,'{}'::jsonb)::text))$$;

create or replace function public.admin_live_coat_review_workspace()returns table(horse_id uuid,inventory_id uuid,name text,breed text,sex text,color text,image_url text,signature text,decision text,notes text,reviewed_at timestamptz)language plpgsql security definer set search_path=public as $$begin perform require_super_admin();return query select h.id,si.id,h.name,h.breed,h.sex,h.color,h.image_url,horse_visual_render_signature(h),r.decision,r.notes,r.reviewed_at from store_inventory si join horses h on h.id=si.horse_id left join horse_visual_render_reviews r on r.signature=horse_visual_render_signature(h)where si.status='active'order by h.breed,h.sex,h.color,h.id;end$$;

create or replace function public.admin_review_live_coat(p_horse uuid,p_decision text,p_notes text default'')returns void language plpgsql security definer set search_path=public as $$declare h horses;s text;begin perform require_super_admin();if p_decision not in('approved','needs_correction')then raise exception'Invalid review decision';end if;select*into h from horses where id=p_horse;if not found then raise exception'Horse not found';end if;s:=horse_visual_render_signature(h);insert into horse_visual_render_reviews(signature,sample_horse_id,decision,notes,reviewed_by,reviewed_at)values(s,h.id,p_decision,left(trim(coalesce(p_notes,'')),1000),auth.uid(),now())on conflict(signature)do update set sample_horse_id=excluded.sample_horse_id,decision=excluded.decision,notes=excluded.notes,reviewed_by=excluded.reviewed_by,reviewed_at=excluded.reviewed_at;insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'visual.live_coat_'||p_decision,'horse_visuals','render_signature',s,jsonb_build_object('horse_id',h.id,'breed',h.breed,'sex',h.sex,'color',h.color,'notes',left(trim(coalesce(p_notes,'')),1000)));end$$;

revoke all on function public.horse_visual_render_signature(public.horses),public.admin_live_coat_review_workspace(),public.admin_review_live_coat(uuid,text,text)from public,anon;
grant execute on function public.admin_live_coat_review_workspace(),public.admin_review_live_coat(uuid,text,text)to authenticated;
