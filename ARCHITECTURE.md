# Architecture

Legacy Equine uses Next.js App Router and TypeScript. UI code is in `app/`; framework-independent rules are in `lib/game/`. `config.ts` is the balance source of truth, `simulation.ts` contains deterministic generation, inheritance, effective-stat, cooldown, and aging functions, and `types.ts` defines domain objects.

The checked-in Supabase migration creates stable, horse, ledger, training, inventory, and competition tables with real foreign keys. Horse parents use restricted foreign keys so ownership changes cannot alter ancestry and deletion cannot break pedigrees. Sequential stable numbers use a PostgreSQL identity and are never recycled. JSONB keeps stat and trait definitions data-driven.

RLS allows public reading of stable and horse profiles, limits ordinary users to owned data, and deliberately provides no direct insert policies for protected game records. Production purchase, training, and breeding writes must be implemented as security-definer RPC functions so balance checks, cooldowns, ownership, generated stats, and ledger entries share one database transaction.

The current local Alpha runs in a transparent browser-persistence mode so the complete game loop can be evaluated before cloud credentials exist. Production activation requires a dedicated Supabase project, applying migrations, environment variables, and replacing the local adapter with authenticated RPC calls. Vercel builds from the repository; migrations stay version controlled and should run in CI before deployment.

Age is derived from `birth_date` and the configured clock rather than mass-updating rows. Cooldown eligibility similarly derives from `last_bred_at`, so time progresses without cron jobs.

## Genetics and breed identity

`horses.genetics` stores allele pairs as JSONB and `horses.breed_composition` stores fractional ancestry independently from the displayed breed label. Foundation generation creates the genotype first and derives the visible color from it. Breeding locks both parents, independently selects one allele from each parent at every locus, rejects a modeled lethal result before any balance or cooldown mutation, and then persists that exact genotype and phenotype on the foal. This makes previews probabilistic while the resulting foal remains permanent and reproducible from its stored genes.

The stat count is primary-source confirmed at exactly seven while names and order remain provisional in `stat_definitions`. `horses.birth_stats` is immutable historical JSONB; `horses.stats` stores current permanent Developed values, with Development derived as the difference. Training changes only Developed and appends `training_log`. Effective values are derived from Developed plus tack and active service effects. Shows snapshot Effective values, while breeding transactionally reads only parental Developed values and applies the configurable `stat_system_config` inheritance range. Temporary modifiers cannot be inherited, and no schema or UI assumes a 100-point ceiling.

`horses.height_genetics` separately stores allele pairs for the LCORL, HMGA2, ZFAT, and LASP1 gameplay loci, while `mature_height_hands` stores the permanent expressed height. A before-insert trigger initializes Foundation/Admin horses or inherits one allele per parent for foals, applies small non-genetic variance, constrains the result through `breed_height_ranges` (or parental bounds for named crosses), and embeds the exact height into `visual_phenotype` for artwork generation.

All horse artwork uses genotype → calculated phenotype → approved breed template → controlled appearance variation. `horse_image_templates` is the human-reviewed template registry with breed/body archetype, optional sex, pose, review state, activation, audit identity, and replacement history. The worker cannot make a variation without an active approved template; it supplies the approved raster as the image-to-image anatomy source and permits only coat/pattern/marking changes. Candidate QA compares the result against both the persisted phenotype and source template, requiring preserved geometry, exactly four complete legs and hooves, balanced breed conformation, complete framing, clean background, and no text/signature artifacts. Failure or missing breed coverage completes safely with the official Foundation fallback instead of retrying unconstrained generation.

Persistent `markings`, `visual_phenotype`, `image_template_id`, and `image_quality_status` live on the horse; the legacy-named `store_horse_image_jobs` table remains the shared artwork-only queue. Approved assets are stored under `legacy-equine-media/generated/template-variations`. Admin template review and batch regeneration are security-definer RPCs. Player uploads remain independent custom artwork. Artwork replacement never mutates gameplay identity, genetics, stats, pedigree, or ownership.

`get_breeding_genetic_preview` computes locus-level inheritance and combined lethal probability from the selected pair. It is informational; `breed_horses` repeats all ownership, eligibility, lethal, balance, and cooldown enforcement transactionally. `breed_cross_rules` separates documented breed naming from genetics, while breed composition is combined mathematically over generations.

## Shared LE Store inventory

Foundation inventory is persisted in `horses` plus `store_inventory`; store-owned horses have no player owner until checkout. `store_settings` configures the 5–8 supported inventory size (default six), 60-minute rotation, and price. `foundation_breeds` is data-driven. Reads call `get_store_inventory`, which refreshes expired stock under a transaction-scoped advisory lock. Checkout locks the inventory, stable, and horse rows, transfers the exact viewed horse, records the ledger entry, marks the listing sold, and creates one replacement. Sold and expired listing rows remain as audit history. Competing purchases and rotations serialize on the same advisory lock.

Stable capacity is an entitlement ledger in `stable_capacity_allocations`: base, purchased, admin, promotional, event, and explicit unlimited sources remain independently auditable. `stable_capacity()` derives occupied, total, and available stalls. Every horse-acquisition RPC calls the same locked server-side capacity guard before ownership or currency mutation. Verified USD payments are stored separately in `stall_payment_transactions`; Stripe Checkout completion reaches a signed webhook and the idempotent `complete_stall_payment` RPC, whose unique provider references prevent duplicate grants.

Sanctuary retirement sets permanent status and former-owner fields on the preserved horse record, closes active listings, ends its open `horse_ownership_history` interval, and writes a capacity audit event. Public directory reads include former stable identity. Referentially restricted horse IDs remain intact, so ancestry, progeny, service, and competition records cannot be severed by retirement.

## Player systems

Stable profiles keep immutable `account_number` identity separate from editable names, biographies, and case-insensitively unique community usernames. Shows use the existing competition tables and server-authoritative scoring RPCs. `marketplace_listings` records active, sold, and cancelled offers; checkout locks the listing and both accounts, transfers the existing horse, and writes balanced buyer/seller ledger entries in one transaction. `forum_posts` stores conversations and replies while read RPCs join only the public identity fields needed by the community UI. Direct table writes remain unavailable to normal clients.

Player media uses the dedicated public `legacy-equine-media` Supabase Storage bucket. Object paths begin with the authenticated user ID and storage policies prevent cross-account inserts, updates, and deletion. Ranch images and avatars are separate stable columns; horse images remain attached to individual horse rows. Upload validation permits image MIME types only and caps files at 5 MB.

## Administration

The `stables.is_admin` role is checked inside security-definer RPCs on every privileged operation. Account #1 is the protected owner authority and is the only account allowed to grant or revoke administrators. Admin balance changes update the locked stable balance and write the same signed amount to `currency_ledger`; custom horses are created directly as permanent `Admin Custom` records. The UI merely exposes these RPCs and is not an authorization boundary.
# Professional Services Architecture

Professional reference data is relational and balanceable without source changes: `professions`, `certification_levels`, `study_modules`, `certification_questions`, and `service_catalog`. Player state lives in `player_professions`, `player_study_progress`, `certification_attempts`, and `player_service_offerings`. Completed work is an immutable `horse_service_records` trail that follows the horse through ownership changes and can later anchor verified-client reviews.

All progression, certification, pricing validation, cooldown enforcement, service completion, and LED movement occurs in security-definer database functions. A service request locks the horse, provider progression, offering, and client balance, writes both ledger sides in the same transaction, records a unique idempotency key, and only then adds qualifying credit. Browser code cannot directly mutate these protected tables.

Service effects are stored as transparent JSON stat deltas with explicit expiry. They remain distinct from inherited base values, permanent development, and tack. The image pipeline similarly persists the authoritative genotype-derived phenotype, prompt, status, asset URL, and generation timestamp; artwork never determines genetics.
## Institutional economy and player shows

Migration `202609150036_closed_loop_economy_and_player_shows.sql` adds `economy_config`, `system_funds`, and `system_fund_ledger`. Player balances remain on `stables`; system balances cannot be accessed through player balance RPCs. Security-definer mutations validate the caller's persisted `is_super_admin` role. Profession charges lock the stable, deduct once, write the player ledger, and allocate the same transaction into the institutional funds.

Shows use `show_disciplines`, `show_tiers`, `show_placement_rules`, `player_shows`, `player_show_entries`, and `player_show_results`. Disciplines and weighted applicable-stat mappings are database records. Transactional RPCs own creation and entry. Entry locks the show, horse, and stable, snapshots eligibility plus historical horse/owner identity, and transfers the fee into the purse. A PostgreSQL `pg_cron` job invokes `process_due_player_shows()` every five minutes. Processing uses `FOR UPDATE SKIP LOCKED`, transitions `open → processing → complete`, calculates the weighted average of applicable Effective Stats, stores a per-stat base/training/tack/service breakdown, and ranks deterministically. A unique result per entry and insert-then-award flow make processing retries idempotent. Result snapshots are never rewritten after ownership changes.

`get_horse_competition_tier` resolves the one active tier whose configurable point bounds contain a horse's current Career Points. `get_show_entry_options` presents that same server decision to the UI. `enter_player_show_batch` accepts a distinct horse-ID array, locks and validates the complete batch, applies the optional show maximum to horse records rather than owners, charges the exact per-horse total, and creates independent entry and ledger rows in one transaction. The `(show_id, horse_id)` uniqueness constraint prevents duplicate entries while the entry snapshot preserves legitimate eligibility across later tier movement.

Public read RPCs project this source of truth without redundant counters: `get_horse_show_record` builds career and discipline records, `get_show_results` builds permanent result pages, and `get_show_archive` provides search/filter/sort across completed shows, horses, historical owners, hosts, tiers, and disciplines. The Shows client separates Upcoming Shows, Create Show, My Entries, and Results / Archive rather than combining workflows.

## Realtime Community

`chat_rooms` is the database-driven room registry. `chat_messages` stores sanitized plain-text messages plus extensible JSON entity references; `chat_mutes` and `community_audit_log` preserve moderation state and history. All writes use security-definer RPCs that recover identity from `auth.uid()`, check persisted `community_role`, enforce room permissions, and rate-limit messages. Clients subscribe to filtered Supabase Realtime events and reload joined public identity fields through the read RPC. History uses indexed timestamp cursor pagination. Community roles (`player`, `moderator`, `admin`, `owner`) are deliberately independent of Treasury authorization.

## Player Bank

`currency_ledger` remains the authoritative append-only player accounting record. `get_bank_activity` projects it into paginated, categorized, player-friendly Bank entries and derives the balance resulting from each transaction without duplicating accounting state. `get_bank_summary` calculates lifetime income and spending. The Bank UI never exposes a withdrawal path; any future LED purchase system is one-way into the closed game economy.

## Artwork QA gate

The image worker generates a candidate, submits the candidate plus the persisted structured phenotype to a vision-capable QA model, and uploads only an approved result. QA returns separate required verdicts for base coat, color pattern, and individual markings so a visually dominant white pattern cannot conceal an incorrect underlying coat; coat-specific prompts also encode required pigment points such as a bay horse's black mane, tail, ear rims, and uncovered lower legs. `horse_image_qa_reviews` records each structured decision. Rejection returns the existing job to the bounded retry flow while leaving the authoritative horse row untouched. The completion RPC replaces only system-generated artwork and continues to protect concurrent player uploads.

## Horse profile views

The client horse profile is a tab-state view keyed by URL hash, allowing deep links without duplicating the horse record. Supporting records are read from `training_log`, `horse_service_records`, `player_show_entries`, `player_show_results`, and public horse ancestry/progeny rows. Stat breakdowns derive permanent training from the immutable training log and keep tack and active service effects separate from inherited/current values.

`ContainedHorseArtwork` is the single full-body image boundary. Its fixed responsive host and padded absolute inner frame apply centered `object-fit: contain` independently of source aspect ratio or format, with the Foundation asset as the recovery candidate. Contexts control only box dimensions; they may never switch full-horse artwork to `cover`.
