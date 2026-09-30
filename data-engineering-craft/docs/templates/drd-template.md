# Data Requirements Document (DRD)

> Where business language becomes **unambiguous definitions**. Every metric gets
> a formula, a grain, and filters. This is the contract.

## 1. Linked BRD
-

## 2. Grain of the analysis
> One row = ?

## 3. Metric Definitions
| Metric | Definition (exact formula) | Grain | Filters / Inclusions | Source of Truth |
|--------|----------------------------|-------|----------------------|-----------------|
|        |                            |       |                      |                 |

## 4. Dimensions & Attributes
| Dimension | Attributes | Used to slice by |
|-----------|------------|------------------|
|           |            |                  |

## 5. Data Sources
| Source System | Object / Table | Owner | Access method | Known issues |
|---------------|----------------|-------|---------------|--------------|
|               |                |       |               |              |

## 6. Freshness / SLA
| Deliverable | Latency | Ready-by | On lateness |
|-------------|---------|----------|-------------|
|             |         |          |             |

## 7. Data Quality Expectations
| Rule | Severity | Action on failure |
|------|----------|-------------------|
|      |          |                   |

## 8. Definitions / Glossary (agreed terms)
- **term** = definition (confirmed with ___ on ___)

## 9. Gaps & Risks (data not captured today)
-

---

<details>
<summary>Filled example (click to expand)</summary>

**Grain:** one row per rep per day (daily snapshot); dashboard aggregates to quarter.

| Metric | Definition | Grain | Filters | Source of Truth |
|--------|-----------|-------|---------|-----------------|
| Bookings | `SUM(opportunity.amount) WHERE stage='Closed Won'` | rep, day | close_date in period; exclude auto-renewals; USD | RevOps bookings report |
| Win Rate | Closed Won ÷ (Closed Won + Closed Lost) | rep, qtr | exclude opps < $1k; exclude test accts | CRM |

**Glossary:** "Booking" = Closed Won by close_date (confirmed w/ RevOps).
**Gap:** quota history not retained → must snapshot daily going forward.

See [the full methodology](../stakeholder-to-technical-requirements.md#42-data-requirements-doc-drd)
for the complete filled example.

</details>
