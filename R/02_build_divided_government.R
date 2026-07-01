#!/usr/bin/env Rscript
# 02_build_divided_government.R
# Builds a year-level divided-government indicator, 1953-2025.
#   - Chamber control: HAND-VERIFIED table (handles caucusing independents and
#     VP-tiebreak Senates, which a naive party-count gets wrong).
#   - voteview is downloaded only as an INDEPENDENT CROSS-CHECK (maker-checker):
#     the script prints any Congress where a naive vote count disagrees with the
#     verified table, so every override is visible and auditable.
# Output: data/divided_government.csv
#
# Run from project root:  Rscript R/02_build_divided_government.R

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr); library(tibble)
})

YEARS <- 1953:2025

# --- 1. HAND-VERIFIED chamber control, 83rd-119th Congress ------------------
# Majority party of each chamber. Cross-checked against voteview below.
# Notable overrides of a naive party-count:
#   107th: Senate flipped R->D mid-2001 (Jeffords); coded to its majority-of-Congress state.
#   117th: Senate 50-50, Democratic control via VP Harris tiebreak -> "D".
control <- tribble(
  ~congress, ~house_majority, ~senate_majority,
  83,"R","R", 84,"D","D", 85,"D","D", 86,"D","D", 87,"D","D", 88,"D","D",
  89,"D","D", 90,"D","D", 91,"D","D", 92,"D","D", 93,"D","D", 94,"D","D",
  95,"D","D", 96,"D","D",
  97,"D","R", 98,"D","R", 99,"D","R",
  100,"D","D", 101,"D","D", 102,"D","D", 103,"D","D",
  104,"R","R", 105,"R","R", 106,"R","R",
  107,"R","D",                 # Jeffords switch (see note above)
  108,"R","R", 109,"R","R",
  110,"D","D", 111,"D","D",
  112,"R","D", 113,"R","D",
  114,"R","R", 115,"R","R",
  116,"D","R",
  117,"D","D",                 # 50-50 Senate, Democratic via VP tiebreak
  118,"R","D",
  119,"R","R"
)

# --- 2. Presidential party (incoming president holds ~96% of a transition year) ---
admin <- tribble(
  ~president,  ~pres_party, ~start_year, ~end_year,
  "eisenhower","R",1953,1960, "kennedy","D",1961,1963, "johnson","D",1964,1968,
  "nixon","R",1969,1973, "ford","R",1974,1976, "carter","D",1977,1980,
  "reagan","R",1981,1988, "bush_hw","R",1989,1992, "clinton","D",1993,2000,
  "bush_w","R",2001,2008, "obama","D",2009,2016, "trump_1","R",2017,2020,
  "biden","D",2021,2024, "trump_2","R",2025,2025
)
pres_by_year <- admin |> rowwise() |>
  mutate(year = list(seq(start_year, end_year))) |> unnest(year) |>
  select(year, president, pres_party)

# --- 3. Build the year-level panel ------------------------------------------
panel <- tibble(year = YEARS) |>
  mutate(congress = floor((year - 1789) / 2) + 1) |>
  left_join(pres_by_year, by = "year") |>
  left_join(control,      by = "congress") |>
  mutate(
    house_match  = pres_party == house_majority,
    senate_match = pres_party == senate_majority,
    divided      = as.integer(!(house_match & senate_match)),
    control = case_when(house_match & senate_match     ~ "unified",
                        xor(house_match, senate_match) ~ "split_congress",
                        TRUE                           ~ "opposition_congress")
  )

# --- 4. CROSS-CHECK against voteview (maker-checker) -------------------------
VV_URL <- "https://voteview.com/static/data/out/members/HSall_members.csv"
ok <- tryCatch({
  mem <- read_csv(VV_URL, show_col_types = FALSE)
  naive <- mem |>
    filter(chamber %in% c("House","Senate"), congress >= 83) |>
    mutate(party = case_when(party_code==100~"D", party_code==200~"R", TRUE~"Other")) |>
    count(congress, chamber, party) |>
    group_by(congress, chamber) |> slice_max(n, n=1, with_ties=FALSE) |> ungroup() |>
    select(congress, chamber, naive = party) |>
    pivot_wider(names_from = chamber, values_from = naive,
                names_prefix = "naive_")
  chk <- control |> left_join(naive, by = "congress") |>
    mutate(house_disagree  = house_majority  != naive_House,
           senate_disagree = senate_majority != naive_Senate)
  disagree <- filter(chk, house_disagree | senate_disagree)
  if (nrow(disagree) == 0) {
    message("Cross-check: verified table agrees with naive voteview count everywhere.")
  } else {
    message("Cross-check: verified table OVERRIDES naive voteview count in these Congresses ",
            "(expected, due to caucusing independents / VP tiebreak / mid-session flip):")
    print(select(disagree, congress, house_majority, naive_House,
                 senate_majority, naive_Senate))
  }
  TRUE
}, error = function(e) { message("Cross-check skipped (voteview unreachable): ", conditionMessage(e)); FALSE })

dir.create("data", showWarnings = FALSE)
write_csv(panel, "data/divided_government.csv")
message(sprintf("Done. %d year-rows -> data/divided_government.csv", nrow(panel)))
print(count(panel, control))
