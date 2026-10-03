# Raw Logs → Canonical Datasets in dbt

### The process I follow to define, build, and manage canonical data pipelines

> Anyone can write a `SELECT`. My job as a data engineer is to turn a firehose of messy, half-instrumented, late-arriving raw logs into a small number of **canonical datasets** that the whole company trusts enough to make decisions on — and to keep them correct, cheap, and fresh while the business changes underneath me. dbt is the tool. This document is the method I apply, not a tutorial.

This doc is the methodology; the runnable proof lives in [`/pipelines/dbt_saas_analytics`](../pipelines/dbt_saas_analytics). Every pattern below maps to a real model, test, or config in that project, and the whole thing builds green in CI on DuckDB with zero secrets.

**Warehouse framing.** I write the method warehouse-aware. The runnable scaffold targets **DuckDB** so the repo is self-contained and reviewer-runnable, but I flag where **Snowflake / BigQuery / Redshift / Databricks** differ on the things that actually change between them (incremental strategy, partitioning/clustering, `MERGE` availability). The *concepts* are identical across all of them; only the keywords move.

**Running example (used throughout).** A fictional B2B SaaS product emits an **app event log** — a raw, append-only stream of user interaction events (`login`, `page_view`, `feature_used`, `purchase`) landed by an ingestion tool. I turn that raw log into a canonical **`fct_user_sessions`** fact and its conformed **`dim_users`** dimension, with tests, an incremental strategy, docs, and a CI plan. The raw table I model against:

```
schema: raw     table: raw_app_events

| column          | type      | notes                                                     |
|-----------------|-----------|-----------------------------------------------------------|
| event_id        | string    | usually unique... but NOT guaranteed (at-least-once → dupes)|
| event_type      | string    | 'login' | 'page_view' | 'feature_used' | 'purchase'       |
| user_id         | string    | null for anonymous events (pre-login)                     |
| anonymous_id    | string    | device/cookie id, present on all events                   |
| session_id      | string    | client-generated; can be null or reused                   |
| event_timestamp | timestamp | CLIENT time — can be skewed, out of order                 |
| received_at     | timestamp | SERVER ingest time — monotonic-ish, use for incrementals  |
| properties      | string    | raw JSON blob, schema drifts over time                    |
| _ingested_at    | timestamp | when ingestion wrote the row                              |
| _file_name      | string    | source file, useful for debugging backfills               |
```

Everything below treats this table as real. Every anti-pattern is something people actually do to *this* table.

---

## The method, in one breath

I design the responsibility as three pillars, and I run every pipeline through all three:

1. **DEFINE** — design the pipeline on paper first: what the raw logs really are, what makes the output *canonical*, and how I go from a business question to a target model (grain → dimensions → measures → sources), laid out in layers.
2. **BUILD** — implement it in dbt: sources/`ref`, materializations, incremental strategy, tests, macros, contracts, docs.
3. **MANAGE** — operate it in production: orchestration, CI/CD, environments/secrets, cost/performance, observability, data-quality strategy, and change management.

For each pillar I keep the same discipline: explain the concept and the *tradeoff that justifies it*, show a concrete example from the running pipeline, name the anti-pattern I refuse to ship, and give a short exercise with a definition of done.

---

## PILLAR 1 — DEFINE

### 1.1 What raw logs actually are

**Concept + tradeoff.** "Raw logs" is data emitted for the *emitter's* convenience, not mine. Five shapes I always account for: JSON events (keys drift), CDC (row = a version, latest wins), append-only (dupes + late data are my problem), late-arriving (an event timestamped Monday lands Wednesday), schema drift (a JSON key appears mid-history). The tradeoff that drives everything: **raw logs optimize for cheap lossless capture; canonical datasets optimize for correct cheap consumption.** Those are opposite goals, and the whole job is the transformation between them.

Two distinctions I never confuse:
- **`event_timestamp` (client) vs `received_at` (server).** I report/partition on event time; I **filter incrementals on ingest time**. Mixing these up is the single most common late-data bug.
- **At-least-once delivery.** Duplicates are normal, not exceptional. I dedupe defensively on `event_id`.

**Example.** Before modeling anything I profile the source — dedupe rate, client-vs-server skew, which JSON keys exist and since when. In the running pipeline the synthetic seed deliberately contains a duplicate `event_id` (`e004`), an anonymous event with null `user_id` (`e005`), a late-arriving row (`e009`, event 2026-03-15 but received 2026-03-17), and a `plan_tier` key that only appears from March. The staging model handles all four.

**Anti-pattern.** Treating the raw log as clean: `SELECT user_id, count(*) ... WHERE event_timestamp >= '2026-01-01' GROUP BY user_id`. It counts duplicates as real events, filters on client time so late data vanishes, and buckets all anonymous events into one bogus `NULL`. It runs green and is wrong by a few percent — nobody notices until Finance cross-checks.

**Exercise.** Profile `raw_app_events`: dedupe rate of `event_id`, distribution of `received_at − event_timestamp`, and first-seen date of each `properties` key. **Done when** you can state your dedupe strategy, your lookback window in days, and which JSON keys are safe to depend on.

### 1.2 What makes a dataset canonical

**Concept + tradeoff.** Canonical = the single, agreed, reusable representation of a business concept. Six properties: explicit **grain** ("one row = one session"), **conformed dimensions** (the same `dim_users` everywhere), **business key vs surrogate key**, **SCD type** (overwrite vs history), predictable **naming + contracts**, and a **written definition** of every ambiguous term. The tradeoff: **canonical means centralized — slower to change, but safe to trust.** A one-off query is faster to write and nobody can rely on it; a canonical model is slower to establish and becomes the foundation everyone builds on.

**Example — the spec I write before any SQL for `fct_user_sessions`:**

```
Grain:       one row per session_key
Business key:(actor_id, session_start_ts)
Surrogate:   session_key = generate_surrogate_key([actor_id, session_seq])
Measures:    event_count, page_view_count, feature_used_count,
             purchase_count, revenue_usd, session_duration_seconds
Conformed:   dim_users (SCD2 on plan_tier/is_active), dim_date
Session rule:new session when gap between an actor's events > 30 min   ← a CONTRACT
```

The 30-minute rule is a *business rule written down before code*. Change it and every number changes — so it's a contract, not an implementation detail.

**Anti-pattern.** A table named `sessions` whose grain is actually *per user* (`GROUP BY user_id`). The name lies; someone joins it expecting session grain, fans out their revenue, ships a wrong number. **A canonical table whose name doesn't match its grain is worse than no table.**

**Exercise.** Write a one-page spec for `dim_users`: grain, business key, surrogate key, which attributes are SCD1 vs SCD2 and why, and the exact testable definition of `is_active`. **Done when** every attribute's SCD choice has a one-sentence defense and `is_active` has a formula.

### 1.3 From business question to target model

**Concept + tradeoff.** I model **backward from the question**, in a fixed order: **grain → dimensions → measures → sources**. Grain first because everything hangs off it; sources *last*, because that's where I discover on paper (cheaply) that the data can't support the ask. The tradeoff: writing a spec before code feels slower but catches impossibility before two weeks of building.

**Example.** Question: *"Which plan tiers have the most engaged users, and is engagement rising?"* → grain = user × week (`fct_user_weekly_engagement`, built on `fct_user_sessions`, not raw); dimensions = plan_tier (SCD2, as-of that week), week, device; measures = sessions_per_week, active_days, `is_engaged = active_days >= 3`; sources = map back and find the gap — "engaged" was undefined, so I define it and get sign-off.

**Anti-pattern.** Modeling forward from the log ("`events` has `event_type`, let me `GROUP BY` it and see"). You produce the wrong grain and answer a question nobody asked.

**Exercise.** Decompose *"Are new users activating faster this quarter than last?"* into grain/dims/measures/sources, and name the one term you'd refuse to build without defining ("activating" = ?). **Done when** you have a 4-line spec and at least one flagged undefined term.

### 1.4 Layered architecture

**Concept + tradeoff.** Four layers, each with one job: **sources** (declare raw + freshness), **staging** (`stg_`, 1:1 with a source — rename/cast/dedupe, no joins), **intermediate** (`int_`, the heavy joins/sessionization, reusable, not exposed), **marts** (`dim_`/`fct_`, business-facing canonical models). The tradeoff: **layering adds files and indirection in exchange for isolation, reusability, and testability.** Staging insulates downstream from source drift; intermediate keeps marts readable and logic DRY; marts give consumers one trustworthy place to query.

**Example — the running pipeline's DAG:**

```
raw.raw_app_events  (source + freshness)
   └─ stg_app_events__events        [view]       dedupe, coalesce ids, safe JSON extract
        └─ int_sessionized_events   [ephemeral]  30-min sessionization (window fn)
             ├─ fct_user_sessions   [incremental] canonical session fact
             │     └─ fct_user_weekly_engagement [table]  → engagement_dashboard (exposure)
             └─ dim_users           [table]      SCD2 from users_snapshot
```

**Anti-pattern.** The "god model": one 400-line file that reads `raw` directly and does rename + dedupe + sessionize + join + aggregate at once. Untestable, unreadable, un-reusable, and it hides its dependency so the DAG is a lie.

**Exercise.** Sketch the four-layer skeleton for `fct_user_sessions` (empty files + a one-line purpose comment each). **Done when** names follow `stg_/int_/fct_` and no layer does another's job.

---

## PILLAR 2 — BUILD

### 2.1 Sources, ref(), freshness, seeds, snapshots

**Concept + tradeoff.** `source()`/`ref()` are the edges of the DAG — they're what make dbt a graph instead of a folder of scripts; the indirection buys lineage, ordering, and `state:modified+` CI. Freshness catches upstream stalls before I build on stale data. Seeds are for small static lookups only. Snapshots are dbt's built-in **SCD2** machinery.

**Example.** The running pipeline declares `raw_app_events` as a source with a 2h-warn/6h-error freshness block, `stg_app_events__events` reads it via `{{ source(...) }}` and dedupes, and `users_snapshot` captures SCD2 history that `dim_users` reads. See [`_app_events__sources.yml`](../pipelines/dbt_saas_analytics/models/staging/app_events/_app_events__sources.yml) and [`users_snapshot.sql`](../pipelines/dbt_saas_analytics/snapshots/users_snapshot.sql).

**Anti-pattern.** Hard-coding `from raw.raw_app_events` instead of `source()` — the DAG can't see the dependency, lineage and Slim CI break. And putting real/large data in a seed (seeds are parsed on every `dbt seed`).

**Exercise.** Add a freshness block and write a staging model that references the source via `source()`, dedupes on `event_id`, and extracts one JSON key with an `'unknown'` default. **Done when** `dbt source freshness` reports a state and the staging model has zero hard-coded `raw.` strings and zero duplicate `event_id`s.

### 2.2 Materializations

**Concept + tradeoff.** view / table / incremental / ephemeral. The core tension is **freshness+simplicity vs compute cost**: views are always fresh but pay compute per query; tables rebuild everything each run; incremental processes only new rows but you now own late-data/backfill/idempotency complexity; ephemeral is zero-storage but can't be queried/tested directly. My defaults: **staging = view, intermediate = ephemeral, small marts = table, big event facts = incremental.** Start simple; promote to incremental only when a rebuild actually hurts.

**Anti-pattern.** Materializing *everything* as `table` (staging rebuilds 40 copies of raw for nothing), or reaching for `incremental` on day one on a 100k-row table to save four seconds while taking on all the correctness complexity.

**Exercise.** Assign a materialization to each model in the sessions stack with a one-sentence justification. **Done when** you can defend why `fct_user_sessions` is incremental but `fct_user_weekly_engagement` is a table.

### 2.3 Incremental models (the part that silently loses data)

**Concept + tradeoff.** Process only new rows via `is_incremental()`. The non-negotiables: **filter on `received_at` (ingest, monotonic), never `event_timestamp` (client)**; add a **lookback window** so late arrivals are re-read; use a **`unique_key` + merge** so re-reading is idempotent. The tradeoff: incremental buys huge compute savings at the cost of correctness complexity you now own — the lookback+merge pattern is how you buy correctness back.

**[Warehouse note]** Strategy keyword differs: `merge` (Snowflake/BigQuery/Databricks/Delta), `insert_overwrite` by partition (BigQuery/Databricks for whole-partition reprocessing), `delete+insert` (Redshift historically, and what the DuckDB scaffold uses). Same concept everywhere.

**Example** — [`fct_user_sessions.sql`](../pipelines/dbt_saas_analytics/models/marts/fct_user_sessions.sql):

```sql
{{ config(materialized='incremental', unique_key='session_key',
          incremental_strategy='delete+insert') }}  -- merge on cloud warehouses

with sessionized as (
    select * from {{ ref('int_sessionized_events') }}
    {% if is_incremental() %}
    where received_at >= (                           -- INGEST time, not event time
        select coalesce(max(received_at), timestamp '1900-01-01') - interval 3 day
        from {{ this }}                               -- 3-day lookback for late data
    )
    {% endif %}
)
...
```

**Anti-pattern.** `where event_timestamp > (select max(event_timestamp) from {{ this }})` — filters on client time so late events are dropped forever, and no unique_key means reprocessing duplicates. Runs green, loses a few percent daily. The most common incremental mistake there is.

**Exercise.** Convert `fct_user_sessions` to incremental with `unique_key`, a 3-day `received_at` lookback, and merge/delete+insert. **Done when** two consecutive runs produce identical row counts and measures (idempotent), and the filter uses `received_at`.

### 2.4 Tests

**Concept + tradeoff.** Generic (`unique`, `not_null`, `relationships`, `accepted_values`), singular (bespoke `.sql`), and package tests (`dbt_utils`, `dbt_expectations`). The tradeoff: **over-testing causes alert fatigue and red builds people ignore — worse than no tests; under-testing lets bad data reach an exec deck.** The skill is testing the *right* thing at the *right* layer, with deliberate severity (reconciliation and key-uniqueness = error/block; soft distribution checks = warn).

**Example.** The running pipeline tests `unique`+`not_null` on `session_key`, `accepted_values` on `event_type` *in staging*, a bounded-range `warn` on `session_duration_seconds`, and a **singular reconciliation** test ([`assert_sessions_purchases_reconcile.sql`](../pipelines/dbt_saas_analytics/tests/assert_sessions_purchases_reconcile.sql)) that ties session purchase counts back to raw purchase events.

**Anti-pattern.** `not_null` on `user_id` — which is *legitimately* null for anonymous events. Now every run fails on valid data and people learn to ignore the red.

**Exercise.** Add key-uniqueness, one categorical/measure assertion, one `relationships` test with justified severity, and one singular reconciliation test. **Done when** every severity is deliberate and the reconciliation test fails if you corrupt one row.

### 2.5 Macros, Jinja, packages — and when NOT to abstract

**Concept + tradeoff.** Macros DRY up repeated SQL; packages let you stand on `dbt_utils`/`dbt_expectations`. The tradeoff juniors get wrong in the *enthusiastic* direction: **abstraction trades local readability for global reuse.** Rule of three — duplicate twice, abstract on the third *identical* use. A macro with a reuse count of one is just obfuscation.

**Example.** The pipeline uses `dbt_utils.generate_surrogate_key([...])` instead of hand-rolled `md5(concat(...))` (handles nulls/casting/portability), and a single [`clean_string`](../pipelines/dbt_saas_analytics/macros/clean_string.sql) macro only because the exact cleanup recurs.

**Exercise.** Replace a hand-written surrogate key with the package macro; extract one macro only if a snippet genuinely recurs ≥3×. **Done when** `dbt deps` installs the package and you wrote *no* macro if there was no 3-use case (that's a pass).

### 2.6 Contracts, constraints, versioning

**Concept + tradeoff.** A contract (`contract: {enforced: true}`) fails the build if a model's output schema drifts — it turns a mart into a stable API. Versioning (`v1`/`v2` + `deprecation_date`) lets consumers migrate on their own schedule. The tradeoff: **contracts add rigidity in exchange for downstream safety — contract the interfaces, not the internals.**

**Example.** `fct_user_sessions` carries an enforced contract with types, `not_null`+`primary_key` on `session_key`, and a `check (revenue_usd >= 0)` — see [`_marts.yml`](../pipelines/dbt_saas_analytics/models/marts/_marts.yml).

**Anti-pattern.** Renaming `revenue → revenue_usd` on a canonical mart with no version, no deprecation — every downstream dashboard breaks at the next run.

**Exercise.** Add an enforced contract and prove a deliberate type mismatch fails `dbt build`. **Done when** the violation blocks the build and reverting makes it pass.

### 2.7 Documentation, exposures, the DAG

**Concept + tradeoff.** Docs are prose contracts (a column's *meaning*); the DAG is the dependency graph; exposures declare downstream consumers (a dashboard/ML/reverse-ETL) so they appear in lineage and blast-radius queries. The tradeoff: **authoring effort now saves investigation time later**, and it compounds with team size and project age.

**Example.** `fct_user_sessions` documents its grain + session rule in prose, and the pipeline declares an `engagement_dashboard` exposure on `fct_user_weekly_engagement`, so `dbt ls --select +exposure:engagement_dashboard` shows exactly what feeds it.

**Exercise.** Document the fact's grain + session rule, declare one exposure, run `dbt docs generate`. **Done when** the docs site renders source→fact→exposure lineage.

---

## PILLAR 3 — MANAGE

### 3.1 Orchestration & job design

**Concept + tradeoff.** Something must run dbt on a schedule, in order, with retries and alerting (dbt Cloud / Airflow / Dagster / cron). The job shape I use: `source freshness → snapshot → build → docs`, with failures paged. The tradeoff: **managed trades money+flexibility for near-zero ops; DIY trades ops burden for control.** The classic mistake is cron for something that needs retries/alerting (you learn it's been failing for a week).

**Example.** The [CI workflow](../.github/workflows/dbt_ci.yml) runs exactly that ordering: `deps → seed → snapshot → build --fail-fast → build again (idempotency) → docs`.

**Anti-pattern.** `dbt run` on cron with no `dbt test` and no freshness gate — ingestion stalls, dbt rebuilds on stale data, dashboards show yesterday as today, and you hear it from a stakeholder.

**Exercise.** Write the production runbook: command sequence, schedule time justified against ingest arrival, retries, alert destination. **Done when** a teammate could operate it from the doc.

### 3.2 CI/CD

**Concept + tradeoff.** Validate every PR by building/testing only what changed, cheaply, against prod data: `state:modified+` selects changed models + children, `--defer` points unchanged upstreams at prod, Slim CI runs only that. The tradeoff: **Slim CI trades manifest-management complexity for massive time/cost savings** — and fast CI people actually wait for catches more real bugs than slow CI they route around.

**Example / honest note.** The public scaffold runs a **full build** on DuckDB (fast, self-contained, no external state). In a cloud deploy I'd switch to:

```bash
dbt build --select state:modified+ --defer --state ./prod-manifest --target ci
```

which needs a stored prod manifest. I left that out of the public repo on purpose so it stays runnable without external state — and documented it so the *reasoning* is visible.

**Exercise.** Write the Slim-CI plan: selector, defer/state mechanism, merge-blocking criteria, promotion strategy. **Done when** a reviewer could stand it up from the doc and knows why full-build CI was rejected for the cloud case.

### 3.3 Environments, profiles, secrets

**Concept + tradeoff.** `profiles.yml` holds connection config *outside* the repo, with `dev`/`ci`/`prod` targets writing to different schemas; secrets come from `env_var`, never committed. The tradeoff: **separation adds config overhead in exchange for making a dev mistake structurally unable to touch prod.**

**Example.** [`profiles.example.yml`](../pipelines/dbt_saas_analytics/profiles.example.yml) ships three targets and defaults to `dev` (never `prod`). The real `profiles.yml`, `.env`, and keys are blocked by [`.gitignore`](../.gitignore). On DuckDB there are no credentials at all, which is why the public repo is safe to run as-is.

**Anti-pattern.** A token pasted into `profiles.yml` and committed — a permanent credential leak the moment anyone clones.

**Exercise.** Write a `profiles.yml` with three targets, all auth via `env_var`, dev≠prod schema, default target = dev. **Done when** `dbt debug` connects for dev and grep finds zero literal secrets.

### 3.4 Cost & performance

**Concept + tradeoff.** Partitioning prunes scans; clustering (Z-order/liquid on Databricks, clustering keys on Snowflake, dist/sort on Redshift) co-locates filtered rows; incremental is usually the biggest lever at scale. The tradeoff: **every optimization adds complexity/rigidity and only pays at scale — profile first, optimize the one thing the plan blames.** Over-partitioning a small table *slows* it.

**Anti-pattern.** Optimizing by vibes — adding clustering/partitioning because "big table = optimize" without reading a query plan, while the real bottleneck (a fan-out join) is untouched.

**Exercise.** `EXPLAIN` a date-filtered query, read whether pruning happens, and justify exactly one optimization from the evidence. **Done when** you can also name a case where partitioning would hurt.

### 3.5 Observability

**Concept + tradeoff.** `run_results.json`/`manifest.json` → monitoring (elementary/re_data) → alerting on freshness/test failures. The tradeoff: **observability is insurance that produces no data value directly — under-invest and you fly blind; over-invest and alert fatigue makes the team mute the channel.** I alert only on "a human must act now" (reconciliation fail, freshness breach, key non-unique) and let the rest be dashboards.

**Anti-pattern.** Routing every `warn` to a paging channel until everyone mutes it — then the one critical page scrolls past unseen.

**Exercise.** Assign every check to page / notify / dashboard-only. **Done when** the page tier contains only genuine act-now failures and each warn's non-page status is justified.

### 3.6 Data-quality strategy

**Concept + tradeoff.** Test the *assumption at the layer where it first becomes true or false*: source assumptions in staging, transform correctness in intermediate, business invariants + **reconciliation** in marts. Decide **block vs quarantine** by criticality (financial marts block; soft metrics quarantine and continue). The tradeoff: **testing everywhere is noisy; testing nowhere is a time bomb** — and the non-negotiable is reconciliation, because it's the only test that catches systematic errors that leave everything green.

**Example.** Key-uniqueness tested once in staging (where dedupe happens), reconciliation at the mart. **Green pipeline ≠ correct; reconciled = correct.**

**Exercise.** Build a test-placement map (assertion → layer → block/quarantine → severity) with no assertion tested twice and at least one reconciliation test. **Done when** it would catch a systematic (e.g. timezone) error.

### 3.7 Change management

**Concept + tradeoff.** A canonical model is a public API. I classify changes as breaking (rename/type/grain) vs non-breaking (add a nullable column), check blast radius with `dbt ls --select model+` and `+exposure:`, and run a deprecation path (version + `deprecation_date` + notify) for breaking changes. The tradeoff: **ceremony slows down "obvious" improvements in exchange for not breaking consumers who trusted you — match the ceremony to the blast radius.**

**Anti-pattern.** The "harmless cleanup" rename on a shared mart, merged Friday, breaks six dashboards Monday. The change was correct; the *process* failed. The mirror image: never deprecating anything, so dead `v1…v5` pile up forever.

**Exercise.** Plan a breaking change to `dim_users`: identify blast radius, choose version-vs-in-place, set a `deprecation_date`, list consumers, include the remove-v1 step. **Done when** a teammate could run the migration from the plan.

---

## One-page mental model (redraw from memory)

```
            RAW LOGS  →  CANONICAL DATASETS
  (cheap, lossless capture)   (correct, cheap, trusted)

  1. DEFINE            2. BUILD                   3. MANAGE
  grain first         source()/ref() = the DAG   orchestrate: freshness→
  ↓ dimensions        stg → int → mart layers       snapshot→build→docs
  ↓ measures          view/table/incr/ephemeral   Slim CI: state:modified+
  ↓ sources (map      incremental: received_at      --defer --state
    back, find gap)     + lookback + merge         env isolation, env_var secrets
  conformed dims      tests: right thing/layer    partition/cluster only if profiled
  SCD1 vs SCD2        contracts = API on marts    observability + act-now alerts
  "one row = ___"     docs + exposures = lineage  reconcile to truth; version breaks

  THE 5 SILENT DATA-KILLERS:
   • incremental filtered on event_time (client), not received_at
   • no lookback → late data lost forever
   • no unique_key/merge → reprocessing duplicates
   • overwriting an SCD2 attribute → history rewritten
   • no reconciliation → systematic errors stay green

  GREEN PIPELINE ≠ CORRECT DATA.  RECONCILED = CORRECT.
```

**The one sentence:** *Design backward from the decision (grain→dims→measures→sources), build in layers with the DAG as the source of truth, load incrementally on ingest-time-with-lookback-and-merge, and never trust a number I haven't reconciled.*

---

## dbt PR review checklist

Grouped by pillar. **[BLOCK]** = request changes; **[FLAG]** = comment and discuss.

**Design** — [BLOCK] grain stated and unambiguous · [BLOCK] model in the correct layer (stg does no joins; marts don't read `raw`) · [FLAG] dimensions conformed · [FLAG] SCD1/SCD2 deliberate · [FLAG] naming convention.

**Sources & refs** — [BLOCK] no hard-coded table names (grep `raw.`/`prod.`) · [FLAG] freshness block present · [FLAG] seeds only for small static data.

**Materialization & incrementals** — [FLAG] materialization justified · [BLOCK] incremental filters on ingest time not client time · [BLOCK] lookback + `unique_key` + merge (idempotent) · [FLAG] `on_schema_change` set.

**Tests & quality** — [BLOCK] grain key has `unique`+`not_null` · [BLOCK] reconciliation test for trusted numbers · [FLAG] severities deliberate (no `not_null` on nullable columns) · [FLAG] assertions at the right layer.

**Abstraction** — [FLAG] no macro with reuse count of one · [FLAG] model readable top-to-bottom.

**Contracts / docs / change mgmt** — [BLOCK] breaking change (rename/type/grain) has version + deprecation path · [BLOCK] blast radius checked (`model+`, `+exposure:`) · [FLAG] new columns documented with meaning · [FLAG] contract on consumer-facing marts.

**Ops & CI** — [FLAG] no secrets committed (all `env_var`) · [FLAG] CI green · [FLAG] optimizations justified by a profile, not a guess.

**One-liner:** *Grain stated, refs not hard-coded, incremental filters on ingest-time-with-lookback-and-merge, key is unique, trusted numbers reconcile, breaking changes are versioned. Everything else is style.*

---

## Capstone — the end-to-end mart that proves the method

The runnable pipeline in [`/pipelines/dbt_saas_analytics`](../pipelines/dbt_saas_analytics) *is* the capstone: a canonical `fct_user_sessions` built end-to-end from the raw app-event log, with an SCD2 `dim_users`, a stretch `fct_user_weekly_engagement` mart that reuses both (proving the layering + conformed-dimension payoff), tests including a reconciliation assertion, an enforced contract, an incremental strategy with a 3-day ingest lookback, docs + an exposure, and a CI workflow that builds, tests, and re-runs for idempotency on every push.

**Capstone definition of done:**
- The four-model stack builds clean with `dbt build`.
- `fct_user_sessions` is incremental, filters on `received_at` with a 3-day lookback, and is idempotent (two consecutive runs → identical results).
- `session_key` passes `unique`+`not_null`; the reconciliation test passes and *fails* if a row is corrupted.
- The enforced contract blocks a deliberate type mismatch.
- `dbt docs generate` renders source→fact→exposure lineage.
- The CI workflow is green, with a written Slim-CI plan for the cloud case, an alerting-tier table, and a breaking-change migration plan.
