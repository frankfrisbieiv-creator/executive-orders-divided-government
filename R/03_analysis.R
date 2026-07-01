#!/usr/bin/env Rscript
# 03_analysis.R  (CLI path; report.qmd renders the same spec for the website)
# Model + panel spec live in R/00_shared.R - DO NOT redefine here.
# Run from project root:  Rscript R/03_analysis.R

suppressPackageStartupMessages({ library(dplyr); library(readr); library(broom); library(ggplot2) })
source("R/00_shared.R")

# Coefficient table with confidence intervals. Uses profile-likelihood CIs
# (broom's default) where they can be computed; falls back to Wald CIs only when
# profiling fails. The president fixed-effects spec suffers complete separation
# on this small sample (several president dummies are perfectly determined by a
# unique run of years), so its profile CI cannot be computed - without this
# fallback that one spec aborts the whole run. The three other specs are
# unaffected and keep their exact profile-likelihood intervals.
tidy_ci <- function(m) {
  tryCatch(
    tidy(m, conf.int = TRUE),
    error = function(e) {
      message("  (profile CI unavailable for this spec; using Wald CI - ",
              conditionMessage(e), ")")
      z <- qnorm(0.975)
      tidy(m) |> mutate(conf.low  = estimate - z * std.error,
                        conf.high = estimate + z * std.error)
    }
  )
}

eos     <- read_csv("data/executive_orders_raw.csv", show_col_types = FALSE)
divided <- read_csv("data/divided_government.csv",   show_col_types = FALSE)
panel   <- build_panel(eos, divided)
write_csv(panel, "data/analysis_panel.csv")

cat("\n--- Mean EO count by control type ---\n")
print(panel |> group_by(control) |> summarise(n_years = n(), mean_eo = round(mean(eo_count), 1)))

models <- fit_models(panel)
for (nm in names(models)) {
  cat("\n===", nm, "===\n")
  print(tidy_ci(models[[nm]]) |> mutate(across(where(is.numeric), \(x) round(x, 4))))
}
cat("\nInterpret against H1 in PRE_REGISTRATION.md. Report all four specs.\n")

dir.create("figures", showWarnings = FALSE)
ggsave("figures/eo_timeline.png", make_timeline_plot(panel), width = 10, height = 5, dpi = 150)
cat("Wrote figures/eo_timeline.png\n")
