# data-engineering-craft

How I think about and build data engineering work: methodology docs paired with runnable, tested pipelines. Each responsibility in this repo comes as a **method** (the process I follow and the tradeoffs behind it) plus **proof** (code that builds green in CI).

The current focus is the path from **raw logs → canonical datasets** in dbt — defining, building, and managing the pipelines that transform a messy append-only event log into trustworthy, documented, tested facts and dimensions.

---

## Contents

| Area | What it is | Where |
|------|-----------|-------|
| **Requirements engineering** | Turning fuzzy stakeholder asks into precise, buildable specs (Discovery → Clarification → Modeling → Tech Spec → Validation). | [`docs/stakeholder-to-technical-requirements.md`](docs/stakeholder-to-technical-requirements.md) |
| ↳ BRD template | Business Requirements Document skeleton. | [`docs/templates/brd-template.md`](docs/templates/brd-template.md) |
| ↳ DRD template | Data Requirements Document skeleton. | [`docs/templates/drd-template.md`](docs/templates/drd-template.md) |
| ↳ Tech-spec template | Technical Specification skeleton. | [`docs/templates/tech-spec-template.md`](docs/templates/tech-spec-template.md) |
| **Raw logs → canonical datasets** | The method I follow to define, build, and manage dbt pipelines — three pillars, each with concept + tradeoff, worked example, anti-pattern, and exercise. | [`docs/raw-logs-to-canonical-datasets.md`](docs/raw-logs-to-canonical-datasets.md) |
| ↳ Runnable dbt project | The methodology, proven: a canonical `fct_user_sessions` pipeline built end-to-end from a synthetic event log, with tests, incremental strategy, SCD2, contract, docs, and CI. | [`pipelines/dbt_saas_analytics/`](pipelines/dbt_saas_analytics) |
| **CI** | Builds, tests, and re-runs the pipeline for idempotency on every push — on DuckDB, with no secrets. | [`.github/workflows/dbt_ci.yml`](.github/workflows/dbt_ci.yml) |

---

## The runnable pipeline at a glance

A fictional B2B SaaS app emits an append-only event log. The pipeline turns it into canonical datasets:

```
raw.raw_app_events  (synthetic seed; dupes, anonymous events, late arrivals, schema drift baked in)
   └─ stg_app_events__events        [view]        dedupe, coalesce identity, safe JSON extract
        └─ int_sessionized_events   [ephemeral]   30-min-gap sessionization
             ├─ fct_user_sessions   [incremental] canonical session fact (received_at + 3-day lookback)
             │     └─ fct_user_weekly_engagement [table]  → engagement_dashboard (exposure)
             └─ dim_users           [table]       SCD2, from users_snapshot
```

**What it demonstrates:** declared grain, layered architecture, `source()`/`ref()` lineage, source freshness, an idempotent incremental model that filters on **ingest time** with a lookback for late data, generic + singular + package tests, a **reconciliation** test, an enforced **contract**, SCD2 via snapshot, docs + an exposure, and a CI job that proves idempotency.

### Run it yourself

```bash
cd pipelines/dbt_saas_analytics
pip install dbt-duckdb
cp profiles.example.yml profiles.yml      # DuckDB — no credentials needed
dbt deps --profiles-dir .
dbt seed --profiles-dir .                  # load the synthetic raw log + lookups
dbt snapshot --profiles-dir .             # build SCD2 history
dbt build --profiles-dir .                 # run + test every model in DAG order
dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .
```

Everything is synthetic and fictional. No credentials, no cloud account, no cost.

---

## Repository layout

```
data-engineering-craft/
├── README.md
├── LICENSE
├── .gitignore
├── .github/
│   └── workflows/
│       └── dbt_ci.yml
├── docs/
│   ├── stakeholder-to-technical-requirements.md
│   ├── raw-logs-to-canonical-datasets.md
│   └── templates/
│       ├── brd-template.md
│       ├── drd-template.md
│       └── tech-spec-template.md
└── pipelines/
    └── dbt_saas_analytics/
        ├── dbt_project.yml
        ├── packages.yml
        ├── profiles.example.yml
        ├── seeds/
        │   └── plan_tier_lookup.csv
        ├── seeds_raw/
        │   ├── raw_app_events.csv
        │   └── raw_app_users.csv
        ├── models/
        │   ├── staging/
        │   │   └── app_events/
        │   │       ├── _app_events__sources.yml
        │   │       ├── _app_events__models.yml
        │   │       ├── stg_app_events__events.sql
        │   │       └── stg_app_events__users.sql
        │   ├── intermediate/
        │   │   └── int_sessionized_events.sql
        │   └── marts/
        │       ├── _marts.yml
        │       ├── dim_users.sql
        │       ├── fct_user_sessions.sql
        │       └── fct_user_weekly_engagement.sql
        ├── macros/
        │   └── clean_string.sql
        ├── snapshots/
        │   └── users_snapshot.sql
        └── tests/
            └── assert_sessions_purchases_reconcile.sql
```

---

## Roadmap

- [x] **Requirements engineering** — methodology + BRD/DRD/tech-spec templates.
- [x] **Raw logs → canonical datasets** — methodology doc + runnable dbt pipeline (sessions fact, SCD2 users dimension, weekly-engagement mart, tests, incremental, contract, CI).
- [ ] **Data quality & observability** — elementary-style monitors, anomaly detection, alert-tiering on freshness/test failures.
- [ ] **Orchestration** — the pipeline under an orchestrator (Airflow/Dagster) with retries, SLAs, and backfill runbooks.
- [ ] **Streaming / near-real-time** — micro-batch ingestion and incremental processing on a continuous event stream.
- [ ] **Dimensional modeling at scale** — conformed-dimension bus matrix across multiple fact tables.

---

## Conventions

- **Naming:** `stg_<source>__<table>`, `int_<verb>`, `dim_<entity>`, `fct_<grain>`.
- **Layers:** staging = view (clean interface), intermediate = ephemeral (reusable logic), marts = table/incremental (canonical, consumer-facing).
- **Incrementals** filter on ingest time (`received_at`) with a lookback window, and use a `unique_key` so reprocessing is idempotent.
- **Secrets** never land in the repo — `profiles.yml`, `.env`, and keys are blocked by `.gitignore`; connection auth comes from `env_var`.
- **Everything is synthetic.** No real companies, people, systems, or numbers.

## License

[MIT](LICENSE)
