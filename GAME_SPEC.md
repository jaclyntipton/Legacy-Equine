# Legacy Equine Gameplay Specification — Alpha 0.1

## Status labels

- **Confirmed inspiration:** ownership, training, breeding, pedigrees, and community are the intended genre pillars; no proprietary implementation is reproduced.
- **Strong player recollection:** foundation horses cost approximately 1,000 and mares rested roughly one to two weeks.
- **Legacy Equine modernization:** timestamp-derived aging, permanent audit ledger, responsive interface, and server-authoritative actions.
- **Primary-source confirmed:** Ludus Equinus used exactly seven separate horse stats. Surviving player-bred Quarter Horse artwork for “Flying On My Raptor” records seven birth values: 218, 220, 220, 400, 224, 270, and 220.
- **Provisional names:** Legacy Equine currently uses Agility, Speed, Endurance, Temperament, Strength, Intelligence, and Conformation. The count is confirmed; the exact historical names and order remain under archival investigation, so definitions stay data-driven and renameable without changing horse records.
- **Unresolved:** exact historical aging rate, training tickets, retirement thresholds, and original stat names/order.

## Alpha rules

Configuration lives in `lib/game/config.ts`. New public player accounts receive 3,000 LE Dollars, Level 1 with 0 Account XP, and the configured starter Stable capacity. Foundation Store purchases have no lifetime count limit: sufficient LED and an available stable stall are the only account constraints. Normal foundation stats are 10–15 with a 6% outlier roll spanning 7–18. Every random process accepts a seeded generator.

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

The modeled color system covers Extension and Agouti base color; Cream and Pearl dosage/interaction; Dun, Champagne, Silver, Gray, Roan, Mushroom; Tobiano, Frame Overo, Sabino 1, Splashed White variants, Leopard Complex/PATN1, and selected Dominant White variants. Foundation allele frequency is driven by the editable `breed_foundation_genetic_population` configuration: every breed/locus has an actual allele weight, rarity tier, and explicit inclusion/exclusion flag. American Paint Horse is a distinct Foundation breed and the primary population for loud stock-horse white patterns. Quarter Horses strongly favor traditional AQHA-type colors, while patterned Thoroughbreds are genuinely exceptional. Breeding ignores Foundation population weights and calculates inheritance exclusively from the two stored parent genotypes.

Before breeding, the server returns exact Mendelian percentages for inherited variants and known modeled lethal combinations. Breeding involving a possible lethal genotype requires explicit player confirmation. If the actual allele draw is lethal, the transaction creates no horse, changes no cooldown, and charges no fee. Modeled non-viable combinations are homozygous Frame Overo, W5, W10, W13, W22, GBED, SCID, LFS, and OAAM. HERDA, HYPP, PSSM1, and CA are tracked inherited disorders but are not silently treated as embryonic lethal.

Crossbred foals retain ancestry percentages across generations. Current registry-style display rules include Anglo-Arabian, Appendix Quarter Horse, Quarab, Morab, and AraAppaloosa; other crosses receive an honest `Parent Breed × Parent Breed Cross` label rather than an invented registry name. The rule table is data-driven so additional documented registries can be added later.

Named cross outcomes carry their recognition basis and source. “Formal registry,” “registration pathway,” and “documented named cross” are deliberately distinct: the game never implies that every genetic cross is automatically eligible for real-world papers. Breed artwork likewise uses registry-sourced conformation, movement, temperament, height, and restriction data. Individual genetics remain the source of truth for color and pattern.

Training raises one Developed Stat by one, once per 20 real hours per horse, and never changes its Birth Stat. No care meters exist. Foals arrive immediately. Each foal Birth Stat is the rounded average of the sire's and dam's Developed values plus an independently configured inheritance roll, currently −6 to +6, floored at one. Tack, Farrier, massage/condition, and all other temporary modifiers are excluded from inheritance. There is no regression toward Foundation values: intentional line improvement across developed generations is core gameplay. The mare receives a ten-real-day cooldown. No arbitrary 100-point stat cap exists.

Training and breeding age are derived exclusively from each horse's authoritative `birth_date` at one horse-year per 28 real days. Training is eligible from exact age 2 with no upper limit. Mares and stallions are breeding-eligible from exact age 2 through the instant before age 26 (`2 <= age < 26`). The server independently enforces every boundary using unrounded age.

One horse-year advances every 28 real days. Training and breeding start at exact age two; breeding retirement begins at exact age 26. Horses and pedigree records are never deleted due to age.

## Alpha 0.2 candidates

Stud services between players, tack catalog and equipment UI, direct messaging, admin custom-horse tools, show seasons, and richer community moderation.

## Player features

Every account may change its stable name and biography while retaining its permanent LE account number. A unique 3–24 character username identifies the player in community conversations. The Training Center exposes the existing 20-hour stat-training loop. Automated shows accept owned horses and calculate discipline-specific entry scores. The shared player marketplace transfers the exact listed horse and LE Dollars transactionally between buyer and seller. Community posts and replies are persistent and attributed to username, stable, and historical account number.

Ranch artwork, player avatars, and horse profile images are three independent media identities. Players may upload JPG, PNG, WebP, or GIF files up to 5 MB. Ranch images appear as stable-home artwork, avatars represent usernames in community spaces, and each horse retains its own image. Changing one never changes either of the others.

LE Account #1 is the permanent owner administrator. Administrators have a server-authorized console for ledgered LE balance adjustments and unrestricted custom horse creation, including owner, species label, breed, age, sex, phenotype, genetics, artwork URL, and every base stat. Only Account #1 may grant or revoke administrator status; Account #1 cannot be demoted. Ordinary clients cannot call these operations successfully without a current database administrator role.

Owner Account #1 may edit any horse through the server-authorized Horse Editor. Ordinary administrators do not inherit this power; Account #1 must grant the separate `horse_editor` permission. The editor covers identity, timestamp-derived age, sex (Mare, Stallion, Gelding), uncapped Birth and Permanent Development stats, genotype-driven phenotype, explicit visual overrides, compatible deterministic templates, breeding state, cycle-safe pedigree corrections, administrative ownership transfers, emergency Sanctuary restoration, Career Point corrections, and data-driven special traits. Sex, age, and genotype edits affect future rules only and never rewrite historical progeny or completed show records. High-impact edits require confirmation and a reason, and every mutation stores immutable old/new audit values.

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

Production per-horse generative AI is deprecated and disabled. Horse visuals follow a deterministic Approved Breed Template + Genetic Phenotype Layer pipeline. Every horse permanently stores a `visual_template_id`; a stable fingerprint covers template, authoritative phenotype, pattern, face, four independent leg markings, and separate mane and tail treatments. Mane and tail must be human-approved transparent hair artwork registered to the exact body master; recoloring broad body regions to imitate hair is prohibited. Body coat, leg points, mane, tail, face markings, leg markings, and patterns remain independent. Only approved and active layers may participate. Incomplete combinations display the branded non-illustrative Legacy Equine™ Horse Visual Pending state; genetically incorrect substitute horse artwork is prohibited.

The single Artwork Album provides hosted player artwork. Active subscribers receive an Admin-configurable base entitlement (default 100 images); free accounts default to zero hosted slots. Owner-granted bonus capacity is independent of Admin roles and, unless explicitly marked subscription-dependent, remains active without a subscription. Owner Account #1 has an explicit application-level unlimited entitlement. Unlimited affects image count only: every upload remains limited to approved JPEG/PNG/WebP types, 5 MB incoming size, 1200×1200 stored dimensions, and security/processing validation. Capacity reductions never delete artwork; an over-capacity album preserves existing images and blocks new reservations until capacity is restored or usage falls below the effective limit.

The visual taxonomy follows approved equine reference material rather than earlier generated LE artwork. Facial white distinguishes isolated snips, faint marks/stars, stars, strips, broken strips, star-plus-strip, blaze families, irregular blaze, and broad bald face; Medicine Hat belongs to Paint/white-pattern architecture, never ordinary facial white. Each LF/RF/LH/RH marking is attached to the horse's anatomical limb and independently supports coronet, white heel, half pastern, pastern, ankle, half sock, full sock, and high sock variants. Grulla is Dun acting on a black base, gray retains its underlying base and progresses with age, true roan remains distinct from gray/varnish, and dapple intensity is a non-genetic visual modifier. Pinto families and Leopard Complex families use separate combinable layer systems. Every required layer begins Missing in the per-master Visual Asset Requirements Matrix until artwork is uploaded, reviewed, approved, and explicitly promoted to Production.

Player custom artwork is stored independently and has display priority over the cached deterministic LE visual. Removing it restores the LE visual without deleting its template assignment or fingerprint. Store and bred horses use the same assignment rules, and no page view triggers generation.

Production horse artwork uses an Approved Breed Template → Controlled Visual Variation pipeline. Every variation must begin with an active, human-approved breed/body/sex template and preserve its skeletal proportions, limb and hoof placement, balance, conformation, framing, and pose; image generation may change only genetics-driven coat, dilution, pattern, markings, and mane/tail appearance. Unconstrained text-to-image horse generation is prohibited. Only QA-approved variations may be published. If no applicable approved breed template exists or any edit fails anatomy, conformation, phenotype, framing, background, or text/signature QA, the official generic Foundation horse is shown. Correct anatomy always outranks uniqueness.

Horse template candidates have pending, approved, or rejected review state and are separately active/inactive. Owner/Admin template management supports upload/replacement, breed/body archetype, optional sex, pose, review notes, approval/rejection, activation, and artwork-only Foundation batch regeneration. Horse artwork records retain pending, generated, approved, needs-review, rejected, or fallback quality status plus the source template. Regeneration never changes the horse's identity, genetics, phenotype, markings, stats, pedigree, ownership, or other gameplay data. Horse assets contain no ground, objects, colored blobs, scenery, text, signature, watermark, logo, or artist mark; transparency is preferred only when it can preserve the entire silhouette and markings reliably.

# Horse Profile Navigation

Horse profiles use independent, URL-addressable views for Overview, Stats, Training, Shows, Farrier, Health, Pedigree, Progeny, and Breeding. Overview remains horse-focused and always exposes all seven effective stats through one compact AGI/SPD/END/TMP/STR/INT/CON strip. Hover and tap breakdowns disclose base, permanent training, tack, Farrier, condition/service, and effective values. Detailed stat bars contain no training controls; all training actions, cooldowns, and history live in Training. Show records, professional care, ancestry, offspring, and breeding controls appear only in their respective views.

Stable horse listings use bounded, anatomy-safe image regions and compact browser-simulation cards rather than collectible-card styling. Listings expose identity and restrained Career Points/tier information; detailed stats stay on the horse profile. Cards and dense compact rows share the same component. Stable listings support name search plus breed, sex, age, origin, show-tier, and breeding-eligibility filters, with sorting by identity, age, recency, Career Points, or any stat. Store inventory retains its distinct shopping layout.

All primary full-horse artwork uses one shared containment renderer across Horse Profiles, Store, Stable, Progeny, Sanctuary, Marketplace, uploads, and administration. The complete native image is centered and scaled down within a light-lavender frame with 5% internal breathing room. Cropping, stretching, and aspect-ratio coercion are prohibited for generated, Foundation, and player-provided artwork; letterboxing is intentional.
# Account Progression — Alpha V1

Horse Career Points and Stable Account XP are separate permanent systems. Horse CP determines competition tier; Account XP determines Levels 1–50 and account capabilities. Level thresholds, weekly allowance values, show-hosting quotas, and unlocks are stored in `account_level_config`. XP continues as Lifetime XP after Level 50.

Account XP is awarded idempotently when show results become permanent: entry +1, first +10, second +6, third +3. Legitimate completed shows award the host +5, plus cumulative unique-stable bonuses of +3 at five, +5 at ten, and +10 at twenty. QA entries never award XP, CP, or LED.

The LE week begins Friday 12:00 AM America/New_York. Weekly show-hosting limits are 5 (Levels 1–14), 10 (15–29), 15 (30–44), 20 (45–49), and 25 (50); Account #1 has an owner override. Bulk show creation unlocks at Level 15, custom Stable layouts at Level 20, and advanced multi-show entry at Level 30. An active subscription may grant immediate use of the two bulk convenience tools but never increases weekly hosting quota. Ordinary multi-horse entry into one show remains available to every account.

Weekly Stable Allowance is claimed in Bank, never auto-deposited. Base values rise from 500 LED at Level 1 to 1,500 LED at Level 50 in configured five-level bands. Active subscribers receive +100 LED and may preserve up to six individual missed entitlements; preserved entitlements remain collectible after expiration. Free missed entitlements expire at the next Friday boundary. Each entitlement snapshots week, level, base, bonus, total, timestamps, protection, and status.

Full player-to-player economy access unlocks at Level 5. The server—not the client—enforces progression gates. One verified phone may be associated with only one Stable; IP data is a risk signal and never a sole uniqueness rule. Account lifecycle periods are configuration-driven.
# Store, Development, Equipment, Wellness, and Aging

The LE Store has separate Foundation Horses, Feed & Hay, Tack, and Stable Supplies departments. Foundation horses are shared global inventory organized by breed, with four active horses per enabled breed by default and independent server-authoritative hourly rotation. Every Foundation card exposes all seven stats; checkout transfers the exact horse transactionally and immediately refills only that breed.

Feed is optional permanent Development, limited to one qualifying feeding per horse per America/New_York calendar day. Missing a day has no penalty and does not bank attempts. Products configure server-side price, success probability, award range, and eligible stats. Every result is permanent history. Successful Feed Development contributes to Developed Stats and breeding.

Tack occupies Bridle, Saddle, Saddle Pad, or Leg Protection slots. Equipped bonuses contribute only to Effective Stats and show scoring; they never alter Birth or Developed Stats and are never inherited. Products and bonuses are data-driven and LED-only.

Wellness is independent of the seven stats: Health, Hooves, Recovery, and weighted Competition Readiness on a bounded 0–100 scale. Training wears Recovery; showing wears Recovery and Hooves. Recovery passively improves from elapsed time. Routine Vet care restores Health once per half horse-year; Farrier and Massage restore Hooves and Recovery respectively once per Friday–Thursday LE week. Professional certification controls configured maximum restoration, and service history records before/after Wellness.

Horse age is continuously timestamp-derived at one horse-year per 28 real days. Player display uses years/months, while training, breeding, and care windows use unrounded precision. Training and breeding begin at exactly age 2; breeding ends at exact age 26 while training continues.

The LE Store uses department-specific browsing. Foundation Horses use a compact, data-driven breed selector and a bounded scrolling result area; each card exposes all seven stats and exact persistent identity. Purchased Feed & Hay appears in the player's Feed Room and owned equipment appears in the Tack Room. Tack occupies one of four exclusive slots (bridle, saddle, saddle pad, leg protection), modifies Effective Stats only, remains owned while equipped, and is never inherited.

Horse visual production is human-supplied and review-led. Bulk PNG/WebP imports must match one exact registered master canvas, include transparency, pass validation, and begin in Review. Automated validation never grants Approval or Production status. The Owner may export the complete requirement manifest as CSV or JSON; missing artwork remains fallback-only and is never generated automatically.

The QH artist workspace provides separate Mare and Stallion ZIP starter packs using the immutable 1496×1051 masters, exact transparent canvases, manifests, naming/layer guides, and non-production anatomical overlays. Review uses full registered-resolution compositing with zoom/pan/layer toggles, temporary multi-layer previews, actual-asset contact sheets, per-asset Owner notes, explicit Needs Revision/Reject/Approve actions, version history, rollback, coverage counts, and a separate guarded Production promotion.

Stable Brands are non-stat provenance available to active subscribers, Owner #1, and accounts with explicit Brand Privilege. A unique reserved 2–4 character code and optional transparent mark are snapshotted permanently when an eligible stable purchases a Foundation horse or owns the dam when a foal is born. A later sale, transfer, subscription expiration, or Brand Mark update never rewrites a horse's historical Brand. Twisted Fox Ranch #1 permanently reserves `TFR`.
# Player information architecture

- **My Profile** is the player/account/social identity destination. Its permanent tabs are Profile, Artwork Album, and Settings. The header avatar/account identity always opens My Profile.
- **My Stable** is the owned-horse and physical-inventory management destination. Its permanent tabs are My Horses, Tack Room, Feed Room, and Supply Room.
- Feed and hay purchases route to Feed Room; tack routes to Tack Room; stable-supply SKUs route to Supply Room. Store pages never double as owned-inventory rooms.
- Horse profiles remain separate destinations. An owner may select profile artwork from their Artwork Album, an external permitted URL, or the horse's approved Legacy Equine visual.
- Public stable presentation is distinct from these authenticated management views.
