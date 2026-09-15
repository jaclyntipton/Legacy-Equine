-- Equine height notation is base four: 14.3h is followed by 15h.
create or replace function public.hand_notation_to_inches(value numeric)
returns integer language sql immutable as $$ select floor(value)::int*4+round((value-floor(value))*10)::int $$;
create or replace function public.inches_to_hand_notation(value numeric)
returns numeric language sql immutable as $$ select floor(round(value)::int/4)::numeric+(mod(round(value)::int,4)::numeric/10) $$;
create or replace function public.format_hand_height(value numeric)
returns text language sql immutable as $$ select floor(hand_notation_to_inches(value)/4)::text||case when mod(hand_notation_to_inches(value),4)=0 then 'h' else '.'||mod(hand_notation_to_inches(value),4)::text||'h' end $$;

create or replace function public.express_mature_height(g jsonb,min_h numeric,max_h numeric)
returns numeric language plpgsql volatile as $$
declare min_inches integer:=hand_notation_to_inches(min_h);max_inches integer:=hand_notation_to_inches(max_h);midpoint numeric:=(min_inches+max_inches)/2.0;half_range numeric:=(max_inches-min_inches)/2.0;large_count integer:=height_large_alleles(g);result_inches numeric;begin
 result_inches:=midpoint+((large_count-4)::numeric/4)*(half_range*.88)+((random()-.5)*1.0);
 return inches_to_hand_notation(greatest(min_inches,least(max_inches,round(result_inches))));
end $$;

-- Normalize old values according to their displayed meaning: 14.8 becomes 16h.
update public.horses set mature_height_hands=inches_to_hand_notation(hand_notation_to_inches(mature_height_hands));
update public.horses set visual_phenotype=jsonb_set(visual_phenotype,'{height_hands}',to_jsonb(mature_height_hands),true);
alter table public.horses add constraint valid_hand_height_notation check (round((mature_height_hands-floor(mature_height_hands))*10)::int between 0 and 3);
comment on column public.horses.mature_height_hands is 'Permanent adult height in standard equine hand notation; suffix digit is inches 0–3.';
revoke all on function public.hand_notation_to_inches(numeric),public.inches_to_hand_notation(numeric) from public;
grant execute on function public.format_hand_height(numeric) to authenticated,anon;
