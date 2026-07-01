#!/usr/bin/env Rscript
# 01_pull_executive_orders.R  -- COMPLETE HYBRID PULL, 1953-2025
#
# Why hybrid: the Federal Register documents.json search API only has complete
# EO coverage from 1994 forward (it returns 0 EOs for every year before 1993),
# so it silently drops Eisenhower..G.H.W. Bush - the original bug that faked the
# divided-government result. There is NO single "All EOs since 1937" bulk JSON on
# the FR site (its EO page is a JS app that exposes only the same incomplete
# documents API). The COMPLETE record for pre-1994 lives in the FR per-president
# /year disposition tables (HTML), where each EO is an <h5> heading linking
# /executive-order/NNNNN with a "Signed:" date. So:
#   * 1953-1993  -> scrape the disposition tables (authoritative for older EOs)
#   * 1994-2025  -> documents.json (complete for this range)
# then dedupe by EO number and VALIDATE per-president totals before proceeding.
# Absence of data must never pass as a result.
#
# Output: data/executive_orders_raw.csv
# Run from project root:  Rscript R/01_pull_executive_orders.R

suppressPackageStartupMessages({
  library(httr); library(jsonlite); library(dplyr); library(readr)
  library(stringr); library(tibble); library(tidyr)
})

UA <- user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) eo-divided-government research script")

# ---------------------------------------------------------------------------
# A. PRE-1994: scrape FR disposition tables (h5 /executive-order/ format)
# ---------------------------------------------------------------------------
# president URL slug -> calendar years to fetch (all <= 1993). Transition years
# appear under both the outgoing and incoming president; each EO lives only on
# its own signer's page and we dedupe by EO number, so overlap is safe. Truman
# 1953 is included so EOs signed Jan 1-20, 1953 are not lost from the 1953
# calendar-year count. Slugs verified against the live site.
DISP <- list(
  "harry-s-truman"      = 1953,         # Jan 1-20, 1953 only (rest of Truman is out of window)
  "dwight-d-eisenhower" = 1953:1961,
  "john-f-kennedy"      = 1961:1963,
  "lyndon-b-johnson"    = 1963:1969,
  "richard-nixon"       = 1969:1974,
  "gerald-ford"         = 1974:1977,
  "jimmy-carter"        = 1977:1981,
  "ronald-reagan"       = 1981:1989,
  "george-h-w-bush"     = 1989:1993,
  "william-j-clinton"   = 1993          # 1994+ comes from the API below
)

# Field detection / entry parsing for the disposition pages. Each EO entry is an
# <h5> heading linking /executive-order/NNNNN, followed by its own metadata block
# with "Signed:" and "Published:" dates. We slice the page into per-entry chunks
# at the h5 headings so each EO's date is scoped to its own entry and the inline
# cross-reference links (amends/revokes other EOs) are NOT miscounted.
parse_disposition <- function(h) {
  hits <- str_locate_all(h, "<h5>\\s*<a href=\"/executive-order/[0-9]+\"")[[1]]
  if (nrow(hits) == 0)
    return(tibble(eo_number = character(), title = character(),
                  signing_date = as.Date(character())))
  starts <- hits[, 1]; ends <- c(starts[-1] - 1, nchar(h))
  bind_rows(lapply(seq_along(starts), function(i) {
    ch <- str_sub(h, starts[i], ends[i])
    tibble(
      eo_number    = str_match(ch, "/executive-order/([0-9]+)")[, 2],
      title        = str_match(ch, "/executive-order/[0-9]+\">\\s*([^<]*?)\\s*</a>")[, 2],
      signing_date = as.Date(
        str_match(ch, "<dt>\\s*Signed:\\s*</dt>\\s*<dd>\\s*([A-Z][a-z]+ [0-9]{1,2}, [0-9]{4})")[, 2],
        format = "%B %d, %Y")
    )
  }))
}

scrape_year <- function(slug, yr) {
  u <- sprintf("https://www.federalregister.gov/presidential-documents/executive-orders/%s/%d", slug, yr)
  r <- GET(u, UA)
  if (status_code(r) != 200) { warning(sprintf("disposition %s/%d: HTTP %d", slug, yr, status_code(r))); return(NULL) }
  df <- parse_disposition(content(r, as = "text", encoding = "UTF-8"))
  if (nrow(df)) df$president <- slug
  df
}

message("Scraping FR disposition tables for 1953-1993 ...")
pre94 <- bind_rows(lapply(names(DISP), function(slug) {
  bind_rows(lapply(DISP[[slug]], function(yr) {
    df <- scrape_year(slug, yr)
    message(sprintf("  %-22s %d: %s EOs", slug, yr, if (is.null(df)) 0 else nrow(df)))
    Sys.sleep(0.25)  # be polite
    df
  }))
}))

# ---------------------------------------------------------------------------
# B. 1994-2025: documents.json (complete for this range)
# ---------------------------------------------------------------------------
BASE_URL <- "https://www.federalregister.gov/api/v1/documents.json"
FIELDS   <- c("executive_order_number", "president", "signing_date",
              "title", "document_number", "citation")
api_year <- function(yr) {
  params <- c(
    "conditions%5Btype%5D%5B%5D=PRESDOCU",
    "conditions%5Bpresidential_document_type%5D=executive_order",
    sprintf("conditions%%5Bsigning_date%%5D%%5Bgte%%5D=01/01/%d", yr),
    sprintf("conditions%%5Bsigning_date%%5D%%5Blte%%5D=12/31/%d", yr),
    "per_page=1000", paste0("fields%5B%5D=", FIELDS))
  resp <- GET(paste0(BASE_URL, "?", paste(params, collapse = "&")))
  if (http_error(resp)) { warning(sprintf("API %d: HTTP %d", yr, status_code(resp))); return(NULL) }
  dat <- fromJSON(content(resp, as = "text", encoding = "UTF-8"), flatten = TRUE)
  if (is.null(dat$results) || length(dat$results) == 0) return(NULL)
  if (!is.null(dat$total_pages) && dat$total_pages > 1)
    warning(sprintf("API year %d has >1 page (%d) - widen paging", yr, dat$total_pages))
  res <- as_tibble(dat$results)
  pcol <- intersect(c("president.identifier", "president"), names(res))[1]
  tibble(
    eo_number    = as.character(res$executive_order_number),
    title        = if ("title" %in% names(res)) as.character(res$title) else NA_character_,
    signing_date = as.Date(res$signing_date),
    president    = if (!is.na(pcol)) as.character(res[[pcol]]) else NA_character_
  )
}

message("Pulling 1994-2025 from documents.json ...")
post94 <- bind_rows(lapply(1994:2025, function(yr) {
  message("  api ", yr); Sys.sleep(0.2); api_year(yr)
}))

# ---------------------------------------------------------------------------
# C. Combine, dedupe, restrict to window
# ---------------------------------------------------------------------------
eos <- bind_rows(pre94, post94) |>
  filter(!is.na(signing_date)) |>
  mutate(signing_year = as.integer(format(signing_date, "%Y"))) |>
  filter(signing_year >= 1953, signing_year <= 2025) |>
  distinct(eo_number, .keep_all = TRUE) |>
  arrange(signing_date)

# ---------------------------------------------------------------------------
# D. COMPLETENESS VALIDATION (maker-checker on the data itself)
# ---------------------------------------------------------------------------
# Published totals for the 10 single-occupant administrations fully inside the
# window. If the pull is complete these match within tolerance; the old broken
# pull had most of these near zero. Bush (x2) and Trump (x2) are name-ambiguous,
# so they're excluded from the per-president check but covered by the total floor.
expected <- tribble(
  ~key,        ~exp_n,
  "eisenhower", 484, "kennedy", 214, "johnson", 325, "nixon", 346,
  "ford", 169, "carter", 320, "reagan", 381, "clinton", 364,
  "obama", 276, "biden", 162
)
pres_l <- str_to_lower(eos$president)
obs <- expected |>
  rowwise() |>
  mutate(obs_n = sum(str_detect(pres_l, key))) |>
  ungroup() |>
  mutate(diff = obs_n - exp_n)

message("\n--- Completeness check (published vs pulled, per president) ---")
print(as.data.frame(obs))
message(sprintf("Total EOs pulled (1953-2025): %d", nrow(eos)))

TOL <- 12          # allows minor source/edition differences, not a 60% shortfall
total_floor <- 3400
bad <- filter(obs, abs(diff) > TOL)
if (nrow(bad) > 0 || nrow(eos) < total_floor)
  stop("INCOMPLETE DATA: ", nrow(eos), " EOs pulled (expect ~3,800 for 1953-2025). ",
       if (nrow(bad)) paste0(nrow(bad), " president(s) off by >", TOL, " (see table above). "),
       "Do NOT proceed - investigate the source before any analysis.")

# ---------------------------------------------------------------------------
# E. Write
# ---------------------------------------------------------------------------
dir.create("data", showWarnings = FALSE)
out <- eos |> transmute(signing_year, signing_date, eo_number, president, title)
write_csv(out, "data/executive_orders_raw.csv")
message(sprintf("\nDone. %d executive orders (1953-2025) -> data/executive_orders_raw.csv", nrow(out)))
