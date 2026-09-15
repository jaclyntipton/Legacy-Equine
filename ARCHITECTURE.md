# Architecture

Legacy Equine uses Next.js App Router and TypeScript. UI code is in `app/`; framework-independent rules are in `lib/game/`. `config.ts` is the balance source of truth, `simulation.ts` contains deterministic generation, inheritance, effective-stat, cooldown, and aging functions, and `types.ts` defines domain objects.

The checked-in Supabase migration creates stable, horse, ledger, training, inventory, and competition tables with real foreign keys. Horse parents use restricted foreign keys so ownership changes cannot alter ancestry and deletion cannot break pedigrees. Sequential stable numbers use a PostgreSQL identity and are never recycled. JSONB keeps stat and trait definitions data-driven.

RLS allows public reading of stable and horse profiles, limits ordinary users to owned data, and deliberately provides no direct insert policies for protected game records. Production purchase, training, and breeding writes must be implemented as security-definer RPC functions so balance checks, cooldowns, ownership, generated stats, and ledger entries share one database transaction.

The current local Alpha runs in a transparent browser-persistence mode so the complete game loop can be evaluated before cloud credentials exist. Production activation requires a dedicated Supabase project, applying migrations, environment variables, and replacing the local adapter with authenticated RPC calls. Vercel builds from the repository; migrations stay version controlled and should run in CI before deployment.

Age is derived from `birth_date` and the configured clock rather than mass-updating rows. Cooldown eligibility similarly derives from `last_bred_at`, so time progresses without cron jobs.

## Shared LE Store inventory

Foundation inventory is persisted in `horses` plus `store_inventory`; store-owned horses have no player owner until checkout. `store_settings` configures the 5–8 supported inventory size (default six), 60-minute rotation, and price. `foundation_breeds` is data-driven. Reads call `get_store_inventory`, which refreshes expired stock under a transaction-scoped advisory lock. Checkout locks the inventory, stable, and horse rows, transfers the exact viewed horse, records the ledger entry, marks the listing sold, and creates one replacement. Sold and expired listing rows remain as audit history. Competing purchases and rotations serialize on the same advisory lock.
