# Architecture

Legacy Equine uses Next.js App Router and TypeScript. UI code is in `app/`; framework-independent rules are in `lib/game/`. `config.ts` is the balance source of truth, `simulation.ts` contains deterministic generation, inheritance, effective-stat, cooldown, and aging functions, and `types.ts` defines domain objects.

The checked-in Supabase migration creates stable, horse, ledger, training, inventory, and competition tables with real foreign keys. Horse parents use restricted foreign keys so ownership changes cannot alter ancestry and deletion cannot break pedigrees. Sequential stable numbers use a PostgreSQL identity and are never recycled. JSONB keeps stat and trait definitions data-driven.

RLS allows public reading of stable and horse profiles, limits ordinary users to owned data, and deliberately provides no direct insert policies for protected game records. Production purchase, training, and breeding writes must be implemented as security-definer RPC functions so balance checks, cooldowns, ownership, generated stats, and ledger entries share one database transaction.

The current local Alpha runs in a transparent browser-persistence mode so the complete game loop can be evaluated before cloud credentials exist. Production activation requires a dedicated Supabase project, applying migrations, environment variables, and replacing the local adapter with authenticated RPC calls. Vercel builds from the repository; migrations stay version controlled and should run in CI before deployment.

Age is derived from `birth_date` and the configured clock rather than mass-updating rows. Cooldown eligibility similarly derives from `last_bred_at`, so time progresses without cron jobs.

## Genetics and breed identity

`horses.genetics` stores allele pairs as JSONB and `horses.breed_composition` stores fractional ancestry independently from the displayed breed label. Foundation generation creates the genotype first and derives the visible color from it. Breeding locks both parents, independently selects one allele from each parent at every locus, rejects a modeled lethal result before any balance or cooldown mutation, and then persists that exact genotype and phenotype on the foal. This makes previews probabilistic while the resulting foal remains permanent and reproducible from its stored genes.

All horse artwork uses a genotype → calculated phenotype → registry-derived breed archetype → structured visual description → image-worker pipeline. Persistent `markings` and `visual_phenotype` live on every horse; the legacy-named `store_horse_image_jobs` table is the shared retryable artwork queue for Foundation inventory, owned horses, bred foals, and Admin Custom horses. The authenticated Next.js worker claims eligible jobs with the Supabase service role and sends the structured phenotype through Vercel AI Gateway without an anatomy reference image that could homogenize body type. It stores the finished asset in `legacy-equine-media/generated/horses`. The security-definer completion transaction replaces only a generic placeholder or an earlier system-generated URL; a player upload made during processing always wins and is never overwritten. AI failures never mutate horse gameplay data.

`get_breeding_genetic_preview` computes locus-level inheritance and combined lethal probability from the selected pair. It is informational; `breed_horses` repeats all ownership, eligibility, lethal, balance, and cooldown enforcement transactionally. `breed_cross_rules` separates documented breed naming from genetics, while breed composition is combined mathematically over generations.

## Shared LE Store inventory

Foundation inventory is persisted in `horses` plus `store_inventory`; store-owned horses have no player owner until checkout. `store_settings` configures the 5–8 supported inventory size (default six), 60-minute rotation, and price. `foundation_breeds` is data-driven. Reads call `get_store_inventory`, which refreshes expired stock under a transaction-scoped advisory lock. Checkout locks the inventory, stable, and horse rows, transfers the exact viewed horse, records the ledger entry, marks the listing sold, and creates one replacement. Sold and expired listing rows remain as audit history. Competing purchases and rotations serialize on the same advisory lock.

## Player systems

Stable profiles keep immutable `account_number` identity separate from editable names, biographies, and case-insensitively unique community usernames. Shows use the existing competition tables and server-authoritative scoring RPCs. `marketplace_listings` records active, sold, and cancelled offers; checkout locks the listing and both accounts, transfers the existing horse, and writes balanced buyer/seller ledger entries in one transaction. `forum_posts` stores conversations and replies while read RPCs join only the public identity fields needed by the community UI. Direct table writes remain unavailable to normal clients.

Player media uses the dedicated public `legacy-equine-media` Supabase Storage bucket. Object paths begin with the authenticated user ID and storage policies prevent cross-account inserts, updates, and deletion. Ranch images and avatars are separate stable columns; horse images remain attached to individual horse rows. Upload validation permits image MIME types only and caps files at 5 MB.

## Administration

The `stables.is_admin` role is checked inside security-definer RPCs on every privileged operation. Account #1 is the protected owner authority and is the only account allowed to grant or revoke administrators. Admin balance changes update the locked stable balance and write the same signed amount to `currency_ledger`; custom horses are created directly as permanent `Admin Custom` records. The UI merely exposes these RPCs and is not an authorization boundary.
