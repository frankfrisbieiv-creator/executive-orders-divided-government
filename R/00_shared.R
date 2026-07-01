#!/usr/bin/env Rscript
# 00_shared.R
# Single source of truth for the PRE-REGISTERED model spec and the figure.
# Sourced by both 03_analysis.R (CLI) and report.qmd (website) so the spec
# can never silently drift between the two.

suppressPackageStartupMessages({ library(dplyr); library(MASS); library(ggplot2) })

# The frozen formula (see PRE_REGISTRATION.md section 6).
EO_FORMULA <- eo_count ~ divided_government + first_year_of_term + year_centered

INAUG_YEARS <- c(1953,1961,1965,1969,1974,1977,1981,1989,1993,2001,2009,2017,2021,2025)

# Build the analysis panel from the two raw inputs. Single source of truth so
# the CLI script and the website can't construct different panels.
build_panel <- function(eos, divided) {
  eo_counts <- eos |> count(signing_year, name = "eo_count") |>
    rename(year = signing_year)
  divided |>
    left_join(eo_counts, by = "year") |>
    mutate(eo_count           = ifelse(is.na(eo_count), 0L, eo_count),
           first_year_of_term = as.integer(year %in% INAUG_YEARS),
           year_centered      = year - mean(year),
           divided_government = divided)
}

# Returns the pre-registered models as a named list. The president fixed-effects
# spec is wrapped: if it fails to converge on this small sample, that is reported
# as a dropped spec, not a crash that kills the whole report.
fit_models <- function(panel) {
  m <- list(
    `Negative binomial (primary)` = glm.nb(EO_FORMULA, data = panel),
    `Poisson`                     = glm(EO_FORMULA, data = panel, family = poisson),
    `OLS`                         = lm(EO_FORMULA, data = panel)
  )
  fe <- tryCatch(
    glm.nb(update(EO_FORMULA, . ~ . + factor(president)), data = panel),
    error = function(e) { warning("FE model did not converge: ", conditionMessage(e)); NULL }
  )
  if (!is.null(fe)) m[["NB + president fixed effects"]] <- fe
  m
}

make_timeline_plot <- function(panel) {
  ggplot(panel, aes(year, eo_count, fill = control)) +
    geom_col() +
    scale_fill_manual(values = c(unified = "#2c7fb8",
                                 split_congress = "#7fcdbb",
                                 opposition_congress = "#d95f0e")) +
    labs(title = "Executive orders per year, 1953-2025",
         subtitle = "Colored by party control of government",
         x = NULL, y = "Executive orders signed", fill = NULL) +
    theme_minimal(base_size = 12)
}
