# Legacy Equine Gameplay Specification — Alpha 0.1

## Status labels

- **Confirmed inspiration:** ownership, training, breeding, pedigrees, and community are the intended genre pillars; no proprietary implementation is reproduced.
- **Strong player recollection:** foundation horses cost approximately 1,000 and mares rested roughly one to two weeks.
- **Legacy Equine modernization:** timestamp-derived aging, permanent audit ledger, responsive interface, and server-authoritative actions.
- **Primary-source confirmed:** Ludus Equinus used exactly seven separate horse stats. Surviving player-bred Quarter Horse artwork for “Flying On My Raptor” records seven birth values: 218, 220, 220, 400, 224, 270, and 220.
- **Provisional names:** Legacy Equine currently uses Agility, Speed, Endurance, Temperament, Strength, Intelligence, and Conformation. The count is confirmed; the exact historical names and order remain under archival investigation, so definitions stay data-driven and renameable without changing horse records.
- **Unresolved:** exact historical aging rate, training tickets, retirement thresholds, and original stat names/order.

## Alpha rules

Configuration lives in `lib/game/config.ts`. New stables receive 4,000 LE Dollars, and every existing player was raised to a minimum 4,000 LE balance for the Alpha economy. Foundation Store purchases have no lifetime count limit: sufficient LED and an available stable stall are the only account constraints. Normal foundation stats are 10–15 with a 6% outlier roll spanning 7–18. Every random process accepts a seeded generator.

Every normal account begins with five active-horse stalls. Capacity is derived from auditable base, verified USD purchase, Owner-granted, promotional, and event allocations rather than a mutable total. The provisional repeatable package adds five permanent account-bound stalls for $4.99 USD as a one-time purchase. Account #1 has an explicit unlimited-capacity entitlement. Store, marketplace, transfer, gift, auction, and foal acquisition paths must enforce capacity transactionally before money or ownership changes.

The LE Equine Sanctuary permanently retires a horse without deleting it. Surrender requires exact-name confirmation, frees its stall, ends active ownership, and can never be reversed. Sanctuary horses retain artwork, genetics, stats, pedigree, progeny, ownership history, service history, and show records, remain publicly searchable, and can never again be owned, transferred, sold, bred, shown, or used for services. The initial surrender fee is 0 LED.

Public LE account numbers are permanent, positive, unique, and assigned atomically in genuine stable-creation order from #1. Twisted Tree Ranch is LE Account #1. Numbers are never edited or recycled. Service-role-marked automated test identities receive no public number and never advance the production sequence.

### Shared LE Store inventory

The production LE Store maintains eight globally shared Foundation horses, one slot for each currently established Foundation breed. The architecture remains configurable from five to eight, and future breed additions can expand that supported range deliberately. Each listing is a real, server-generated horse with persistent identity, breed, sex, age, color, stats, artwork, price, and generation time before purchase. Players inspect every stat and purchase the exact horse shown. Inventory rotates after 60 minutes when next accessed; unsold rows become historical `expired` records. A sale atomically locks and transfers that horse, records payment, marks its inventory record sold, and fills only the empty slot. There is no introductory or lifetime Foundation purchase-count limit; stable capacity is the acquisition constraint.

Store Foundation horses are intentionally unnamed. Their database identity, breed, appearance, and stats persist before purchase, but the display name remains `Unnamed Foundation Horse`. After purchase, the owner gives the horse an editable individual name from its horse profile.

Every horse created in Legacy Equine receives persistent face and four-leg markings plus individual generated artwork, including Foundation inventory, purchased horses, bred foals, and administrator-created horses. The genetics engine resolves coat color and patterns first, then produces a structured visual phenotype containing breed/body archetype, sex, age, coat, mane/tail, pattern, and exact markings. A server-only image worker uses that structure without imposing one reference horse's anatomy on every breed. The resulting raster asset is stored once on that horse and follows it through ownership changes; page views never reroll identity, genes, markings, stats, or artwork. Failed jobs retain the exact horse and placeholder for a safe retry. A player-supplied horse image is a deliberate customization and is never replaced by the generator.

Breed type is the highest-priority artwork constraint. Foundation breeds must be recognizable from anatomy and silhouette before color: Arabians are smaller, fine-boned, short-backed and distinctly refined with an authentic gentle dish and high tail; Quarter Horses are lower, shorter, close-coupled and powerfully stocky; Thoroughbreds are tall, lean, long-legged and rangy; Hanoverians are tall rectangular warmbloods with greater bone and substance while remaining athletic; Morgans are compact, deep-bodied, proud and upright; Rocky Mountain Horses are moderate in height, bone and proportions; Tennessee Walking Horses are taller and longer-lined with a long shoulder, hip and underline; Appaloosas retain sound versatile stock-horse conformation independently of leopard-complex markings. Prompts explicitly reject a shared generic AI-horse anatomy.

Every new LE Store horse enters at exactly two game-years old. Each horse also has a permanent diploid genotype: one allele pair per modeled locus and a breed-composition record. A bred foal independently inherits one allele at each locus from its sire and one from its dam; phenotype is then derived from that exact inherited genotype. Recessive carriers therefore remain meaningful even when the associated color or disorder is not visible.

Mature height is a permanent heritable phenotype measured at the withers in hands. Legacy Equine models directional alleles at four major size-associated loci—LCORL, HMGA2, ZFAT, and LASP1—on top of a breed-specific height range. Foundation horses receive independently varied allele pairs. A foal inherits one height allele at every locus from each parent, so players can select taller or shorter breeding stock over generations while offspring still show realistic variation and remain bounded by their breed or parental cross. The game labels these as gameplay height alleles rather than representing them as commercial diagnostic test results.

The modeled color system covers Extension and Agouti base color; Cream and Pearl dosage/interaction; Dun, Champagne, Silver, Gray, Roan, Mushroom; Tobiano, Frame Overo, Sabino 1, Splashed White variants, Leopard Complex/PATN1, and selected Dominant White variants. Foundation allele frequency is breed-biased and deliberately rare for unusual variants; breeding percentages are calculated from the two selected parents rather than a global rarity roll.

Before breeding, the server returns exact Mendelian percentages for inherited variants and known modeled lethal combinations. Breeding involving a possible lethal genotype requires explicit player confirmation. If the actual allele draw is lethal, the transaction creates no horse, changes no cooldown, and charges no fee. Modeled non-viable combinations are homozygous Frame Overo, W5, W10, W13, W22, GBED, SCID, LFS, and OAAM. HERDA, HYPP, PSSM1, and CA are tracked inherited disorders but are not silently treated as embryonic lethal.

Crossbred foals retain ancestry percentages across generations. Current registry-style display rules include Anglo-Arabian, Appendix Quarter Horse, Quarab, Morab, and AraAppaloosa; other crosses receive an honest `Parent Breed × Parent Breed Cross` label rather than an invented registry name. The rule table is data-driven so additional documented registries can be added later.

Named cross outcomes carry their recognition basis and source. “Formal registry,” “registration pathway,” and “documented named cross” are deliberately distinct: the game never implies that every genetic cross is automatically eligible for real-world papers. Breed artwork likewise uses registry-sourced conformation, movement, temperament, height, and restriction data. Individual genetics remain the source of truth for color and pattern.

Training raises one Developed Stat by one, once per 20 real hours per horse, and never changes its Birth Stat. No care meters exist. Foals arrive immediately. Each foal Birth Stat is the rounded average of the sire's and dam's Developed values plus an independently configured inheritance roll, currently −6 to +6, floored at one. Tack, Farrier, massage/condition, and all other temporary modifiers are excluded from inheritance. There is no regression toward Foundation values: intentional line improvement across developed generations is core gameplay. The mare receives a ten-real-day cooldown. No arbitrary 100-point stat cap exists.

Breeding age is derived exclusively from each horse's authoritative `birth_date` using the normal accelerated game clock (30 game days per real day). Mares and stallions are eligible from exact age 3 through the completion of age 25 (`3 <= age < 26`). Before every breeding, the server locks and independently validates both parents; younger, age-26-or-older, or retired horses cannot create a foal, incur a fee, or receive a cooldown. Existing pedigrees, progeny, and breeding records remain visible permanently.

One real day advances game age by 30 days. Breeding starts at age three and ends at age 30. Horses and pedigree records are never deleted due to age.

## Alpha 0.2 candidates

Stud services between players, tack catalog and equipment UI, direct messaging, admin custom-horse tools, show seasons, and richer community moderation.

## Player features

Every account may change its stable name and biography while retaining its permanent LE account number. A unique 3–24 character username identifies the player in community conversations. The Training Center exposes the existing 20-hour stat-training loop. Automated shows accept owned horses and calculate discipline-specific entry scores. The shared player marketplace transfers the exact listed horse and LE Dollars transactionally between buyer and seller. Community posts and replies are persistent and attributed to username, stable, and historical account number.

Ranch artwork, player avatars, and horse profile images are three independent media identities. Players may upload JPG, PNG, WebP, or GIF files up to 5 MB. Ranch images appear as stable-home artwork, avatars represent usernames in community spaces, and each horse retains its own image. Changing one never changes either of the others.

LE Account #1 is the permanent owner administrator. Administrators have a server-authorized console for ledgered LE balance adjustments and unrestricted custom horse creation, including owner, species label, breed, age, sex, phenotype, genetics, artwork URL, and every base stat. Only Account #1 may grant or revoke administrator status; Account #1 cannot be demoted. Ordinary clients cannot call these operations successfully without a current database administrator role.

## Visual direction

Legacy Equine uses a welcoming purple and lilac game-world palette, rounded typography, soft cards, prominent horse artwork, playful currency presentation, and accessible purple focus states. The intended mood is a polished modern continuation of social browser horse games: warm and lightly nostalgic, never corporate, sterile, or preschool-like. Shared CSS tokens control color, radius, and shadow values so future screens stay visually consistent.
# Professional Services

The player recalls Ludus Equinus may have let accounts develop service professions such as Veterinarian, Farrier, and Trainer. This is classified as **Probable firsthand Ludus recollection**, not confirmed archival fact. Legacy Equine intentionally expands the idea with Farrier, Veterinarian, Trainer, and Equine Massage Therapist; Massage Therapist is an LE addition.

Each profession progresses independently through exactly Basic, Proficient, Advanced, and Professional. Advancement always requires Study, a passing certification test, and the configured qualifying completed-service total (initially 0, 10, 25, and 50). These are explicitly Legacy Equine Game Certifications and are not real-world licenses or qualifications.

Certified players choose prices inside administrator-configured ranges, can offer services to other stables, and can self-service their horses. Paid services transfer LED atomically; self-service never creates LED and initially earns 50% qualifying credit. Horse/service cooldowns prevent farming. Certification, lifetime client and self-service records, availability, and permanent horse service history are retained.

Horse stats are always visible. Each of the exactly seven data-driven stats exposes an immutable Birth value, permanent Development, derived Developed value, tack, Farrier, massage/condition, other temporary effects, and derived Effective value. Breeding uses Developed Stats; shows use Effective Stats. Temporary service and equipment effects never modify genetic or breeding values. Stats may legitimately exceed 100 or 400 through long-term line improvement and are never rendered as percentages of a fixed ceiling.

# Horse Height

Height uses standard equine hand notation: one hand is four inches, and the suffix is inches rather than a base-ten decimal. Valid progressions are `14h`, `14.1h`, `14.2h`, `14.3h`, then `15h`. Values such as `14.4h` through `14.9h` are invalid and must normalize into the next hand. Breed-specific minimum and maximum heights remain data-driven so future breeds can extend the supported range.
A hand is four inches. Heights are stored as total inches and displayed in canonical hands notation (`14h`, `14.1h`, `14.2h`, `14.3h`, `15h`) rather than decimal hands.

# Closed-loop LED Economy

LE Dollars are game currency only. LED can never be withdrawn, redeemed, cashed out, converted back to USD, or treated as money or property. Any future USD purchase of LED is one-way. The Legacy Equine Treasury and Legacy Equine Show Fund are persistent institutional balances, never player accounts, and every inflow/outflow is recorded in the system-fund ledger.

Professional enrollment is permanent and costs 500 LED for Farrier, Trainer, and Equine Massage Therapist, or 750 LED for Veterinarian. Certification exams cost 250 / 500 / 1,000 / 2,000 LED by level. Submission charges the fee transactionally and failures do not refund it. Insufficient funds never remove study progress. These fees split by configurable percentages, initially 50% Show Fund and 50% Treasury.

# Player-created Shows

Any stable may create a show with a name, data-driven discipline, Career Point tier, future date, entry fee, optional entry cap, and description. Shows run at midnight in `America/New_York`, with server-side processing. Eligibility is snapshotted when the horse enters; the default limit is one horse per owner per show.

Initial disciplines are Hunters, Jumpers, Dressage, Halter, Reining, Western Pleasure, Trail, Driving, Steeplechase, Fox Hunting, Racing, and Cross Country. Their applicable-stat records are the **Legacy Equine provisional discipline mappings**: Hunters (Agility, Temperament, Conformation, Intelligence); Jumpers (Agility, Strength, Speed, Intelligence); Dressage (Agility, Temperament, Intelligence, Conformation); Halter (Conformation, Temperament, Strength); Reining (Agility, Temperament, Intelligence, Strength); Western Pleasure (Temperament, Conformation, Intelligence, Agility); Trail (Temperament, Intelligence, Agility, Endurance); Driving (Strength, Temperament, Endurance, Intelligence); Steeplechase (Speed, Endurance, Agility, Strength); Fox Hunting (Endurance, Agility, Temperament, Intelligence); Racing (Speed, Endurance, Strength); and Cross Country (Endurance, Agility, Strength, Temperament). These are initial balance values, not recovered Ludus Equinus formulas, and remain database-configurable.

Performance is deterministic. Competition Score is the weighted average—not the sum—of only the discipline’s applicable Effective Stats. Effective values include permanent training, tack, and active configured professional-service effects; these bonuses never alter inherited breeding values. Highest score wins. Exact ties use effective score, trained/base contribution, Career Points at entry, entry time, then horse ID. First, second, and third are prominently named Win, Place, and Show. Career Points remain separate from stats.

Completed result rows are permanent and authoritative. They snapshot horse name plus owner stable name/account at competition time, preserve the effective-stat breakdown, score, placing, Career Points, and LED prize, and are idempotent under processing retries. Public horse Show Records derive Starts, Wins, Places, Shows, other placings, Career Points, earnings, rates, discipline records, and history from those rows. Completed shows remain searchable in the permanent Show Archive. Show-age limits remain independently configurable/provisional and must not inherit breeding-age rules by assumption.

Players may enter every owned horse independently eligible for a show; there is no per-owner entry cap. The multi-horse selector separates eligible, already-entered, and ineligible horses with reasons, and previews the per-horse fee, batch total, current balance, and resulting balance. `enter_player_show_batch` validates and locks the entire distinct horse set, show, total horse-entry maximum, and account balance before creating or charging anything. A failed validation rolls back the full batch. Each horse receives its own entry and ledger charge.

Competition tiers are strict, database-driven Career Point divisions. `get_horse_competition_tier` is authoritative for new entry eligibility, so horses cannot enter above or below their current division. Entry rows permanently snapshot Career Points and tier at entry; a later level-up affects future entries without invalidating a previously legitimate entry. Multiple horses from one stable are scored independently and may earn Win, Place, and Show together.

# Community Chat Rooms

Community consists of database-managed rooms with persistent, paginated message history and near-real-time updates. Authenticated stable identity, permanent account number, avatar, and Community role are supplied by the server. Players cannot create rooms or impersonate another identity. Initial rooms are General, Horse Sales & Breeding, Shows, Artwork, Professional Services, and Help.

Community Admins and the Owner can create, rename, reorder, deactivate, archive, lock, and make rooms read-only. Moderators, Admins, and the Owner can hide or restore messages and issue room or global timeouts. Moderation and room administration are audited rather than silently deleted. Community roles never grant Treasury authority. Messages are plain text, limited to 1,000 characters, rate-limited, and protected against duplicate spam.

# Legacy Equine Bank

The player-facing financial area is the **Bank**, permanently available in the main game navigation. It shows Current Balance, lifetime LED Earned and Spent, and paginated transaction history with game-friendly descriptions, categories, dates, direction, related entities, and resulting balances. “Ledger” remains internal accounting terminology only. Treasury and Show Fund retain their institutional names. LED is closed-loop: future USD → LED purchase is permitted, while cash-out, withdrawal, redemption, and LED → USD are permanently prohibited.

# Horse Artwork Quality Assurance

Production horse artwork uses an Approved Breed Template → Controlled Visual Variation pipeline. Every variation must begin with an active, human-approved breed/body/sex template and preserve its skeletal proportions, limb and hoof placement, balance, conformation, framing, and pose; image generation may change only genetics-driven coat, dilution, pattern, markings, and mane/tail appearance. Unconstrained text-to-image horse generation is prohibited. Only QA-approved variations may be published. If no applicable approved breed template exists or any edit fails anatomy, conformation, phenotype, framing, background, or text/signature QA, the official generic Foundation horse is shown. Correct anatomy always outranks uniqueness.

Horse template candidates have pending, approved, or rejected review state and are separately active/inactive. Owner/Admin template management supports upload/replacement, breed/body archetype, optional sex, pose, review notes, approval/rejection, activation, and artwork-only Foundation batch regeneration. Horse artwork records retain pending, generated, approved, needs-review, rejected, or fallback quality status plus the source template. Regeneration never changes the horse's identity, genetics, phenotype, markings, stats, pedigree, ownership, or other gameplay data. Horse assets contain no ground, objects, colored blobs, scenery, text, signature, watermark, logo, or artist mark; transparency is preferred only when it can preserve the entire silhouette and markings reliably.

# Horse Profile Navigation

Horse profiles use independent, URL-addressable views for Overview, Stats, Training, Shows, Farrier, Health, Pedigree, Progeny, and Breeding. Overview remains horse-focused and always exposes all seven effective stats through one compact AGI/SPD/END/TMP/STR/INT/CON strip. Hover and tap breakdowns disclose base, permanent training, tack, Farrier, condition/service, and effective values. Detailed stat bars contain no training controls; all training actions, cooldowns, and history live in Training. Show records, professional care, ancestry, offspring, and breeding controls appear only in their respective views.

Stable horse listings use bounded, anatomy-safe image regions and compact browser-simulation cards rather than collectible-card styling. Listings expose identity and restrained Career Points/tier information; detailed stats stay on the horse profile. Cards and dense compact rows share the same component. Stable listings support name search plus breed, sex, age, origin, show-tier, and breeding-eligibility filters, with sorting by identity, age, recency, Career Points, or any stat. Store inventory retains its distinct shopping layout.
