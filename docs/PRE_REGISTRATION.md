# Pre-Registration — Executive Orders & Divided Government

**Frozen:** 2026-06-30, *before any data was pulled or inspected.*
**Enforcement note:** this plan was written in an environment with no network access to the data sources. The analyst had not seen a single data point when committing to the spec below. That is the point.

---

## 1. Research question

Does the U.S. president issue more executive orders (EOs) under **divided government** than under **unified government**?

This operationalizes the popular and scholarly claim that presidents turn to unilateral action to "go around" a Congress they don't control (Howell, *Power Without Persuasion*, 2003; Mayer, *With the Stroke of a Pen*, 2001).

## 2. Hypothesis

- **H1 (primary):** The coefficient on `divided_government` in a regression predicting annual EO count is **positive and statistically distinguishable from zero** (α = 0.05).
- **H0 (null):** The coefficient is zero or negative.

I commit, in advance, to reporting H0-consistent results as a finding — not as a failed analysis. A clean "the raw-count data does not support the popular story" is a publishable result.

## 3. Data sources (provenance)

| Variable | Source | Access |
|---|---|---|
| Executive orders (count, signing date, president) | Federal Register API (`documents.json`) | No key; `R/01_pull_executive_orders.R` |
| Chamber party control | voteview.com member-ideology file (party counts per chamber per Congress) | CSV; `R/02_build_divided_government.R` |
| Presidential party | Hand-coded administrations table (14 rows, 1953–2025) | Inline in `R/02`; low transcription risk |

Every figure in the writeup must trace to one of these. No number enters the conclusion without a documented path.

## 4. Sample & unit of analysis

- **Unit:** president-year (one row per calendar year).
- **Window:** **1953–2025** (83rd–119th Congress, Eisenhower → present). Chosen for the modern unified/divided-government and polarization era, *fixed before seeing results.* Pre-1953 is out of scope for v1.
- **Outcome:** count of EOs by `signing_date` year.

## 5. Key independent variable

`divided_government` = 1 if the president's party does **not** control **both** chambers of Congress that year; 0 if it controls both (unified).

Secondary specification (also pre-registered): 3-level factor — `unified` / `split_congress` (party controls one chamber) / `opposition_congress` (party controls neither).

## 6. Model (pre-specified)

EO counts are non-negative integers and near-certainly over-dispersed, so:

- **Primary:** Negative binomial GLM —
  `eo_count ~ divided_government + first_year_of_term + year_centered`
  (`first_year_of_term` because presidents front-load EOs in inaugural years; `year_centered` = linear secular trend.)
- **Robustness 1:** Poisson GLM (same formula) — report if dispersion assumption was wrong.
- **Robustness 2:** OLS on `eo_count` — transparency check against the count models.
- **Robustness 3:** add president fixed effects — does the effect survive within-president variation, or is it just cross-president composition?

I will report **all four**. The primary spec governs the headline; divergence across specs is itself reported, not hidden.

## 7. What would falsify / weaken H1

- `divided_government` coefficient ≈ 0 or negative, or CI crossing zero, in the primary spec.
- Effect present in OLS but vanishing under negative binomial or president fixed effects (would suggest an artifact of a few high-EO administrations, not a divided-government effect).
- Effect driven entirely by one administration (checked via fixed effects + leave-one-president-out).

## 8. Known limitations (stated before results, not as post-hoc excuses)

1. **Counts ignore significance.** Raw EO volume undercounts consequential orders (Howell). This measures *volume of unilateral action*, not its weight. The headline claim is scoped accordingly.
2. **Publication lag.** OFR publishes EOs days after signing; year boundaries can misattribute a handful. Using `signing_date` (not publication date) minimizes this.
3. **Mid-Congress control flips.** E.g., the 2001 Senate flip (Jeffords). These are coded at the Congress level; the rare within-year flip is footnoted and tested in robustness, not silently averaged.

   *Measurement note (2026-06-30, before any results seen):* chamber control is **hand-verified** per Congress, not derived from a naive party-count, because a count of Democrats vs. Republicans mis-handles independents who caucus with a party and 50–50 Senates decided by the Vice President (e.g., the 117th Congress, 2021–22, which a naive count would wrongly label Republican-controlled). The voteview file is retained as an **independent cross-check** that flags every Congress where the verified table overrides the naive count. This corrects measurement validity; it does not alter the frozen hypothesis or model spec, and was made before observing any outcome.
4. **Inauguration-year attribution.** Jan 1–20 of transition years belongs to the outgoing president. Years are assigned to the incoming president (holds ~96% of the year); EOs are also attributable directly via the data's `president` field as a check.
5. **EOs are one channel.** Memoranda and proclamations are other unilateral tools, out of scope for v1.
6. **Small N (~73 years)** limits statistical power; wide CIs are expected and will be reported honestly.

## 9. Deliverables

- `data/executive_orders_raw.csv`, `data/divided_government.csv`, `data/analysis_panel.csv` (all reproducible from the scripts)
- `figures/eo_timeline.png` (EO count over time, colored by divided/unified)
- Model output tables for all four specs
- A short writeup stating the result against H1, honestly, with the limitations above intact.

*Anything not specified above that I decide during analysis will be labeled exploratory, not confirmatory.*
