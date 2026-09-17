-- Replace the original cross-level seed question with curriculum-specific banks.
-- Each row is grounded in one lesson from the matching Study module.
delete from public.certification_questions;

insert into public.certification_questions
  (profession_id,level,prompt,choices,correct_index,explanation)
values
('farrier',1,'Which hoof structures help absorb force alongside the weight-bearing hoof wall?','["The sole, frog, and internal structures","Only the coronet band","Only the outer wall"]',0,'Basic Study identifies the sole, frog, and internal structures as force-absorbing structures.'),
('farrier',1,'What is the purpose of routine trimming?','["Maintain balance and prevent excess growth","Maximize hoof length","Choose identical shoes for every horse"]',0,'Basic Study teaches that routine trimming maintains balance and prevents excess growth.'),
('farrier',1,'What is true of LE farrier services?','["They are game mechanics, not a replacement for real care","They provide real veterinary advice","They permanently rewrite genetics"]',0,'Basic Study explicitly distinguishes LE gameplay from real farrier care.'),
('farrier',2,'What does medial-lateral hoof balance support?','["Even loading","Maximum traction in every setting","Longer toes"]',0,'Proficient Study connects medial-lateral balance with even loading.'),
('farrier',2,'Which factors should be considered together?','["Breakover and heel support","Coat color and account level","Age and stable name"]',0,'Proficient Study teaches that breakover and heel support are considered together.'),
('farrier',2,'A service plan should match which combination?','["Work, footing, and current hoof status","Breed name alone","The cheapest available shoe"]',0,'Proficient Study bases the plan on work, footing, and current hoof status.'),
('farrier',3,'Why can traction needs differ?','["Performance disciplines place different demands on the hoof","All disciplines use identical footing","Traction is determined by coat color"]',0,'Advanced Study teaches that performance disciplines create different traction and support demands.'),
('farrier',3,'What should hoof-care changes preserve?','["Sound, functional movement","Maximum speed at any cost","A fixed package for every horse"]',0,'Advanced Study prioritizes sound, functional movement.'),
('farrier',3,'What do specialty packages require?','["Accurate assessment and follow-up","No reassessment","Selection by breed alone"]',0,'Advanced Study requires accurate assessment and follow-up for specialty packages.'),
('farrier',4,'Professional service balances protection and movement with what?','["The horse’s workload","The owner’s account number","A universal shoeing schedule"]',0,'Professional Study includes workload in the balance of protection and movement.'),
('farrier',4,'Why document service history?','["To support continuity of care","To change inherited stats","To bypass cooldowns"]',0,'Professional Study teaches that documentation supports continuity of care.'),
('farrier',4,'What is Professional certification in the current LE system?','["The highest current game tier","A real-world license","An automatic genetics bonus"]',0,'Professional Study identifies Professional as the highest current LE game tier.'),

('veterinarian',1,'Which observations belong in routine wellness monitoring?','["Appetite, demeanor, movement, and hydration","Coat color only","Show points only"]',0,'Basic Study lists appetite, demeanor, movement, and hydration.'),
('veterinarian',1,'How is a wellness exam used in LE?','["As preventive game care","As a real diagnosis","As permanent stat training"]',0,'Basic Study describes the wellness exam as preventive game care.'),
('veterinarian',1,'What does LE veterinary certification represent?','["An in-game credential, not real licensure","A real veterinary license","Permission to alter genetics"]',0,'Basic Study states that LE certification is not real veterinary licensure.'),
('veterinarian',2,'What should current signs be compared with?','["The horse’s normal baseline","A random horse","Show rankings only"]',0,'Proficient Study begins evaluation by comparing signs with the normal baseline.'),
('veterinarian',2,'What does a recovery plan balance?','["Rest, reassessment, and gradual return","Continuous maximum work","No follow-up"]',0,'Proficient Study balances rest, reassessment, and gradual return.'),
('veterinarian',2,'Where should urgent real-world concerns be directed?','["A licensed veterinarian","An LE market listing","A show host"]',0,'Proficient Study directs urgent real-world concerns to a licensed veterinarian.'),
('veterinarian',3,'What does performance evaluation consider?','["The whole horse","Only one stat","Only recent winnings"]',0,'Advanced Study considers the whole horse.'),
('veterinarian',3,'How should management changes be made?','["Gradually and with records","All at once without records","Only after breeding"]',0,'Advanced Study calls for gradual, recorded management changes.'),
('veterinarian',3,'How is reproductive evaluation represented in LE?','["As a simplified game service","As real medical care","As a genetics rewrite"]',0,'Advanced Study identifies reproductive evaluation as a simplified game service.'),
('veterinarian',4,'What does professional-level service integrate?','["History, observation, and follow-up","A single isolated sign","Account progression"]',0,'Professional Study integrates history, observation, and follow-up.'),
('veterinarian',4,'Why should transparent records follow the horse?','["To preserve continuity of information","To increase base stats","To remove service limits"]',0,'Professional Study requires transparent records to follow the horse.'),
('veterinarian',4,'What is true of an LE veterinary result?','["It is not a real diagnosis","It replaces licensed care","It changes breeding stats"]',0,'Professional Study states that no LE result is a real diagnosis.'),

('trainer',1,'How should training progress?','["Through repeatable, achievable steps","By repeating the hardest task continuously","By skipping foundations"]',0,'Basic Study teaches repeatable, achievable progression.'),
('trainer',1,'How does fitness develop?','["Gradually, with recovery","Instantly without rest","Only through shows"]',0,'Basic Study pairs gradual fitness development with recovery.'),
('trainer',1,'What should guide a training session?','["Temperament and current ability","Coat color and stable brand","Price alone"]',0,'Basic Study uses temperament and current ability to guide sessions.'),
('trainer',2,'What connects exercises to performance goals?','["Specificity","Random repetition","Temporary tack alone"]',0,'Proficient Study uses specificity to connect exercises and goals.'),
('trainer',2,'What remains important as difficulty increases?','["Foundation skills","Skipping recovery","Changing genetics"]',0,'Proficient Study retains foundation skills at higher difficulty.'),
('trainer',2,'How should permanent development be tracked?','["Separately from temporary effects","As the same thing as Wellness","Only in market prices"]',0,'Proficient Study separates permanent development from temporary effects.'),
('trainer',3,'What does periodized work alternate?','["Challenge and recovery","Only maximum effort","Different coat colors"]',0,'Advanced Study alternates challenge and recovery.'),
('trainer',3,'What is more valuable than repetitive clicking?','["Quality practice","Longer sessions regardless of quality","Skipping reassessment"]',0,'Advanced Study prioritizes quality practice.'),
('trainer',3,'Why keep transparent development records?','["To preserve breeding values","To create temporary Wellness","To bypass age rules"]',0,'Advanced Study uses transparent records to preserve breeding values.'),
('trainer',4,'What does a professional plan connect?','["Conformation, temperament, fitness, and goals","Only speed and price","Only recent results"]',0,'Professional Study connects conformation, temperament, fitness, and goals.'),
('trainer',4,'Why reassess a professional training plan?','["To keep it appropriate","To avoid all recovery","To change inherited genetics"]',0,'Professional Study uses reassessment to keep the plan appropriate.'),
('trainer',4,'What is Professional certification in current LE training?','["The highest current certification","A real-world training license","An unlimited service exemption"]',0,'Professional Study identifies Professional as the highest current certification.'),

('massage',1,'What supports movement and benefits from appropriate recovery?','["Large muscle groups","Account level","Stable branding"]',0,'Basic Study connects large muscle groups with movement and recovery.'),
('massage',1,'How is general massage represented in LE?','["As a temporary condition service","As a permanent genetic change","As a certification shortcut"]',0,'Basic Study defines general massage as a temporary condition service.'),
('massage',1,'What does LE massage certification represent?','["An in-game credential, not real qualification","A real-world qualification","Veterinary licensure"]',0,'Basic Study distinguishes LE certification from real qualification.'),
('massage',2,'What does performance preparation support rather than replace?','["Conditioning","Genetics","Service history"]',0,'Proficient Study states that preparation supports rather than replaces conditioning.'),
('massage',2,'What should guide the scope of a session?','["Response and comfort","Price alone","Show placement"]',0,'Proficient Study uses response and comfort to guide scope.'),
('massage',2,'How do massage effects relate to inheritance?','["They are temporary and never inherited","They permanently alter breeding stats","They transfer to offspring"]',0,'Proficient Study explicitly says effects are temporary and never inherited.'),
('massage',3,'What should a recovery plan consider?','["Recent workload and upcoming demands","Only breed","Only account level"]',0,'Advanced Study considers recent workload and upcoming demands.'),
('massage',3,'Why is documented history useful?','["It helps avoid excessive repeat service","It removes cooldowns","It changes permanent stats"]',0,'Advanced Study uses history to avoid excessive repeat service.'),
('massage',3,'What do cooldowns protect?','["Game balance and horse welfare","Provider branding","Show entry fees"]',0,'Advanced Study states that cooldowns protect balance and welfare.'),
('massage',4,'What does professional bodywork integrate?','["Preparation, recovery, and follow-up","Only preparation","Only market pricing"]',0,'Professional Study integrates preparation, recovery, and follow-up.'),
('massage',4,'How should Professional massage bonuses be labeled?','["Clearly as temporary","As inherited stats","As permanent development"]',0,'Professional Study requires temporary bonuses to remain clearly labeled.'),
('massage',4,'Where should real health concerns be referred?','["Qualified professionals","An LE show host","A market buyer"]',0,'Professional Study refers real health concerns to qualified professionals.');

-- The existing RPCs already key selection by both profession and level. Guard
-- against future accidental reuse by requiring three active questions per bank.
do $$
declare missing text;
begin
  select string_agg(p.id||'/'||l.level,', ') into missing
  from professions p cross join certification_levels l
  left join lateral (
    select count(*) count from certification_questions q
    where q.profession_id=p.id and q.level=l.level and q.active
  ) bank on true
  where p.active and bank.count<3;
  if missing is not null then raise exception 'Incomplete profession question banks: %',missing; end if;
end$$;
