# Translating Stakeholder Data Needs into Technical Requirements
### A Senior Data Engineer's Field Guide

> The single highest-leverage skill in data engineering is not SQL, not Spark, not modeling — it's **turning a fuzzy business sentence into a precise, buildable, testable specification**. Everything downstream (cost, latency, correctness, trust) is decided in the first two conversations. This guide is how senior DEs run those conversations.

---

## Table of Contents

1. [The End-to-End Process](#1-the-end-to-end-process)
2. [The 20 Highest-Leverage First-Meeting Questions](#2-the-20-highest-leverage-first-meeting-questions)
3. [Decoding What Stakeholders Really Mean](#3-decoding-what-stakeholders-really-mean)
4. [The Four Core Artifacts (Templates + Examples)](#4-the-four-core-artifacts)
5. [Common Failure Modes](#5-common-failure-modes)
6. [Three Before/After Case Studies](#6-three-beforeafter-case-studies)
7. [Five Practice Scenarios](#7-five-practice-scenarios)

---

## 1. The End-to-End Process

Senior DEs treat requirements as a **pipeline**, not an event. Each stage consumes the previous stage's artifact and produces a more precise one. The golden rule: **never let ambiguity flow downstream** — the cost of clarifying a metric definition in a meeting is minutes; the cost of discovering it was wrong after the pipeline ships is weeks.

| Stage | What Happens | Who Drives | Artifact Produced | Exit Criteria |
|-------|-------------|-----------|-------------------|---------------|
| **1. Discovery** | Understand the business problem, the decision the data will inform, and who acts on it. Listen more than you talk. | Stakeholder talks, DE listens | **Business Requirements Doc (BRD)** | You can state the business goal in one sentence and name the decision it drives |
| **2. Clarification** | Convert vague language into precise definitions. Nail down every metric, grain, filter, and edge case. Negotiate scope. | DE drives with questions | **Data Requirements Doc (DRD)** | Every metric has an unambiguous formula; every term has a definition |
| **3. Data Modeling** | Map required outputs back to available sources. Design the logical model (star schema / normalized). Identify gaps. | DE drives | **Logical Data Model (ERD / star schema)** | Model supports every metric in the DRD; grain is explicit; conformed dimensions identified |
| **4. Technical Spec** | Translate the model into an implementable design: sources, transforms, SLAs, DQ rules, lineage, orchestration. | DE drives | **Technical Specification** | An engineer who wasn't in the meetings could build it from the doc alone |
| **5. Validation** | Confirm the spec answers the original business question. Prototype key numbers, reconcile against a source of truth, get stakeholder sign-off. | DE + Stakeholder | **Signed-off spec + reconciliation evidence** | Stakeholder confirms the numbers match reality; acceptance tests pass |

### The mental model

```
Business language  →  Precise definitions  →  Logical structure  →  Buildable design  →  Verified truth
   (Discovery)         (Clarification)        (Data Modeling)       (Technical Spec)      (Validation)
      BRD                   DRD                  ERD/Star             Tech Spec          Sign-off + recon
```

**What separates senior from junior at each stage:**

- **Discovery** — Seniors ask *"what decision will this data change?"* Juniors ask *"what columns do you want?"*
- **Clarification** — Seniors refuse to proceed on undefined terms ("active user" means what, exactly?). Juniors assume and build.
- **Modeling** — Seniors design for the questions *not yet asked* (the second and third question always come). Juniors model exactly one report.
- **Technical Spec** — Seniors specify SLAs, DQ, and failure behavior up front. Juniors specify the happy path.
- **Validation** — Seniors reconcile to a trusted number before declaring victory. Juniors ship when the pipeline runs green.

---

## 2. The 20 Highest-Leverage First-Meeting Questions

Ask these in roughly this order. The goal of the first meeting is **not** to design anything — it's to leave with enough to write a DRD without guessing.

### Group A — Understanding the Business Goal (the "why")
> If you get these wrong, everything else is wasted effort — you'll build the wrong thing correctly.

1. **"What decision or action will this data enable that you can't make today?"** — Forces the ask from *artifact* to *outcome*.
2. **"Who is the audience, and what will they do differently when they see it?"** — Reveals the real consumer and the required precision.
3. **"If this were perfect, what's the first thing you'd look at Monday morning?"** — Surfaces the actual primary use case vs. the wish list.
4. **"What are you using today, and why isn't it enough?"** — Uncovers existing sources, prior art, and the true pain.

### Group B — Defining the Metrics (the "what")
> This is where most requirements silently break. A metric name is not a definition.

5. **"When you say '[their metric]', what's the exact numerator and denominator / formula?"** — The most important question in the whole meeting.
6. **"At what grain do you need this — per user, per order, per day, per region?"** — Grain drives the entire model.
7. **"What filters are always applied? Do we include test accounts, internal users, refunds, cancellations?"** — The edge cases that move numbers 5–20%.
8. **"How should this be sliced — by what dimensions (time, geo, product, segment)?"** — Defines the dimensional model.
9. **"Is there an existing number for this we must match? Whose number is the 'truth'?"** — Your reconciliation target.

### Group C — Scoping Data Sources (the "where from")
10. **"Which systems is this data in today — and who owns them?"** — Sources + humans to negotiate with.
11. **"Are there known data quality problems in those systems we should expect?"** — Pre-empts the "data looks wrong" fire drill.
12. **"Is any of this data I'll need not being captured today?"** — Surfaces instrumentation gaps early (the killer scope risk).

### Group D — Freshness / SLAs (the "how fast")
13. **"How fresh does this need to be — real-time, hourly, daily, or is yesterday fine?"** — Freshness is the biggest cost driver.
14. **"By what time each day must it be ready, and what breaks if it's late?"** — Turns "fresh" into a concrete delivery SLA.
15. **"Is this a one-time analysis or an ongoing, operational feed?"** — One-off vs. productionized changes everything.

### Group E — Quality Expectations (the "how correct")
16. **"What's the tolerance for error — is 'approximately right, fast' okay, or must it reconcile to the penny?"** — Finance vs. exploratory differ enormously.
17. **"What must NEVER be wrong — the numbers people will screenshot for the exec / the board?"** — Identifies the critical DQ assertions.
18. **"How should we handle late-arriving or missing data — wait, estimate, or show a gap?"** — Defines completeness policy.

### Group F — Downstream Usage (the "then what")
19. **"How will this be consumed — a dashboard, an email, an API, a reverse-ETL into another tool?"** — Serving layer and interface.
20. **"Who else will want this once they see it, and how might the ask grow in 6 months?"** — Lets you model for extensibility, not just today.

> **Senior tip:** Close every first meeting with: *"Let me play back what I heard…"* and read your understanding aloud. Two-thirds of misalignment surfaces in that 90-second playback.

---

## 3. Decoding What Stakeholders Really Mean

Stakeholders speak in outcomes and shorthand. Your job is to translate to requirements *without making them feel interrogated*. For each phrase below: what they say, what they often mean, and the hidden requirements a senior DE probes for.

### 🗣️ "We need a dashboard for X"
**What it often means:** "I have a recurring question I'm tired of asking someone to answer manually," OR "my boss asked me for X and I'm passing it along."

**Hidden requirements to probe:**
- **Is a dashboard even the right medium?** Often they need a single alerting number or a weekly email, not a BI dashboard nobody opens.
- **What's the *one* decision this dashboard drives?** Dashboards with no decision become dashboard graveyards.
- **Refresh cadence & interactivity** — static snapshot vs. self-serve drill-down. Massive cost difference.
- **Grain & filters** — what dimensions must be filterable? Time granularity?
- **Audience & access** — execs (curated, few numbers) vs. analysts (raw, flexible)?
- **Is there an existing report it must reconcile to?**
- **Lifespan** — is this a permanent operational asset or a one-quarter initiative?

### 🗣️ "Can you pull some numbers on Y?"
**What it often means:** The start of an *iterative investigation*, not a one-shot request. "Some numbers" almost always becomes "and now can you break that down by…".

**Hidden requirements to probe:**
- **What question are the numbers meant to answer?** Pull the *question*, not the numbers.
- **Is this one-time or the first of many?** Decides whether you write a throwaway query or a reusable model.
- **What grain and time window?** "Sales" — total? by day? trailing 30? YoY?
- **What's the definition of Y?** ("revenue" = booked, billed, recognized, or collected?)
- **What decision hinges on it, and by when?** Sets urgency and required precision.
- **Do they need to slice it themselves afterward?** If yes → build a small model, not a one-off extract.

### 🗣️ "The data looks wrong"
**What it often means:** Either (a) the data *is* wrong, (b) the data is right but contradicts their expectation/mental model, or (c) a definition mismatch between two reports. Most of the time it's (b) or (c).

**Hidden requirements to probe:**
- **"What number did you expect, and where does your expectation come from?"** — Anchor to a specific delta.
- **"Which specific figure, for which period, on which view?"** — Reproduce the exact cell.
- **"What are you comparing it against?"** — Two reports with different filters/grain/timezones is the #1 cause.
- **Timezone, currency, and as-of-date alignment** — silent killers.
- **Late-arriving data / refresh timing** — did they look before the pipeline finished?
- **Definition drift** — did "active user" change meaning between the two sources?
- **Requirement:** every trusted number needs documented lineage + a reconciliation rule so this becomes a 5-minute lookup, not an investigation.

### 🗣️ "We want real-time analytics"
**What it often means:** "I want fresher data than I have now." True sub-second real-time is rarely needed and 10–100× more expensive. "Real-time" usually means "I don't want to wait until tomorrow."

**Hidden requirements to probe:**
- **"What's the fastest action anyone would take on this?"** If the human reacts hourly, real-time is wasted money.
- **Quantify latency:** sub-second? seconds? minutes? "Fresh within 15 min" is a totally different (cheaper) system than streaming.
- **Is it operational (drives an automated action) or analytical (a human reads it)?**
- **Freshness vs. completeness trade-off** — real-time data is *incomplete* data; late events arrive after the fact. Can they tolerate numbers that revise?
- **Cost & on-call reality** — streaming infra means 24/7 operational burden. Do they own that?
- **Requirement:** pin an explicit latency SLA and an explicit correctness-vs-speed policy before choosing streaming.

### 🗣️ "We need to track customer engagement"
**What it often means:** They have a goal (retention, growth, activation) but no agreed definition of "engagement." This is a *definition* problem masquerading as a data problem.

**Hidden requirements to probe:**
- **"What does an engaged customer *do*?"** — Define the concrete events (login, purchase, feature use, session length?).
- **"Engaged over what window?"** — daily, 7-day, 28-day active? Rolling or calendar?
- **Unit of analysis** — user, account, household, device?
- **What counts as an "event"?** — Requires event instrumentation that may not exist yet (big scope risk).
- **Is this a leading indicator for a business outcome?** — engagement usually proxies retention/revenue; confirm the link.
- **Identity resolution** — same human across devices/logins? Anonymous → known stitching?
- **Requirement:** produce a written **engagement metric definition** (events + window + unit + filters) and get it signed off *before* building anything.

> **The meta-pattern:** Every vague ask hides three things a senior DE always extracts — **(1) the decision it drives, (2) the precise definition of the key term, and (3) the freshness/correctness tolerance.** Get those three and the rest is engineering.

---

## 4. The Four Core Artifacts

Each artifact below is shown as a reusable template, then filled with a realistic example for the **same running scenario** so you can see how information flows from one doc to the next.

**Running scenario:** A VP of Sales at a B2B SaaS company asks: *"We need a dashboard to see how our sales team is performing so we can spot reps who need coaching."*

---

### 4.1 Business Requirements Doc (BRD)

The BRD captures the *why* and *what* in business language. No schemas, no SQL. If a business stakeholder can't read and approve it, it's not a BRD.

**Template**

```
# Business Requirements Document

## 1. Overview
- Title:
- Author / Date / Version:
- Sponsor (who is accountable):
- Status: Draft | In Review | Approved

## 2. Business Problem & Goal
- Problem statement (1-2 sentences):
- Business goal / desired outcome:
- Decision(s) this enables:

## 3. Stakeholders
| Role | Name | Interest | Sign-off? |

## 4. Scope
- In scope:
- Out of scope (explicitly):
- Assumptions:

## 5. Success Criteria
- How we'll know this succeeded (measurable):

## 6. Constraints & Deadlines
- Timeline / hard dates:
- Budget / tooling constraints:

## 7. Open Questions
```

**Filled Example**

```
# Business Requirements Document

## 1. Overview
- Title: Sales Rep Performance & Coaching Dashboard
- Author: J. Rivera (Data Eng) / 2026-09-21 / v0.2
- Sponsor: VP Sales, D. Okafor (accountable)
- Status: In Review

## 2. Business Problem & Goal
- Problem: Sales leadership has no consistent, timely view of individual rep
  performance, so underperformers are identified late — usually only at
  quarter-end QBRs, too late to intervene.
- Goal: Enable managers to spot reps trending below target *within the quarter*
  so coaching happens in weeks 4-8, not week 13.
- Decision enabled: Which reps get a targeted coaching plan this month.

## 3. Stakeholders
| Role            | Name       | Interest                    | Sign-off? |
| VP Sales        | D. Okafor  | Overall accountability      | Yes       |
| Sales Managers  | 6 managers | Daily users                 | No        |
| RevOps Lead     | S. Chen    | Owns quota & CRM definitions| Yes       |
| Data Eng        | J. Rivera  | Builds it                   | -         |

## 4. Scope
- In scope: Rep-level bookings, pipeline coverage, win rate, activity vs quota;
  current + trailing 4 quarters; direct sales team (not channel/partner).
- Out of scope: Commission calculation, partner/channel sales, forecasting model.
- Assumptions: Salesforce is the system of record for opportunities & quotas.

## 5. Success Criteria
- 100% of the 6 managers use it weekly within 30 days of launch.
- At least 3 at-risk reps identified before week 8 in the first quarter.
- Numbers reconcile to RevOps' official quarter-end bookings report (±0%).

## 6. Constraints & Deadlines
- Live before start of Q1 (hard date: 2026-01-05).
- Must use existing BI tool (no new vendor).

## 7. Open Questions
- Does "booking" mean signed contract date or close date in CRM? (→ DRD)
- How are mid-quarter quota changes handled? (→ RevOps)
```

---

### 4.2 Data Requirements Doc (DRD)

The DRD is where business language becomes **unambiguous definitions**. Every metric gets a formula, a grain, and filters. This is the contract.

**Template**

```
# Data Requirements Document

## 1. Linked BRD:
## 2. Grain of the analysis (one row = ?):

## 3. Metric Definitions
| Metric | Definition (exact formula) | Grain | Filters / Inclusions | Source of Truth |

## 4. Dimensions & Attributes
| Dimension | Attributes | Used to slice |

## 5. Data Sources
| Source System | Object/Table | Owner | Access method | Known issues |

## 6. Freshness / SLA
| Deliverable | Latency | Ready-by | On lateness |

## 7. Data Quality Expectations
| Rule | Severity | Action on failure |

## 8. Definitions / Glossary (agreed terms)
## 9. Gaps & Risks (data not captured today)
```

**Filled Example**

```
# Data Requirements Document — Sales Rep Performance

## 1. Linked BRD: Sales Rep Performance & Coaching Dashboard v0.2
## 2. Grain: One row per rep per day (daily snapshot); dashboard aggregates to quarter.

## 3. Metric Definitions
| Metric          | Definition                                             | Grain     | Filters                                   | Source of Truth |
| Bookings        | SUM(opportunity.amount) WHERE stage='Closed Won'       | rep, day  | close_date in period; exclude type='Renewal-Auto'; USD | RevOps bookings report |
| Attainment %    | Bookings / Quota for the period                        | rep, qtr  | Quota = active quota as of period start   | RevOps quota sheet |
| Win Rate        | Closed Won count / (Closed Won + Closed Lost) count    | rep, qtr  | Exclude opps < $1k (noise); exclude test accts | CRM |
| Pipeline Cover  | Open pipeline amount / remaining quota                 | rep, qtr  | Open = not Closed; weighted by stage prob | CRM |
| Activity Score  | Calls + meetings logged                                | rep, week | Exclude auto-logged system events         | CRM activity |

## 4. Dimensions
| Dimension | Attributes                          | Slice by |
| Rep       | rep_id, name, manager, region, tenure| yes |
| Time      | day, week, month, quarter, fiscal_qtr| yes |
| Segment   | SMB / Mid / Enterprise               | yes |
| Product   | product_line                         | yes |

## 5. Data Sources
| Source     | Object            | Owner   | Access        | Known issues |
| Salesforce | Opportunity, User | RevOps  | Fivetran sync | Amount null on ~2% of won opps (manual fix) |
| Salesforce | Quota (custom)    | RevOps  | Fivetran sync | Mid-qtr changes overwrite, no history |
| Salesforce | Activity          | Sales   | Fivetran sync | Auto-logged emails inflate counts |

## 6. Freshness / SLA
| Deliverable         | Latency | Ready-by      | On lateness |
| Daily rep snapshot  | Daily   | 7:00 AM local | Alert #data-oncall; show stale banner |

## 7. Data Quality Expectations
| Rule                                   | Severity | Action |
| Bookings total = RevOps report (±0%)   | Critical | Block publish, page on-call |
| No rep with null quota in active qtr   | High     | Warn, exclude rep, flag on dash |
| Win rate between 0 and 1               | Critical | Block publish |
| Activity count within 3σ of 30-day avg | Low      | Warn only |

## 8. Glossary
- "Booking" = Closed Won by close_date (CONFIRMED w/ RevOps 2026-09-20).
- "Active rep" = User with role='AE' AND is_active=true.
- "Quota" = period quota snapshotted at period start (mid-qtr changes ignored for scoring — RevOps decision).

## 9. Gaps & Risks
- Quota history not retained → we must snapshot daily going forward (new requirement).
- Auto-logged activity inflates Activity Score → need source flag to filter.
```

---

### 4.3 Logical Data Model (Star Schema)

Maps the DRD to a dimensional structure. For this scenario a **star schema** fits: a central fact (sales activity/bookings) surrounded by conformed dimensions.

**ERD (text form)**

```
                         ┌─────────────────────┐
                         │      dim_date        │
                         │──────────────────────│
                         │ date_key (PK)        │
                         │ date, week, month    │
                         │ quarter, fiscal_qtr  │
                         └──────────┬───────────┘
                                    │
┌───────────────────┐    ┌──────────▼───────────┐    ┌────────────────────┐
│     dim_rep        │    │   fact_opportunity   │    │     dim_segment      │
│────────────────────│    │──────────────────────│    │──────────────────────│
│ rep_key (PK)       │◄───│ rep_key (FK)         │───►│ segment_key (PK)     │
│ rep_id (NK)        │    │ date_key (FK)        │    │ segment_name         │
│ name, manager      │    │ segment_key (FK)     │    │ (SMB/Mid/Ent)        │
│ region, tenure     │    │ product_key (FK)     │    └────────────────────┘
│ is_active (SCD2)   │    │ opportunity_id (DD)  │
└───────────────────┘    │ ── measures ──       │    ┌────────────────────┐
                         │ amount_usd           │───►│    dim_product       │
┌───────────────────┐    │ is_closed_won        │    │──────────────────────│
│    dim_quota       │    │ is_closed_lost       │    │ product_key (PK)     │
│────────────────────│    │ stage_probability    │    │ product_line         │
│ quota_key (PK)     │◄───│ quota_key (FK)       │    └────────────────────┘
│ rep_key (FK)       │    └──────────────────────┘
│ period, quota_amt  │
│ snapshot_date(SCD2)│    Grain: 1 row per opportunity per snapshot day
└───────────────────┘
```

**Why this model:**
- **Star, not normalized** — read-heavy BI workload; analysts slice by many dimensions; joins must be cheap and obvious.
- **`fact_opportunity` at opportunity-per-day grain** — supports both point-in-time snapshots (pipeline as of any day) and closed-won aggregation. Daily snapshot solves the "quota has no history" gap.
- **`dim_rep` and `dim_quota` are SCD Type 2** — we must attribute a booking to the rep/quota *as they were at that time*, not today (rep changed manager, quota changed mid-quarter). SCD2 preserves history — directly addresses the Section 9 gap.
- **Conformed dimensions** (`dim_date`, `dim_rep`) — reusable across future sales facts (activity, forecast) so the second and third stakeholder ask reuses the same dims.

---

### 4.4 Technical Specification

The build doc. An engineer who never attended a meeting should be able to implement it from this alone.

**Template**

```
# Technical Specification

## 1. Summary & linked DRD
## 2. Architecture (sources → ingest → transform → serve)
## 3. Source-to-Target Mapping
| Target field | Source | Transformation | Notes |
## 4. Pipeline / Orchestration
- Schedule, dependencies, backfill strategy
## 5. SLAs
| Metric | Target | Measurement | Alert |
## 6. Data Quality Rules
| Test | Type | Threshold | On failure |
## 7. Data Lineage
## 8. Serving Layer
## 9. Security / Access / PII
## 10. Failure & Recovery
## 11. Cost estimate
## 12. Acceptance tests
```

**Filled Example**

```
# Technical Specification — Sales Rep Performance

## 1. Summary
Daily-refreshed star schema in warehouse feeding a BI dashboard for sales
managers. Linked DRD: Sales Rep Performance v1.0.

## 2. Architecture
Salesforce → Fivetran (raw) → dbt staging → dbt marts (star) → BI tool
                                    │
                              dbt tests (DQ) + snapshots (SCD2)

## 3. Source-to-Target Mapping
| Target                         | Source                        | Transformation | Notes |
| fact_opportunity.amount_usd    | sf.opportunity.amount, .currency | convert to USD via dim_fx | null→0 + flag |
| fact_opportunity.is_closed_won | sf.opportunity.stage          | = 'Closed Won' | |
| dim_rep (SCD2)                 | sf.user WHERE role='AE'       | dbt snapshot on manager, region | daily |
| dim_quota (SCD2)               | sf.quota_c                    | dbt snapshot on quota_amt | captures mid-qtr changes |

## 4. Orchestration
- dbt Cloud job, daily 06:15 local (after Fivetran 06:00 sync completes).
- DAG: fivetran_sync → dbt_snapshot → dbt_run(staging→marts) → dbt_test → notify.
- Backfill: full-refresh only on schema change; snapshots are append-only.

## 5. SLAs
| Metric        | Target         | Measurement          | Alert |
| Freshness     | Ready by 07:00 | job end timestamp    | PagerDuty if > 07:00 |
| Completeness  | 100% of reps   | count(rep) vs roster | Slack #data-oncall |

## 6. Data Quality Rules (dbt tests)
| Test                                  | Type       | Threshold | On failure |
| bookings_total = revops_report        | singular   | ±0%       | error → block publish |
| dim_rep unique on (rep_id, valid_from)| unique     | 0 dupes   | error |
| amount_usd >= 0                        | accepted_range | 0..∞  | error |
| win_rate between 0 and 1              | singular   | [0,1]     | error |
| activity_count 3σ check               | singular   | 3σ        | warn |

## 7. Lineage
sf.opportunity → stg_opportunity → int_opportunity_enriched →
fact_opportunity → dashboard tile "Bookings". (auto-captured in dbt docs / column-level lineage)

## 8. Serving Layer
- Marts materialized as tables (not views) for dashboard perf.
- BI semantic layer defines Attainment %, Win Rate as governed metrics
  (single definition, no per-analyst drift).

## 9. Security / Access / PII
- Row-level security: managers see only their own team; VP sees all.
- No PII beyond employee name (internal). Restricted to Sales + Exec groups.

## 10. Failure & Recovery
- Fivetran delay → dashboard shows "as of <timestamp>" stale banner, does not fail.
- dbt test failure (critical) → last-good snapshot retained, publish blocked, page on-call.
- Idempotent: re-runnable for any date without duplication (snapshots + merge).

## 11. Cost estimate
- Warehouse: ~$120/mo (daily incremental, small volume).
- No streaming infra — daily batch meets the SLA (see decision below).

## 12. Acceptance tests
- Q3 bookings on dashboard = RevOps Q3 report to the dollar.
- Deactivating a rep mid-quarter preserves their historical bookings.
- Mid-quarter quota change reflected via SCD2, prior scoring unchanged.
```

> Note how a single confirmed definition in the DRD ("booking = Closed Won by close_date") flows all the way to an acceptance test. That traceability is the whole point.

---

## 5. Common Failure Modes

| # | Failure Mode | What It Looks Like | Concrete Example | How to Avoid |
|---|-------------|--------------------|--------------------|--------------|
| 1 | **Building the artifact, not solving the problem** | You deliver exactly what was asked; nobody uses it. | Stakeholder said "dashboard"; you built a 12-tile dashboard. They actually needed a single weekly "reps below 70% attainment" alert. Dashboard is never opened. | Ask "what decision does this drive?" and "what will you do Monday morning?" Propose the *lightest* medium that answers it. |
| 2 | **Assuming metric definitions** | Your number disagrees with theirs; trust evaporates. | You defined "revenue" as booked; Finance means recognized. Your dashboard shows $4.2M, their report shows $3.1M. Now every number you produce is doubted. | Never proceed on an undefined term. Write the formula in the DRD and get explicit sign-off. Reconcile to their source of truth. |
| 3 | **Ignoring grain** | Numbers double-count or can't be sliced the way they need. | You modeled at order grain; they need line-item detail to split revenue by product. You have to re-architect the fact table. | Nail grain in question #6 of the first meeting. State "one row = ___" at the top of the DRD. |
| 4 | **Over-engineering freshness** | Streaming pipeline for data a human reads once a day. | Built Kafka + Flink real-time pipeline; stakeholder checks the number every morning with coffee. 30× cost + 24/7 on-call for zero business benefit. | Ask "fastest action anyone takes on this?" Match latency to the *decision cadence*, not the request wording. |
| 5 | **Skipping data quality until it breaks in prod** | Silent bad data reaches an exec deck. | No null-check on `amount`; 2% of won deals had null amounts; Q-end bookings understated by $600k in the board deck. | Define DQ rules in the DRD, implement as tests in the spec. Critical rules *block publish*. |
| 6 | **No reconciliation to a source of truth** | Pipeline is green, numbers are wrong, nobody notices for weeks. | Timezone mismatch put late-night orders in the wrong day; daily totals off by ~5%; discovered only when a manager cross-checked. | Every trusted metric gets a reconciliation test against an agreed source. Green pipeline ≠ correct data. |
| 7 | **Modeling for exactly one report** | The inevitable follow-up ask forces a rebuild. | Hard-coded a single "bookings by rep" query; next week they want "by region and product" — no dimensions exist, full rework. | Model conformed dimensions and design for the 2nd/3rd question (first-meeting Q20). |
| 8 | **Not capturing history (SCD)** | Past attribution silently changes when source records update. | Rep moved teams; overwriting `manager` retroactively reassigned all their past bookings to the new manager. QBR numbers "changed" overnight. | Identify slowly-changing dimensions early; use SCD2 where history matters (org, quota, price). |
| 9 | **Requirements only in your head / chat** | Scope creep, disputes, no accountability. | Definitions lived in Slack threads; six weeks later two people "remember" different things and blame the DE. | Write it down (BRD/DRD/spec), version it, get sign-off. The doc is the contract. |
| 10 | **No validation with the stakeholder before scaling** | You build the whole thing on a wrong assumption. | Built 8 dashboards before showing anyone; the core metric was defined wrong; all 8 need rework. | Prototype the one key number first, reconcile, get a thumbs-up, *then* build out. |

---

## 6. Three Before/After Case Studies

### Case Study 1 — "We need a dashboard for marketing performance"

| | |
|---|---|
| **Original vague ask** | "We need a dashboard to see how marketing is doing." (from CMO) |
| **Clarifying questions asked** | • What decision will this drive? → *Where to reallocate next quarter's budget.* <br>• "Doing" measured how? → *Return on spend by channel.* <br>• Which channels? → *Paid search, paid social, email, events.* <br>• What does "return" mean — leads, pipeline, or closed revenue? → *Pipeline influenced within 90 days.* <br>• Attribution model? → *First-touch initially (simple), multi-touch later.* <br>• Freshness? → *Weekly is fine; budget decisions are monthly.* |
| **Metric definitions negotiated** | **Channel ROI** = (Influenced Pipeline in 90d ÷ Channel Spend). *Influenced pipeline* = SUM(opp.amount) WHERE opp has a first-touch attribution to that channel AND created within 90d of touch. *Spend* = platform spend + agency fees, monthly. Excludes brand/PR (no direct attribution). |
| **Final technical requirements** | Sources: ad platforms (via connector) + CRM opps + finance spend sheet. Weekly batch. Grain: channel × week. SCD2 on campaign→channel mapping. DQ: spend never null, ROI sanity range. Serve: 4-tile BI dashboard + monthly email export. |
| **Data model chosen & why** | **Star schema**: `fact_marketing_performance` (grain: channel × week) with `dim_channel`, `dim_date`, `dim_campaign`. Chosen because the ask will *grow* (they'll want campaign-level, then keyword-level) — conformed dims let us add grain without rework. Rejected a flat wide table because it wouldn't support drill-down. |

### Case Study 2 — "Can you pull some numbers on churn?"

| | |
|---|---|
| **Original vague ask** | "Can you pull some churn numbers for the QBR?" (from Head of CS) |
| **Clarifying questions asked** | • One-time or ongoing? → *Ongoing — they'll want it every quarter and monthly.* <br>• What decision? → *Which accounts to prioritize for retention outreach.* <br>• Define churn — logo or revenue? → *Both: logo churn for count, net revenue retention for $.* <br>• What's a "churned" account? → *No active subscription at period end AND not reactivated within 30d.* <br>• Grain? → *Per account per month.* <br>• Voluntary vs involuntary (failed payment)? → *Track separately.* |
| **Metric definitions negotiated** | **Logo Churn Rate** = (# accounts churned in month ÷ # active at month start). **NRR** = (start MRR + expansion − contraction − churn) ÷ start MRR, per cohort. *Churned* = subscription_status='cancelled' AND no reactivation within 30d. *Involuntary* = cancelled due to payment failure (flagged separately, excluded from voluntary churn). |
| **Final technical requirements** | Not a one-off extract — built a reusable model. Sources: billing system (subscriptions, MRR), CRM (account attributes). Monthly batch, ready by 3rd business day. Grain: account × month. DQ: MRR reconciles to finance ARR report; no negative MRR. Serve: model + QBR dashboard + row-level export for CS outreach list. |
| **Data model chosen & why** | **Accumulating snapshot fact** `fact_subscription_monthly` (grain: account × month) + `dim_account` (SCD2 for plan/segment changes). Chosen over a transaction fact because churn/NRR are inherently *point-in-time state* metrics (active vs not at month boundaries), and monthly snapshots make cohort retention trivial to compute. |

### Case Study 3 — "We want real-time inventory analytics"

| | |
|---|---|
| **Original vague ask** | "We need real-time analytics on our warehouse inventory." (from Ops Director) |
| **Clarifying questions asked** | • What's the fastest action taken on this? → *Reorder decisions + stopping oversell on the storefront.* <br>• Two different needs? → *Yes: (a) storefront stock accuracy = seconds; (b) reorder analytics = daily is fine.* <br>• Who/what consumes it — human or system? → *(a) the e-commerce system, automated; (b) a human planner.* <br>• Tolerance for staleness on (a)? → *Oversell is unacceptable — must be near-real-time.* <br>• On (b)? → *Yesterday's picture is fine.* |
| **Metric definitions negotiated** | **Available-to-Promise (ATP)** = on_hand − reserved − safety_stock, per SKU per location, event-updated. **Days of Cover** = current_on_hand ÷ trailing-28-day avg daily sales, per SKU, daily. Split the "real-time" ask into two distinctly-scoped requirements. |
| **Final technical requirements** | **Two pipelines.** (a) *Operational:* CDC stream from inventory system → streaming upsert → low-latency store powering ATP API (target < 5s, 99.9% uptime, on-call owned by Ops-eng). (b) *Analytical:* daily batch → warehouse → Days-of-Cover dashboard (ready 7 AM). |
| **Data model chosen & why** | **Hybrid.** (a) A **key-value / current-state store** keyed by (sku, location) for the ATP lookup — not a star schema; the access pattern is single-key point reads, not analytical slicing. (b) A **star schema** `fact_inventory_daily` (grain: sku × location × day) + `dim_sku`, `dim_location`, `dim_date` for the analytics. Chosen to *match each workload to the right store* instead of forcing one system to do both — the classic failure mode #4 avoided. |

> **The through-line in all three:** the vague ask was never the real requirement. Discovery + clarification split each into precisely-defined metrics, and the *data model followed from the access pattern and how the ask would grow* — not from the first sentence spoken.

---

## 7. Five Practice Scenarios

Work each one end-to-end: write the clarifying questions, negotiate metric definitions, then produce a mini DRD + chosen data model with justification. Suggested approach after each.

### Scenario 1 — Product
> **The PM says:** "We need to know if the new onboarding flow is working."

- Draft 8 clarifying questions.
- What does "working" mean? Propose 2–3 candidate metric definitions and how you'd get sign-off.
- What events must be instrumented that may not exist yet?
- *Focus: turning a subjective word ("working") into a measurable activation/conversion metric; spotting the instrumentation gap.*

### Scenario 2 — Finance
> **The CFO says:** "The revenue number in your dashboard doesn't match the board deck."

- What are your first 5 diagnostic questions?
- List the top 5 likely root causes in order of probability.
- What reconciliation rule and lineage would prevent this recurring?
- *Focus: the "data looks wrong" playbook; booked vs. recognized revenue; reconciliation as a permanent control.*

### Scenario 3 — Operations
> **The Ops lead says:** "Can you pull some numbers on delivery times?"

- Is this one-off or the first of many? How do you find out, and how does the answer change your build?
- Define "delivery time" three different ways and identify which the stakeholder likely means.
- What grain and dimensions do you model for?
- *Focus: resisting the throwaway extract; choosing grain; designing for the inevitable "now break it down by region" follow-up.*

### Scenario 4 — Customer Support
> **The Support Director says:** "We want a real-time dashboard of customer sentiment."

- Challenge the "real-time": what's the fastest action taken on sentiment?
- "Sentiment" from what source — tickets, surveys, NLP on chat? What are the definition + quality risks of each?
- Where would you push back on scope, and what would you propose instead?
- *Focus: over-engineered freshness; ambiguous/derived metrics; managing scope on an ML-flavored ask.*

### Scenario 5 — Executive / Cross-functional
> **The COO says:** "I want one dashboard that shows the health of the whole business."

- This is the hardest kind of ask. How do you decompose "health"?
- Which 5–7 metrics, owned by which teams, and how do you resolve conflicting definitions across departments?
- What's your phased delivery plan (what ships first)?
- *Focus: scoping an unbounded ask; conformed dimensions and governed metric definitions across domains; phasing to avoid failure mode #10.*

---

### How to self-grade
For each scenario, check yourself against the meta-pattern: did you extract **(1) the decision it drives, (2) the precise definition of the key term, and (3) the freshness/correctness tolerance**? If a senior DE reviewed your DRD, could they build from it with zero further questions? That's the bar.
