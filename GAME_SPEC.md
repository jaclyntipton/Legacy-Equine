# Legacy Equine Gameplay Specification — Alpha 0.1

## Status labels

- **Confirmed inspiration:** ownership, training, breeding, pedigrees, and community are the intended genre pillars; no proprietary implementation is reproduced.
- **Strong player recollection:** foundation horses cost approximately 1,000 and mares rested roughly one to two weeks.
- **Legacy Equine modernization:** timestamp-derived aging, permanent audit ledger, responsive interface, and server-authoritative actions.
- **Provisional:** seven stats are Agility, Speed, Endurance, Temperament, Strength, Intelligence, and Conformation. The last three await archival confirmation.
- **Unresolved:** exact historical aging rate, training tickets, retirement thresholds, and original stat names.

## Alpha rules

Configuration lives in `lib/game/config.ts`. New stables receive 4,000 LE Dollars, and every existing player was raised to a minimum 4,000 LE balance for the Alpha economy. The introductory store permits three foundation purchases at 1,000 each. Normal foundation stats are 10–15 with a 6% outlier roll spanning 7–18. Every random process accepts a seeded generator.

Public LE account numbers are permanent, positive, unique, and assigned atomically in genuine stable-creation order from #1. Twisted Tree Ranch is LE Account #1. Numbers are never edited or recycled. Service-role-marked automated test identities receive no public number and never advance the production sequence.

### Shared LE Store inventory

The production LE Store maintains eight globally shared Foundation horses, one slot for each currently established Foundation breed. The architecture remains configurable from five to eight, and future breed additions can expand that supported range deliberately. Each listing is a real, server-generated horse with persistent identity, breed, sex, age, color, stats, artwork, price, and generation time before purchase. Players inspect every stat and purchase the exact horse shown. Inventory rotates after 60 minutes when next accessed; unsold rows become historical `expired` records. A sale atomically locks and transfers that horse, records payment, marks its inventory record sold, and fills only the empty slot. The three-horse introductory account limit remains distinct from global inventory size.

Store Foundation horses are intentionally unnamed. Their database identity, breed, appearance, and stats persist before purchase, but the display name remains `Unnamed Foundation Horse`. After purchase, the owner gives the horse an editable individual name from its horse profile.

Every horse created in Legacy Equine receives persistent face and four-leg markings plus individual generated artwork, including Foundation inventory, purchased horses, bred foals, and administrator-created horses. The genetics engine resolves coat color and patterns first, then produces a structured visual phenotype containing breed/body archetype, sex, age, coat, mane/tail, pattern, and exact markings. A server-only image worker uses that structure without imposing one reference horse's anatomy on every breed. The resulting raster asset is stored once on that horse and follows it through ownership changes; page views never reroll identity, genes, markings, stats, or artwork. Failed jobs retain the exact horse and placeholder for a safe retry. A player-supplied horse image is a deliberate customization and is never replaced by the generator.

Breed type is the highest-priority artwork constraint. Foundation breeds must be recognizable from anatomy and silhouette before color: Arabians are smaller, fine-boned, short-backed and distinctly refined with an authentic gentle dish and high tail; Quarter Horses are lower, shorter, close-coupled and powerfully stocky; Thoroughbreds are tall, lean, long-legged and rangy; Hanoverians are tall rectangular warmbloods with greater bone and substance while remaining athletic; Morgans are compact, deep-bodied, proud and upright; Rocky Mountain Horses are moderate in height, bone and proportions; Tennessee Walking Horses are taller and longer-lined with a long shoulder, hip and underline; Appaloosas retain sound versatile stock-horse conformation independently of leopard-complex markings. Prompts explicitly reject a shared generic AI-horse anatomy.

Every new LE Store horse enters at exactly two game-years old. Each horse also has a permanent diploid genotype: one allele pair per modeled locus and a breed-composition record. A bred foal independently inherits one allele at each locus from its sire and one from its dam; phenotype is then derived from that exact inherited genotype. Recessive carriers therefore remain meaningful even when the associated color or disorder is not visible.

Mature height is a permanent heritable phenotype measured at the withers in hands. Legacy Equine models directional alleles at four major size-associated loci—LCORL, HMGA2, ZFAT, and LASP1—on top of a breed-specific height range. Foundation horses receive independently varied allele pairs. A foal inherits one height allele at every locus from each parent, so players can select taller or shorter breeding stock over generations while offspring still show realistic variation and remain bounded by their breed or parental cross. The game labels these as gameplay height alleles rather than representing them as commercial diagnostic test results.

The modeled color system covers Extension and Agouti base color; Cream and Pearl dosage/interaction; Dun, Champagne, Silver, Gray, Roan, Mushroom; Tobiano, Frame Overo, Sabino 1, Splashed White variants, Leopard Complex/PATN1, and selected Dominant White variants. Foundation allele frequency is breed-biased and deliberately rare for unusual variants; breeding percentages are calculated from the two selected parents rather than a global rarity roll.

Before breeding, the server returns exact Mendelian percentages for inherited variants and known modeled lethal combinations. Breeding involving a possible lethal genotype requires explicit player confirmation. If the actual allele draw is lethal, the transaction creates no horse, changes no cooldown, and charges no fee. Modeled non-viable combinations are homozygous Frame Overo, W5, W10, W13, W22, GBED, SCID, LFS, and OAAM. HERDA, HYPP, PSSM1, and CA are tracked inherited disorders but are not silently treated as embryonic lethal.

Crossbred foals retain ancestry percentages across generations. Current registry-style display rules include Anglo-Arabian, Appendix Quarter Horse, Quarab, Morab, and AraAppaloosa; other crosses receive an honest `Parent Breed × Parent Breed Cross` label rather than an invented registry name. The rule table is data-driven so additional documented registries can be added later.

Named cross outcomes carry their recognition basis and source. “Formal registry,” “registration pathway,” and “documented named cross” are deliberately distinct: the game never implies that every genetic cross is automatically eligible for real-world papers. Breed artwork likewise uses registry-sourced conformation, movement, temperament, height, and restriction data. Individual genetics remain the source of truth for color and pattern.

Training raises one base stat by one, once per 20 real hours per horse. No care meters exist. Foals arrive immediately. Each foal stat is the rounded parental average plus an independent integer roll from −6 to +6, floored at one. A configurable 25% chance of a one-point regression is applied: the 100,000-breeding simulation showed that the floor otherwise produced a 2.47-point upward drift after ten generations. This preserves the parental-average model while offsetting that boundary effect. The mare receives a ten-real-day cooldown. No generational bonus is applied.

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

Horse stats are always visible. Effective values must expose layers separately: inherited base, permanent development, tack, farrier, massage/condition, and other temporary effects. Temporary service effects never modify genetic or breeding values.
