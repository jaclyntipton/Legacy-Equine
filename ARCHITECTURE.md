# Architecture

Legacy Equine uses Next.js App Router and TypeScript. UI code is in `app/`; framework-independent rules are in `lib/game/`. `config.ts` is the balance source of truth, `simulation.ts` contains deterministic generation, inheritance, effective-stat, cooldown, and aging functions, and `types.ts` defines domain objects.

The checked-in Supabase migration creates stable, horse, ledger, training, inventory, and competition tables with real foreign keys. Horse parents use restricted foreign keys so ownership changes cannot alter ancestry and deletion cannot break pedigrees. Sequential stable numbers use a PostgreSQL identity and are never recycled. JSONB keeps stat and trait definitions data-driven.

RLS allows public reading of stable and horse profiles, limits ordinary users to owned data, and deliberately provides no direct insert policies for protected game records. Production purchase, training, and breeding writes must be implemented as security-definer RPC functions so balance checks, cooldowns, ownership, generated stats, and ledger entries share one database transaction.

The current local Alpha runs in a transparent browser-persistence mode so the complete game loop can be evaluated before cloud credentials exist. Production activation requires a dedicated Supabase project, applying migrations, environment variables, and replacing the local adapter with authenticated RPC calls. Vercel builds from the repository; migrations stay version controlled and should run in CI before deployment.

Age is derived from `birth_date` and the configured clock rather than mass-updating rows. Cooldown eligibility similarly derives from `last_bred_at`, so time progresses without cron jobs.

## Genetics and breed identity

`horses.genetics` stores allele pairs as JSONB and `horses.breed_composition` stores fractional ancestry independently from the displayed breed label. Foundation generation creates the genotype first and derives the visible color from it. Breeding locks both parents, independently selects one allele from each parent at every locus, rejects a modeled lethal result before any balance or cooldown mutation, and then persists that exact genotype and phenotype on the foal. This makes previews probabilistic while the resulting foal remains permanent and reproducible from its stored genes.

`breed_foundation_genetic_population` is the data-driven population layer used only for new Foundation horses. It stores one configurable allele frequency, rarity tier, and generation switch for every breed/locus, with audited Admin changes. The universal genetics and phenotype functions remain shared. Foundation generation samples the selected breed table and retries non-viable lethal genotypes; breeding never consults population frequency and uses only parental alleles. American Paint Horse is modeled as its own breed rather than a coat label.

The stat count is primary-source confirmed at exactly seven while names and order remain provisional in `stat_definitions`. `horses.birth_stats` is immutable historical JSONB; `horses.stats` stores current permanent Developed values, with Development derived as the difference. Training changes only Developed and appends `training_log`. Effective values are derived from Developed plus tack and active service effects. Shows snapshot Effective values, while breeding transactionally reads only parental Developed values and applies the configurable `stat_system_config` inheritance range. Temporary modifiers cannot be inherited, and no schema or UI assumes a 100-point ceiling.

`horses.height_genetics` separately stores allele pairs for the LCORL, HMGA2, ZFAT, and LASP1 gameplay loci, while `mature_height_hands` stores the permanent expressed height. A before-insert trigger initializes Foundation/Admin horses or inherits one allele per parent for foals, applies small non-genetic variance, constrains the result through `breed_height_ranges` (or parental bounds for named crosses), and embeds the exact height into `visual_phenotype` for artwork generation.

All horse artwork uses genotype → calculated phenotype → approved breed template → controlled appearance variation. `horse_image_templates` is the human-reviewed template registry with breed/body archetype, optional sex, pose, review state, activation, audit identity, and replacement history. The worker cannot make a variation without an active approved template. Failure or missing breed coverage renders the non-illustrative Legacy Equine™ Horse Visual Pending state instead of retrying unconstrained generation or displaying genetically incorrect artwork.

Persistent `markings`, `visual_phenotype`, `image_template_id`, and `image_quality_status` live on the horse; the legacy-named `store_horse_image_jobs` table remains the shared artwork-only queue. Approved assets are stored under `legacy-equine-media/generated/template-variations`. Admin template review and batch regeneration are security-definer RPCs. Player uploads remain independent custom artwork. Artwork replacement never mutates gameplay identity, genetics, stats, pedigree, or ownership.

`get_breeding_genetic_preview` computes locus-level inheritance and combined lethal probability from the selected pair. It is informational; `breed_horses` repeats all ownership, eligibility, lethal, balance, and cooldown enforcement transactionally. `breed_cross_rules` separates documented breed naming from genetics, while breed composition is combined mathematically over generations.

## Shared LE Store inventory

Foundation inventory is persisted in `horses` plus `store_inventory`; store-owned horses have no player owner until checkout. `store_settings` configures the 5–8 supported inventory size (default six), 60-minute rotation, and price. `foundation_breeds` is data-driven. Reads call `get_store_inventory`, which refreshes expired stock under a transaction-scoped advisory lock. Checkout locks the inventory, stable, and horse rows, transfers the exact viewed horse, records the ledger entry, marks the listing sold, and creates one replacement. Sold and expired listing rows remain as audit history. Competing purchases and rotations serialize on the same advisory lock.

Stable capacity is an entitlement ledger in `stable_capacity_allocations`: base, purchased, admin, promotional, event, and explicit unlimited sources remain independently auditable. `stable_capacity()` derives occupied, total, and available stalls, with Account #1 intrinsically and permanently unlimited even if an entitlement row is changed accidentally. Every horse-acquisition RPC calls the same locked server-side capacity guard before ownership or currency mutation. Foundation purchase counts are historical analytics only and never gate checkout for any account. Verified USD payments are stored separately in `stall_payment_transactions`; Stripe Checkout completion reaches a signed webhook and the idempotent `complete_stall_payment` RPC, whose unique provider references prevent duplicate grants.

Human-approved body masters are immutable, checksum-recorded source assets. A master fixes every anatomy and conformation pixel; phenotype work produces separate derived clean-body, coat, leg-point, pattern, face, and individual-leg layers on the same alpha geometry. Mane and tail are independent transparent artwork assets—not procedural body-region masks—and are registered to one exact master by canvas, origin, and scale. Mare assets cannot be reused on the stallion or vice versa. Each master has distinct Chestnut, Black, and Flaxen/Cream mane and tail slots. Until a human-approved clean body and required hair assets exist, the combination is incomplete and cannot enter production.

`equine_visual_taxonomy` is the data-driven vocabulary for coats, age-dependent gray, dun/cream/roan/silver/champagne/pearl modifiers, dapple effects, pinto families, Leopard Complex families, face markings, leg markings, primitive details, and hair. `horse_visual_asset_requirements` expands that vocabulary onto every approved body master and all four anatomical limbs. Asset state advances through Missing → Uploaded → Review → Approved → Production; Production requires an approved active asset registered to that exact master. `anatomical_leg_marking` maps LF/RF/LH/RH to stored horse anatomy and never to screen coordinates. This matrix creates no artwork and missing combinations continue to use the safe fallback.

Sanctuary retirement sets permanent status and former-owner fields on the preserved horse record, closes active listings, ends its open `horse_ownership_history` interval, and writes a capacity audit event. Public directory reads include former stable identity. Referentially restricted horse IDs remain intact, so ancestry, progeny, service, and competition records cannot be severed by retirement.

## Player systems

Stable profiles keep immutable `account_number` identity separate from editable names, biographies, and case-insensitively unique community usernames. Shows use the existing competition tables and server-authoritative scoring RPCs. `marketplace_listings` records active, sold, and cancelled offers; checkout locks the listing and both accounts, transfers the existing horse, and writes balanced buyer/seller ledger entries in one transaction. `forum_posts` stores conversations and replies while read RPCs join only the public identity fields needed by the community UI. Direct table writes remain unavailable to normal clients.

Player media uses the dedicated public `legacy-equine-media` Supabase Storage bucket. Object paths begin with the authenticated user ID and storage policies prevent cross-account inserts, updates, and deletion. Ranch images and avatars are separate stable columns; horse images remain attached to individual horse rows. Upload validation permits image MIME types only and caps files at 5 MB.

## Administration

The `stables.is_admin` role is checked inside security-definer RPCs on every privileged operation. Account #1 is the protected owner authority and is the only account allowed to grant or revoke administrators. Admin balance changes update the locked stable balance and write the same signed amount to `currency_ledger`; custom horses are created directly as permanent `Admin Custom` records. The UI merely exposes these RPCs and is not an authorization boundary.

Horse editing uses a narrower `staff_permissions.horse_editor` capability rather than the broad administrator flag. Account #1 always has it and is the only account that can delegate it. `owner_edit_horse` locks the target row, validates high-impact confirmation, recomputes genotype-derived phenotype and Developed stats, rejects pedigree cycles, safely falls back from incompatible visual templates, records administrative ownership intervals, and writes full immutable before/after values to `horse_edit_audit`. Completed show-result correction is a separate Account-#1-only RPC so ordinary horse edits cannot rewrite competition history.
# Professional Services Architecture

Professional reference data is relational and balanceable without source changes: `professions`, `certification_levels`, `study_modules`, `certification_questions`, and `service_catalog`. Player state lives in `player_professions`, `player_study_progress`, `certification_attempts`, and `player_service_offerings`. Completed work is an immutable `horse_service_records` trail that follows the horse through ownership changes and can later anchor verified-client reviews.

All progression, certification, pricing validation, cooldown enforcement, service completion, and LED movement occurs in security-definer database functions. A service request locks the horse, provider progression, offering, and client balance, writes both ledger sides in the same transaction, records a unique idempotency key, and only then adds qualifying credit. Browser code cannot directly mutate these protected tables.

Service effects are stored as transparent JSON stat deltas with explicit expiry. They remain distinct from inherited base values, permanent development, and tack. The image pipeline similarly persists the authoritative genotype-derived phenotype, prompt, status, asset URL, and generation timestamp; artwork never determines genetics.
## Institutional economy and player shows

`create_shows` is the sole current Show-creation transaction used by the player client. It uses a caller request UUID, locks the Stable, validates the full quantity and weekly capacity, inserts independently identifiable Shows, writes one player and institutional ledger row per Show, and commits or rolls back the complete batch. `creation_batch_id` ties those records together without merging their gameplay identity.

`preview_show_entries` is stable/read-only. `confirm_show_entries` locks the Stable plus all selected Shows and horses in deterministic order, re-runs the same eligibility calculation, and either returns changed eligibility without charging or commits the full chosen pairing set. `show_action_requests` stores request results for retry safety. Each entry fee produces a player debit and paired Show Fund contribution/purse-allocation records sharing a batch ID.

`show_fund_reconciliation` maps each recovered historical `currency_ledger` row exactly once. `reconcile_show_fund_history` only recognizes authoritative Show-hosting and Show-entry descriptions. Historical entry fees create an inflow/outflow pair because their value is already present in `player_shows.entry_fee_purse`; historical creation fees restore available Show Fund balance. Existing profession allocation rows remain authoritative and are excluded from this recovery pass.

Migration `202609150036_closed_loop_economy_and_player_shows.sql` adds `economy_config`, `system_funds`, and `system_fund_ledger`. Player balances remain on `stables`; system balances cannot be accessed through player balance RPCs. Security-definer mutations validate the caller's persisted `is_super_admin` role. Profession charges lock the stable, deduct once, write the player ledger, and allocate the same transaction into the institutional funds.

Shows use `show_disciplines`, `show_tiers`, `show_placement_rules`, `player_shows`, `player_show_entries`, and `player_show_results`. Disciplines and weighted applicable-stat mappings are database records. Transactional RPCs own creation and entry. Entry locks the show, horse, and stable, snapshots eligibility plus historical horse/owner identity, and transfers the fee into the purse. A PostgreSQL `pg_cron` job invokes `process_due_player_shows()` every five minutes. Processing uses `FOR UPDATE SKIP LOCKED`, transitions `open → processing → complete`, calculates the weighted average of applicable Effective Stats, stores a per-stat base/training/tack/service breakdown, and ranks deterministically. A unique result per entry and insert-then-award flow make processing retries idempotent. Result snapshots are never rewritten after ownership changes.

`get_horse_competition_tier` resolves the one active tier whose configurable point bounds contain a horse's current Career Points. `get_show_entry_options` presents that same server decision to the UI. `enter_player_show_batch` accepts a distinct horse-ID array, locks and validates the complete batch, applies the optional show maximum to horse records rather than owners, charges the exact per-horse total, and creates independent entry and ledger rows in one transaction. The `(show_id, horse_id)` uniqueness constraint prevents duplicate entries while the entry snapshot preserves legitimate eligibility across later tier movement.

Public read RPCs project this source of truth without redundant counters: `get_horse_show_record` builds career and discipline records, `get_show_results` builds permanent result pages, and `get_show_archive` provides search/filter/sort across completed shows, horses, historical owners, hosts, tiers, and disciplines. The Shows client separates Upcoming Shows, Create Show, My Entries, and Results / Archive rather than combining workflows.

## Realtime Community

`chat_rooms` is the database-driven room registry. `chat_messages` stores sanitized plain-text messages plus extensible JSON entity references; `chat_mutes` and `community_audit_log` preserve moderation state and history. All writes use security-definer RPCs that recover identity from `auth.uid()`, check persisted `community_role`, enforce room permissions, and rate-limit messages. Clients subscribe to filtered Supabase Realtime events and reload joined public identity fields through the read RPC. History uses indexed timestamp cursor pagination. Community roles (`player`, `moderator`, `admin`, `owner`) are deliberately independent of Treasury authorization.

## Player Bank

`currency_ledger` remains the authoritative append-only player accounting record. `get_bank_activity` projects it into paginated, categorized, player-friendly Bank entries and derives the balance resulting from each transaction without duplicating accounting state. `get_bank_summary` calculates lifetime income and spending. The Bank UI never exposes a withdrawal path; any future LED purchase system is one-way into the closed game economy.

## Artwork QA gate

The previous per-horse AI worker is a disabled compatibility endpoint and cannot claim jobs or spend generation credits. `horse_visual_assets` is the source-controlled-by-data library for human-reviewed body templates and transparent phenotype layers. `assign_horse_visual` deterministically selects a breed/sex body template from the horse UUID, stores a permanent template key and visual fingerprint, and resolves display priority as player custom artwork → cached deterministic LE composite → branded Visual Pending state. `get_horse_visual_layers` returns an ordered, approved-only layer manifest for deterministic compositing/caching. Admin asset upload, replacement, approval, rejection, activation, deactivation, and combination preview require no source change.

Artwork Album quota state is normalized into `artwork_storage_config`, `artwork_storage_entitlements`, `artwork_album_items`, and append-only `artwork_storage_gift_history`. `artwork_storage_summary` computes subscription base + applicable Owner bonus and represents unlimited as a boolean with a null numeric capacity—never a sentinel number. Account #1 is always unlimited by identity, independent of subscription, role, or defaults. Uploads reserve quota server-side before storage and finalize only after type, byte-size, and 1200×1200 dimension validation. Capacity changes update entitlement metadata only and never delete album rows or storage objects.

The image worker generates a candidate, submits the candidate plus the persisted structured phenotype to a vision-capable QA model, and uploads only an approved result. QA returns separate required verdicts for base coat, color pattern, and individual markings so a visually dominant white pattern cannot conceal an incorrect underlying coat; coat-specific prompts also encode required pigment points such as a bay horse's black mane, tail, ear rims, and uncovered lower legs. `horse_image_qa_reviews` records each structured decision. Rejection returns the existing job to the bounded retry flow while leaving the authoritative horse row untouched. The completion RPC replaces only system-generated artwork and continues to protect concurrent player uploads.

## Horse profile views

The client horse profile is a tab-state view keyed by URL hash, allowing deep links without duplicating the horse record. Supporting records are read from `training_log`, `horse_service_records`, `player_show_entries`, `player_show_results`, and public horse ancestry/progeny rows. Stat breakdowns derive permanent training from the immutable training log and keep tack and active service effects separate from inherited/current values.

`ContainedHorseArtwork` is the single full-body image boundary. Its fixed responsive host and padded absolute inner frame apply centered `object-fit: contain` independently of source aspect ratio or format, with the Foundation asset as the recovery candidate. Contexts control only box dimensions; they may never switch full-horse artwork to `cover`.
# Progression and weekly economy

`stables.account_xp` is the lifetime XP aggregate. Immutable/idempotent source events live in `account_xp_events`; `account_level_config` derives current level and all level-based balancing. This is intentionally independent of `horses.career_points`.

`weekly_allowance_entitlements` is a snapshot ledger generated by server RPCs at America/New_York Friday boundaries. Collection locks entitlements, writes `currency_ledger`, and updates the Stable balance in one database transaction. Subscription windows determine bonus/protection when an entitlement is created; they do not rewrite prior snapshots.

Show creation quotas and unlocks are checked in security-definer functions. Bulk creation validates the entire Cartesian selection before inserting, so failures roll back the full set. Advanced bulk entry previews each horse/show pair and executes through the existing locked, transactional show-entry path. XP triggers run only from permanent show results and use unique event keys to prevent retries from duplicating XP.

`stable_layouts` stores versioned safe JSON block data only; arbitrary scripts and HTML are not part of the schema. `phone_e164` has a partial unique index when verified. Lifecycle periods and progression/economy constants are stored in `progression_config` for Alpha tuning.
# Store and horse-care architecture

`foundation_breeds` owns per-breed inventory size, optional price, and optional refresh interval. `refresh_store_inventory()` locks globally, evaluates each breed independently, expires only that breed's stale stock, and fills it to its configured count. `store_inventory` remains the permanent shared sale/expiration audit trail.

`store_products` is the configuration source for Feed, Tack, and Stable Supplies. Purchases create individually addressable `player_store_items` through a server-priced LED transaction. `horse_feed_log` enforces one daily feeding and records before/after Developed Stats. `horse_equipment` enforces one item per extensible slot and `recalculate_horse_tack()` derives the cached effective-stat bonus map from equipped assets.

`horse_wellness` stores bounded components and a recovery anchor. Reads materialize timestamp-derived passive Recovery. Activity and professional-service triggers provide auditable wear/restoration without modifying inherited stats. Show entry uses a deterministic configured minimum readiness threshold.

`horse_game_config.real_days_per_horse_year` is the single aging rate. `horse_game_age()` provides precise continuous age from `horses.birth_date`; no aging cron mutates ages. Existing timestamps were migrated while preserving their pre-migration displayed ages.
## Store rooms and visual ingestion

`store_products` is the data-driven catalog for Feed, Tack, and Stable Supplies. Physical item instances live in `player_store_items`; equipped items are referenced by `horse_equipment`, whose unique horse/slot constraint prevents multiple items in one tack category. Feed consumption is audited in `horse_feed_log` and permanent Development changes occur only inside the server transaction.

`horse_visual_asset_requirements` is the exact-master requirement matrix. `admin_visual_asset_manifest()` supplies both human- and machine-readable exports. `admin_register_visual_asset()` validates master canvas, type, and size again on the server, registers a human upload, and leaves it in Review. Approval and Production remain separate explicit Owner actions.

Visual uploads are immutable version rows linked by `supersedes_asset_id`; replacement changes only the requirement's current pointer. `admin_review_visual_asset`, `admin_rollback_visual_asset`, and `admin_promote_visual_asset` are separate Owner-secured transitions. Production changes are written to `horse_visual_production_history`. The client preview compositor never mutates horses or assets.

`stable_brands` reserves the current stable code/mark, while each horse stores assignment-time code, mark URL/version, assigning account, origin, and timestamp. Database triggers brand completed Foundation purchases and new foals; foals resolve the dam's owner at birth. `stable_brand_audit` records registration, assignment, privilege changes, and future corrections without coupling Brand identity to horse names or gameplay stats.
# Player information architecture

The authenticated shell has two separate bounded contexts:

- `My Profile`: player identity, social information, Artwork Album, stable display settings, avatar, ranch image, biography, and permanent brand settings.
- `My Stable`: horse roster and owned inventory rooms. `player_store_items` remains the single source of truth; the room UI filters it by the active `store_products.department` rather than copying inventory records.

Store purchase completion returns a destination descriptor (`Feed Room`, `Tack Room`, or `Supply Room`) and a direct navigation action. Horse artwork selection reads the same `artwork_album_items` records governed by Artwork Album entitlements; no secondary upload library is created.
