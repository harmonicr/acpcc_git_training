# Build the synthetic screening database used by the report.
#
#   Rscript data-raw/make-synthetic.R
#
# Every number this script produces is made up. The shape of the data
# (age gradients, metro vs regional differences, the COVID-19 dip, the rise
# of HPV self-collection) is plausible, but no value is real ACPCC data.
#
# Output: data/screening.duckdb with three tables
#   lga        one row per Victorian LGA, with its PHN and LPHU
#   indicator  one row per indicator shown in the report
#   screening  numerator/denominator by indicator, period, LGA, age and sex

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(DBI)
})

set.seed(20241231)

years <- 2016:2024
age_bands <- paste0(seq(25, 70, 5), "-", seq(29, 74, 5))
age_start <- function(age_group) as.integer(substr(age_group, 1, 2))

# --- Places -----------------------------------------------------------------

lga <- read_csv("data-raw/lga_lookup.csv", show_col_types = FALSE) |>
  mutate(
    # Synthetic resident population aged 25-74. Metro LGAs are larger.
    pop_25_74 = round(rlnorm(n(), if_else(metro, log(115000), log(17000)), 0.45)),
    # Annual growth: faster in the outer suburbs and metro areas.
    growth = if_else(metro, 1.016, 1.007),
    # A latent "engagement" effect shared by all programs in an LGA.
    lga_effect = rnorm(n(), 0, 0.22)
  )

# --- Population -------------------------------------------------------------

# Share of the 25-74 population in each age band. Regional areas are older.
age_share <- function(metro) {
  w <- if (metro) {
    c(13, 13, 12, 11, 10, 10, 9, 8, 7, 7)
  } else {
    c(8, 8, 8, 9, 9, 10, 11, 12, 13, 12)
  }
  w / sum(w)
}

population <- lga |>
  select(lga_code, metro, pop_25_74, growth) |>
  mutate(age_group = list(age_bands), share = map(metro, age_share)) |>
  unnest(c(age_group, share)) |>
  crossing(sex = c("Female", "Male"), year = years) |>
  mutate(
    population = rpois(n(), pop_25_74 * share * 0.5 * growth^(year - 2016))
  ) |>
  select(lga_code, age_group, sex, year, population)

# --- Indicators -------------------------------------------------------------

indicator <- read_csv("data-raw/indicators.csv", show_col_types = FALSE)

# Period labels for each indicator, keyed by the final year in the period.
periods_for <- function(period_type) {
  switch(period_type,
    year     = tibble(end_year = years, period = as.character(years)),
    two_year = tibble(end_year = 2017:2024, period = paste0(end_year - 1, "-", end_year)),
    five_year = tibble(end_year = 2020:2024, period = paste0(end_year - 4, "-", end_year))
  )
}

# Change on the logit scale for each year, relative to 2016.
# COVID-19 disrupted services in 2020-2021; `covid` sets how hard.
year_effect <- function(year, trend, covid) {
  trend * (year - 2016) + covid * (year %in% 2020:2021) + 0.4 * covid * (year == 2022)
}

# The age gradient for each program, on the logit scale.
age_effect <- function(program, age_group) {
  a <- age_start(age_group)
  switch(program,
    # Bowel: participation climbs steadily with age.
    bowel = 0.09 * (a - 60) / 5,
    # Breast: peaks in the 60s.
    breast = -0.02 * ((a - 65) / 5)^2,
    # Cervical: lowest in the youngest and oldest groups.
    cervical = -0.015 * ((a - 45) / 5)^2
  )
}

# Grid of every cell an indicator reports on, with its eligible population.
cells <- function(ind) {
  ages <- age_bands[age_start(age_bands) >= ind$age_min & age_start(age_bands) <= ind$age_max]
  sexes <- if (ind$sexes == "Female") "Female" else c("Female", "Male")

  periods_for(ind$period_type) |>
    crossing(lga_code = lga$lga_code, age_group = ages, sex = sexes) |>
    left_join(population, by = c("lga_code", "age_group", "sex", "end_year" = "year")) |>
    left_join(select(lga, lga_code, metro, lga_effect), by = "lga_code")
}

# Probability for each cell: indicator baseline + age + sex + place + time.
probability <- function(df, ind) {
  regional_shift <- switch(ind$program, bowel = 0.12, breast = -0.05, cervical = -0.10)
  plogis(
    qlogis(ind$base_rate) +
      age_effect(ind$program, df$age_group) +
      if_else(df$sex == "Male", ind$male_effect, 0) +
      df$lga_effect + if_else(df$metro, 0, regional_shift) +
      year_effect(df$end_year, ind$trend, ind$covid) +
      rnorm(nrow(df), 0, 0.05)
  )
}

# Rates and counts where the denominator is the eligible population.
simulate_population_based <- function(ind) {
  df <- cells(ind)
  df |>
    mutate(
      denominator = population,
      numerator = rbinom(n(), denominator, probability(df, ind))
    )
}

# Rates whose denominator is a subset of another indicator's numerator,
# e.g. people referred for colonoscopy after a positive bowel screening test.
simulate_follow_up <- function(ind, parent) {
  df <- parent |>
    select(period, end_year, lga_code, age_group, sex, parent_n = numerator) |>
    left_join(select(lga, lga_code, metro, lga_effect), by = "lga_code")
  df |>
    mutate(
      denominator = rbinom(n(), parent_n, ind$referral_rate),
      numerator = rbinom(n(), denominator, probability(df, ind))
    )
}

# HPV self-collection: a share of cervical tests. It began (in a limited way)
# with the renewed program in December 2017 and rose sharply after the
# July 2022 change that let anyone choose to self-collect.
simulate_self_collection <- function(ind, tests) {
  share <- c(`2018` = 0.004, `2019` = 0.006, `2020` = 0.008, `2021` = 0.012,
             `2022` = 0.07, `2023` = 0.19, `2024` = 0.33)
  tests |>
    filter(period %in% names(share)) |>
    select(period, end_year, lga_code, age_group, sex, numerator) |>
    left_join(select(lga, lga_code, lga_effect), by = "lga_code") |>
    mutate(
      denominator = numerator,
      p = plogis(qlogis(share[period]) + 0.6 * lga_effect),
      numerator = rbinom(n(), denominator, p)
    )
}

results <- list()
for (i in seq_len(nrow(indicator))) {
  ind <- indicator[i, ]
  results[[ind$indicator_id]] <- switch(ind$method,
    population  = simulate_population_based(ind),
    follow_up   = simulate_follow_up(ind, results[[ind$parent_id]]),
    self_collect = simulate_self_collection(ind, results[[ind$parent_id]])
  )
}

screening <- bind_rows(results, .id = "indicator_id") |>
  select(indicator_id, period, end_year, lga_code, age_group, sex, numerator, denominator) |>
  arrange(indicator_id, end_year, lga_code, age_group, sex)

# --- Write ------------------------------------------------------------------

dir.create("data", showWarnings = FALSE)
db_path <- "data/screening.duckdb"
unlink(c(db_path, paste0(db_path, ".wal")))

con <- dbConnect(duckdb::duckdb(db_path, shared_home = FALSE))
dbWriteTable(con, "lga", select(lga, lga_code, lga_name, phn, lphu, metro))
dbWriteTable(con, "indicator", indicator)
dbWriteTable(con, "screening", screening)
dbDisconnect(con, shutdown = TRUE)

message(sprintf(
  "Wrote %s: %d LGAs, %d indicators, %s rows",
  db_path, nrow(lga), nrow(indicator), format(nrow(screening), big.mark = ",")
))
