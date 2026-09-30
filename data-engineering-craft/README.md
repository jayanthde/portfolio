# Data Engineering Craft

> How I translate ambiguous stakeholder asks into precise, buildable, testable
> data requirements — the process I follow *before* writing a line of SQL.

Most data pipeline failures are decided before any code is written — in how the
requirement was (or wasn't) pinned down. This repository documents the
requirements-engineering process I use to prevent that: state the grain, nail
every metric formula, design the model to the access pattern, and reconcile to a
source of truth before building.

---

## Contents

| Doc | What it covers |
|-----|----------------|
| **[Stakeholder Needs → Technical Requirements](docs/stakeholder-to-technical-requirements.md)** | The full methodology: the discovery → clarification → modeling → spec → validation process, 20 high-leverage discovery questions, how to decode what stakeholders really mean, the four core artifacts with filled examples, common failure modes, and three before/after case studies. |
| **[BRD template](docs/templates/brd-template.md)** | Business Requirements Doc — captures the *why* and *what* in business language. |
| **[DRD template](docs/templates/drd-template.md)** | Data Requirements Doc — turns business language into unambiguous metric definitions, grain, sources, SLAs, and DQ rules. |
| **[Technical Spec template](docs/templates/tech-spec-template.md)** | The build doc — source-to-target mapping, materialization, SLAs, DQ tests, lineage, serving, failure/recovery, and acceptance tests. |

---

## The mental model

```
Business language → Precise definitions → Logical structure → Buildable design → Verified truth
   (Discovery)        (Clarification)       (Data Modeling)      (Technical Spec)     (Validation)
      BRD                  DRD                 ERD / Star           Tech Spec         Sign-off + recon
```

Each stage consumes the previous stage's artifact and produces a more precise
one. The golden rule: **never let ambiguity flow downstream** — the cost of
clarifying a metric definition in a meeting is minutes; the cost of discovering
it was wrong after the pipeline ships is weeks.

---

## Why this matters

The highest-leverage skill in data engineering isn't SQL or Spark — it's turning
a fuzzy business sentence into a specification an engineer can build and a test
can verify. Everything downstream (cost, latency, correctness, trust) is decided
in the first two conversations. This repo is how I run them.

## Roadmap

This documents the *design thinking* layer. A companion working dbt pipeline —
implementing one of the case studies end-to-end (staging → intermediate →
canonical marts, incremental models, tests, source freshness, CI) — is in
progress and will be linked here.

---

## License

[MIT](LICENSE)
