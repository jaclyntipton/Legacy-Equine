# Legacy Equine Gameplay Specification — Alpha 0.1

## Status labels

- **Confirmed inspiration:** ownership, training, breeding, pedigrees, and community are the intended genre pillars; no proprietary implementation is reproduced.
- **Strong player recollection:** foundation horses cost approximately 1,000 and mares rested roughly one to two weeks.
- **Legacy Equine modernization:** timestamp-derived aging, permanent audit ledger, responsive interface, and server-authoritative actions.
- **Provisional:** seven stats are Agility, Speed, Endurance, Temperament, Strength, Intelligence, and Conformation. The last three await archival confirmation.
- **Unresolved:** exact historical aging rate, training tickets, retirement thresholds, and original stat names.

## Alpha rules

Configuration lives in `lib/game/config.ts`. New stables receive 3,000 LE Dollars. The introductory store permits three foundation purchases at 1,000 each. Normal foundation stats are 10–15 with a 6% outlier roll spanning 7–18. Every random process accepts a seeded generator.

Training raises one base stat by one, once per 20 real hours per horse. No care meters exist. Foals arrive immediately. Each foal stat is the rounded parental average plus an independent integer roll from −6 to +6, floored at one. A configurable 25% chance of a one-point regression is applied: the 100,000-breeding simulation showed that the floor otherwise produced a 2.47-point upward drift after ten generations. This preserves the parental-average model while offsetting that boundary effect. The mare receives a ten-real-day cooldown. No generational bonus is applied.

One real day advances game age by 30 days. Breeding starts at age three and ends at age 30. Horses and pedigree records are never deleted due to age.

## Alpha 0.2 candidates

Automated shows, horse trading, stud services between players, tack catalog and equipment UI, admin custom-horse UI, messaging, and community spaces.
