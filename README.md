# Executive Orders & Divided Government

A small, reproducible test of one falsifiable claim: **do presidents issue more executive orders when they don't control Congress?**

The deliverable is the reproducibility. Every number traces to a public source; the hypothesis and model were frozen *before* the data was pulled (see `PRE_REGISTRATION.md`).

## What it does

1. `R/01_pull_executive_orders.R` — pulls all EOs 1953–2025 from the Federal Register API (no key).
2. `R/02_build_divided_government.R` — derives chamber control from voteview DW-NOMINATE member data; codes a year-level divided-government indicator.
3. `R/03_analysis.R` — joins the panel, fits the four pre-registered models (negative binomial primary + 3 robustness), writes the figure and tables.

## Run

```bash
# from the project root
Rscript R/01_pull_executive_orders.R
Rscript R/02_build_divided_government.R
Rscript R/03_analysis.R
```

Dependencies: `httr`, `jsonlite`, `dplyr`, `tidyr`, `readr`, `stringr`, `ggplot2`, `MASS`, `broom`.

```r
install.packages(c("httr","jsonlite","dplyr","tidyr","readr",
                   "stringr","ggplot2","MASS","broom"))
```

## Data sources

- **Executive orders:** Federal Register API — federalregister.gov/developers/documentation/api/v1
- **Chamber control:** voteview.com member file (`HSall_members.csv`)
- **Presidential party:** hand-coded administrations table in `R/02` (14 rows)

## The discipline (why this is a portfolio piece, not just a chart)

- Pre-registered: `PRE_REGISTRATION.md` was written with no data in hand.
- Limitations stated up front, not as post-hoc excuses (EO counts ignore significance; publication lag; mid-Congress control flips).
- Result reported honestly against the hypothesis, including a clean null.

See `../PROJECT_BACKLOG.md` for where this sits in the wider portfolio.
