-- Display all eight established Foundation breeds in a full store rotation.
update public.store_settings set inventory_size=8 where singleton;

-- Registry-derived type descriptions deliberately emphasize silhouette-level
-- differences so image generation does not collapse breeds into one body type.
update public.breed_visual_archetypes set
 body_description='unmistakably compact American stock-horse silhouette: comparatively short and low-set frame, short strong back, deep broad chest, thick substantial forearm and gaskin, low-set knees, wide loin, and exceptionally powerful rounded hindquarters; broad-jowled refined wedge-shaped head with a straight profile; moderate neck and visibly heavier muscle than any Thoroughbred or Arabian',
 height_range='typically 14.2–16 hands; portray a shorter, lower, denser silhouette than a Thoroughbred or Hanoverian',
 breed_constraints='Must read immediately as a Quarter Horse: compact, close-coupled, low and powerfully muscled. Never give it the long legs, narrow torso, long back, fragile head, or high-set swan neck of an Arabian, Thoroughbred, or warmblood. Avoid exaggerated halter-horse musculature.',
 source_organization='American Quarter Horse Association',source_url='https://www.aqha.com/' where breed='Quarter Horse';

update public.breed_visual_archetypes set
 body_description='unmistakably refined desert light-horse silhouette: small finely chiseled dry head, broad forehead, very large dark wide-set expressive eyes, short fine muzzle with large nostrils, deep jowls, small inward-curving ears, and a clearly visible gentle concave dish below the eyes; clean throatlatch, long high-set arched neck, short straight back, deep chest, well-sprung ribs, fine dense bone, comparatively horizontal croup, and natural high tail carriage',
 height_range='typically 14.1–15.1 hands; visibly smaller, lighter, finer-boned, shorter-backed and more delicate in feature than the other Foundation breeds',
 breed_constraints='Must read immediately as an Arabian even in silhouette. Prioritize the refined chiseled face, gentle authentic dish, huge expressive eyes, fine muzzle, arched neck, short back and high tail. Athletic and substantial enough to be sound, but never stocky, coarse-headed, long-faced, warmblood-like, or generically horse-shaped; avoid an extreme caricatured dish.',
 source_organization='Arabian Horse Association',source_url='https://arabianhorses.org/discover/arabian-horses/' where breed='Arabian';

update public.breed_visual_archetypes set
 body_description='unmistakably tall lean Thoroughbred racing silhouette: long clean legs with fine flat bone, deep narrow heartgirth, lean tucked athletic barrel, long sloping shoulder, prominent extended withers, long refined neck, straight refined head, long level athletic lines, and lean muscular hindquarters without bulky stock-horse mass',
 height_range='commonly 15.2–17 hands; portray noticeably taller, leggier, narrower and more rangy than a Quarter Horse, Morgan, Appaloosa, or Rocky Mountain Horse',
 breed_constraints='Must read immediately as a fit Thoroughbred: tall, long-legged, lean, deep through the heart and built for galloping. No compact stock-horse body, no thick cresty neck, no warmblood bulk, no Arabian dish or high tail, and no exaggerated bodybuilder muscle.',
 source_organization='The Jockey Club / USEF Thoroughbred Division',source_url='https://www.usef.org/forms-pubs/7qJ0t9vVd58/usef-rulebook' where breed='Thoroughbred';

update public.breed_visual_archetypes set
 body_description='unmistakably substantial yet athletic European warmblood silhouette: tall harmonious rectangular frame, noble expressive but not dished head, well-proportioned muscular neck, pronounced long withers, open long sloping shoulder, long broad forearm with shorter cannon, deep capacious barrel, strong well-padded back, long sprung hind rib, broad slightly sloping croup, powerful correctly angled hindquarters, and more bone and body substance than a Thoroughbred',
 height_range='large sport-horse scale with height proportionate to a clearly rectangular frame; taller and more substantial than stock, Arabian, Morgan, or gaited breeds',
 breed_constraints='Must read immediately as a Hanoverian sport horse: powerful, elegant, uphill and rectangular, combining substance with agility. Never a lean racehorse, compact stock horse, fine Arabian, draft horse, or generic light horse; avoid a square frame or coarse heavy head.',
 source_organization='American Hanoverian Society',source_url='https://hanoverian.org/mare-inspection-requirements/' where breed='Hanoverian';

update public.breed_visual_archetypes set
 body_description='recognizable versatile Appaloosa stock-horse silhouette: symmetrical smooth frame, straight lean distinctive head with prominent eye, clean throatlatch, deep chest, muscular sloping shoulder, defined withers, short straight back, short wide loin, long muscular hip and rounded quarters; moderate stock-horse bone without extreme Quarter Horse bulk',
 height_range='medium stock-horse scale; compact and practical, but generally less massively muscled than the Quarter Horse portrayal',
 breed_constraints='Preserve correct Appaloosa stock-horse conformation independently of coat. When LP is expressed, render believable asymmetric leopard-complex characteristics including mottled muzzle skin, visible white sclera and possibly vertically striped hooves; never use mirrored or dalmatian-like spots.',
 source_organization='Appaloosa Horse Club',source_url='https://www.appaloosa.com/handbook' where breed='Appaloosa';

update public.breed_visual_archetypes set
 body_description='unmistakably compact upright Morgan silhouette: expressive broad forehead, large prominent eyes, short straight or subtly dished face, short shapely wide-set ears, rounded jowls, refined deeper throatlatch, proud slightly crested arched neck emerging from the top of a deeply angled shoulder, defined withers, very short back, close coupling, broad loin, deep well-sprung body, long rounded muscular croup and high graceful tail attachment',
 height_range='typically 14.1–15.2 hands; compact, deep-bodied and substantial for its moderate height',
 breed_constraints='Must read immediately as a Morgan: proud, compact, short-backed, deep-bodied, arched-necked and substantial with refinement. The croup must not be higher than the withers. Do not turn it into an Arabian, Saddlebred, Quarter Horse, or generic small warmblood.',
 source_organization='American Morgan Horse Association',source_url='https://www.morganhorse.com/about-morgan/ideal-morgan/' where breed='Morgan';

update public.breed_visual_archetypes set
 body_description='distinct moderate Rocky Mountain gaited-horse silhouette: medium height and medium bone, proportionate medium feet, wide deep chest with visible span between forelegs, ideally 45-degree sloping shoulders, medium-sized straight-profile head with medium jaws, bold eyes, well-shaped ears, and a graceful medium-length arched neck set for natural carriage; balanced body neither rangy nor heavily muscled',
 height_range='strictly 14–16 hands; medium-sized and moderate in every proportion',
 breed_constraints='Must read as a practical moderate Rocky Mountain Horse, not a Tennessee Walker, Arabian, Saddlebred, or stock horse. Face must be neither dished nor Roman-nosed. Solid body color only, modest facial white only, and absolutely no white above knee or hock.',
 source_organization='Rocky Mountain Horse Association',source_url='https://www.rmhorse.com/?page_id=734' where breed='Rocky Mountain Horse';

update public.breed_visual_archetypes set
 body_description='unmistakably tall long-striding Tennessee Walking Horse silhouette: definitive straight-profile head with small well-placed ears, long refined neck, very long sloping shoulder, long sloping hip, fairly short back with short strong coupling, and a bottom line visibly longer than the top line; smooth rangy frame built for an effortless ground-covering running walk',
 height_range='typically 14.3–17 hands and 900–1200 pounds; taller, longer-lined and rangier than the Rocky Mountain Horse or Morgan',
 breed_constraints='Must read immediately as a natural Tennessee Walking Horse through the long sloping shoulder and hip, longer underline, short coupling and smooth gaited proportions. Do not depict padded-show posture, stacked shoes, artificial action, an Arabian head, stock-horse bulk, or generic warmblood anatomy.',
 source_organization='Tennessee Walking Horse Breeders’ and Exhibitors’ Association',source_url='https://twhbea.com/the-breed/conformation/' where breed='Tennessee Walking Horse';

-- Recalculate descriptions and rerender only generic or system-created art.
-- User-provided horse URLs are intentionally outside this predicate.
with revised as materialized (
 select h.id,build_visual_phenotype(h.breed,h.sex,greatest(0,extract(epoch from (now()-h.birth_date))/31557600),h.genetics,h.markings) as visual
 from public.horses h
 left join public.store_inventory si on si.horse_id=h.id and si.status='active'
 where (h.owner_id is not null or si.id is not null)
 and (coalesce(h.image_url,'') in ('','/foundation-horse.png') or h.image_url like '%/generated/store/%' or h.image_url like '%/generated/horses/%')
)
update public.horses h set visual_phenotype=r.visual,image_generation_status='pending',image_prompt_version='horse-v5'
from revised r where r.id=h.id;

insert into public.store_horse_image_jobs(horse_id,status,attempts,next_attempt_at,last_error,completed_at)
select h.id,'pending',0,now(),null,null from public.horses h
left join public.store_inventory si on si.horse_id=h.id and si.status='active'
where (h.owner_id is not null or si.id is not null)
and (coalesce(h.image_url,'') in ('','/foundation-horse.png') or h.image_url like '%/generated/store/%' or h.image_url like '%/generated/horses/%')
on conflict(horse_id) do update set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null;

create or replace function public.complete_horse_image_job(target_job uuid,target_horse uuid,new_image_url text,used_prompt text,prompt_version text)
returns boolean language plpgsql security definer set search_path=public as $$
declare h horses;begin
 if auth.role()<>'service_role' then raise exception 'Service role required';end if;
 select * into h from horses where id=target_horse for update;
 if not found then raise exception 'Horse not found';end if;
 if coalesce(h.image_url,'') in ('','/foundation-horse.png') or h.image_url like '%/generated/store/%' or h.image_url like '%/generated/horses/%' then
  update horses set image_url=new_image_url,image_generation_status='complete',image_prompt_version=prompt_version where id=target_horse;
 else
  update horses set image_generation_status='complete' where id=target_horse;
 end if;
 update store_horse_image_jobs set status='complete',prompt=used_prompt,completed_at=now(),last_error=null where id=target_job and horse_id=target_horse;
 return true;
end $$;

revoke all on function public.complete_horse_image_job(uuid,uuid,text,text,text) from public;
grant execute on function public.complete_horse_image_job(uuid,uuid,text,text,text) to service_role;

-- Fill the two additional slots immediately. Existing stock remains stable.
select public.refresh_store_inventory();
