# Legacy Equine Gameplay Specification — Alpha 0.1

## Status labels

- **Confirmed inspiration:** ownership, training, breeding, pedigrees, and community are the intended genre pillars; no proprietary implementation is reproduced.
- **Strong player recollection:** foundation horses cost approximately 1,000 and mares rested roughly one to two weeks.
- **Legacy Equine modernization:** timestamp-derived aging, permanent audit ledger, responsive interface, and server-authoritative actions.
- **Provisional:** seven stats are Agility, Speed, Endurance, Temperament, Strength, Intelligence, and Conformation. The last three await archival confirmation.
- **Unresolved:** exact historical aging rate, training tickets, retirement thresholds, and original stat names.

## Alpha rules

Configuration lives in `lib/game/config.ts`. New stables receive 3,000 LE Dollars. The introductory store permits three foundation purchases at 1,000 each. Normal foundation stats are 10–15 with a 6% outlier roll spanning 7–18. Every random process accepts a seeded generator.

Public LE account numbers are permanent, positive, unique, and assigned atomically in genuine stable-creation order from #1. Twisted Tree Ranch is LE Account #1. Numbers are never edited or recycled. Service-role-marked automated test identities receive no public number and never advance the production sequence.

### Shared LE Store inventory

The production LE Store maintains six globally shared Foundation horses, configurable from five to eight. Each is a real, server-generated horse with persistent identity, breed, sex, age, color, stats, artwork, price, and generation time before purchase. Players inspect every stat and purchase the exact horse shown. Inventory rotates after 60 minutes when next accessed; unsold rows become historical `expired` records. A sale atomically locks and transfers that horse, records payment, marks its inventory record sold, and fills only the empty slot. The three-horse introductory account limit remains distinct from global inventory size.

Store Foundation horses are intentionally unnamed. Their database identity, breed, appearance, and stats persist before purchase, but the display name remains `Unnamed Foundation Horse`. After purchase, the owner gives the horse an editable individual name from its horse profile.

Every new LE Store horse enters at exactly two game-years old. Each horse also has a permanent diploid genotype: one allele pair per modeled locus and a breed-composition record. A bred foal independently inherits one allele at each locus from its sire and one from its dam; phenotype is then derived from that exact inherited genotype. Recessive carriers therefore remain meaningful even when the associated color or disorder is not visible.

The modeled color system covers Extension and Agouti base color; Cream and Pearl dosage/interaction; Dun, Champagne, Silver, Gray, Roan, Mushroom; Tobiano, Frame Overo, Sabino 1, Splashed White variants, Leopard Complex/PATN1, and selected Dominant White variants. Foundation allele frequency is breed-biased and deliberately rare for unusual variants; breeding percentages are calculated from the two selected parents rather than a global rarity roll.

Before breeding, the server returns exact Mendelian percentages for inherited variants and known modeled lethal combinations. Breeding involving a possible lethal genotype requires explicit player confirmation. If the actual allele draw is lethal, the transaction creates no horse, changes no cooldown, and charges no fee. Modeled non-viable combinations are homozygous Frame Overo, W5, W10, W13, W22, GBED, SCID, LFS, and OAAM. HERDA, HYPP, PSSM1, and CA are tracked inherited disorders but are not silently treated as embryonic lethal.

Crossbred foals retain ancestry percentages across generations. Current registry-style display rules include Anglo-Arabian, Appendix Quarter Horse, Quarab, Morab, and AraAppaloosa; other crosses receive an honest `Parent Breed × Parent Breed Cross` label rather than an invented registry name. The rule table is data-driven so additional documented registries can be added later.

Training raises one base stat by one, once per 20 real hours per horse. No care meters exist. Foals arrive immediately. Each foal stat is the rounded parental average plus an independent integer roll from −6 to +6, floored at one. A configurable 25% chance of a one-point regression is applied: the 100,000-breeding simulation showed that the floor otherwise produced a 2.47-point upward drift after ten generations. This preserves the parental-average model while offsetting that boundary effect. The mare receives a ten-real-day cooldown. No generational bonus is applied.

One real day advances game age by 30 days. Breeding starts at age three and ends at age 30. Horses and pedigree records are never deleted due to age.

## Alpha 0.2 candidates

Stud services between players, tack catalog and equipment UI, direct messaging, admin custom-horse tools, show seasons, and richer community moderation.

## Player features

Every account may change its stable name and biography while retaining its permanent LE account number. A unique 3–24 character username identifies the player in community conversations. The Training Center exposes the existing 20-hour stat-training loop. Automated shows accept owned horses and calculate discipline-specific entry scores. The shared player marketplace transfers the exact listed horse and LE Dollars transactionally between buyer and seller. Community posts and replies are persistent and attributed to username, stable, and historical account number.

Ranch artwork, player avatars, and horse profile images are three independent media identities. Players may upload JPG, PNG, WebP, or GIF files up to 5 MB. Ranch images appear as stable-home artwork, avatars represent usernames in community spaces, and each horse retains its own image. Changing one never changes either of the others.

## Visual direction

Legacy Equine uses a welcoming purple and lilac game-world palette, rounded typography, soft cards, prominent horse artwork, playful currency presentation, and accessible purple focus states. The intended mood is a polished modern continuation of social browser horse games: warm and lightly nostalgic, never corporate, sterile, or preschool-like. Shared CSS tokens control color, radius, and shadow values so future screens stay visually consistent.
