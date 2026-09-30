# Technical Specification

> The build doc. An engineer who never attended a meeting should be able to
> implement it from this alone.

## 1. Summary & linked DRD
-

## 2. Architecture
> sources → ingest → transform → serve (diagram or description)

## 3. Source-to-Target Mapping
| Target field | Source | Transformation | Notes |
|--------------|--------|----------------|-------|
|              |        |                |       |

## 4. Pipeline / Orchestration
- **Schedule:**
- **Dependencies / DAG:**
- **Backfill strategy:**

## 5. SLAs
| Metric | Target | Measurement | Alert |
|--------|--------|-------------|-------|
|        |        |             |       |

## 6. Data Quality Rules
| Test | Type | Threshold | On failure |
|------|------|-----------|------------|
|      |      |           |            |

## 7. Data Lineage
> source → staging → intermediate → mart → serving tile

## 8. Serving Layer
- **Materialization / interface:**
- **Governed metric definitions:**

## 9. Security / Access / PII
- **Row-level security:**
- **PII handling / access groups:**

## 10. Failure & Recovery
- **On upstream delay:**
- **On critical test failure:**
- **Idempotency / re-run safety:**

## 11. Cost estimate
-

## 12. Acceptance tests
-

---

<details>
<summary>Filled example (click to expand)</summary>

**Architecture:** Salesforce → Fivetran (raw) → dbt staging → dbt marts (star) → BI tool, with dbt tests (DQ) + snapshots (SCD2).

| Target | Source | Transformation | Notes |
|--------|--------|----------------|-------|
| `fact_opportunity.amount_usd` | `sf.opportunity.amount` | convert to USD | null → 0 + flag |
| `dim_rep` (SCD2) | `sf.user WHERE role='AE'` | dbt snapshot on manager, region | daily |

**Critical DQ:** bookings total = RevOps report (±0%) → error blocks publish.
**Acceptance:** Q3 bookings on dashboard = RevOps Q3 report to the dollar.

See [the full methodology](../stakeholder-to-technical-requirements.md#44-technical-specification)
for the complete filled example.

</details>
