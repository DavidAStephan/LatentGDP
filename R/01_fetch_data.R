suppressPackageStartupMessages({
  library(readabs)
  library(dplyr)
  library(tidyr)
})

# ABS Cat. 5206.0:
#   Table 24 = Selected Analytical Series (has GDP-E/I/P chain volume measures)
#   Table 1  = Key Aggregates (has Hours worked: Index for the 4th signal in m8)
raw_t24 <- read_abs("5206.0", tables = 24)
raw_t1  <- read_abs("5206.0", tables = 1)
raw <- raw_t24

eip_pattern <- paste0(
  "^Gross domestic product - (Expenditure|Income|Production)",
  " based: Chain volume measures ;$"
)

gdp_eip <- raw |>
  filter(
    series_type == "Seasonally Adjusted",
    grepl(eip_pattern, series)
  ) |>
  mutate(
    approach = case_when(
      grepl("Expenditure", series) ~ "E",
      grepl("Income",      series) ~ "I",
      grepl("Production",  series) ~ "P"
    )
  ) |>
  select(date, approach, value) |>
  arrange(date, approach)

# Quarterly log-difference, annualised (×400) — matches paper units.
gdp_growth <- gdp_eip |>
  group_by(approach) |>
  arrange(date, .by_group = TRUE) |>
  mutate(g = 400 * (log(value) - log(lag(value)))) |>
  ungroup() |>
  select(date, approach, g) |>
  pivot_wider(names_from = approach, values_from = g, names_prefix = "g_") |>
  drop_na()

stopifnot(all(c("g_E", "g_I", "g_P") %in% names(gdp_growth)))

hours <- raw_t1 |>
  filter(
    series_type == "Seasonally Adjusted",
    series == "Hours worked: Index ;"
  ) |>
  select(date, hours_idx = value) |>
  arrange(date)

stopifnot(nrow(hours) > 0)

hours_growth <- hours |>
  mutate(g_U = 400 * (log(hours_idx) - log(lag(hours_idx)))) |>
  select(date, g_U) |>
  filter(!is.na(g_U))

# Merge with gdp_growth on date; m8 requires all four series at every t.
gdp_growth_4 <- gdp_growth |>
  inner_join(hours_growth, by = "date")

saveRDS(gdp_eip,      file = "data/processed/gdp_eip_levels.rds")
saveRDS(gdp_growth,   file = "data/processed/gdp_growth.rds")
saveRDS(gdp_growth_4, file = "data/processed/gdp_growth_with_hours.rds")

# Monthly employment from ABS 6202.0 Table 1 (Labour Force Survey).
# Used by m11 (mixed-frequency Banbura-Modugno) as a monthly activity indicator.
lfs_files <- show_available_files("labour-force-australia")
lfs_url   <- lfs_files$url[lfs_files$file == "62020001.xlsx"]
stopifnot(length(lfs_url) == 1)
lfs_raw <- read_abs_url(lfs_url)

employment <- lfs_raw |>
  filter(
    series_type == "Seasonally Adjusted",
    series == "Employed total ;  Persons ;"
  ) |>
  select(date, employed = value) |>
  arrange(date)
stopifnot(nrow(employment) > 100)

# Month-on-month annualised growth: 1200 x dlog
emp_growth <- employment |>
  mutate(g_emp = 1200 * (log(employed) - log(lag(employed)))) |>
  filter(!is.na(g_emp)) |>
  select(date, g_emp)

saveRDS(employment, file = "data/processed/employment_monthly.rds")
saveRDS(emp_growth, file = "data/processed/employment_growth_monthly.rds")

cat(sprintf(
  "Saved %d quarters from %s to %s (T = %d after differencing).\n",
  nrow(gdp_eip) / 3, min(gdp_growth$date), max(gdp_growth$date), nrow(gdp_growth)
))
cat(sprintf(
  "Hours-worked series available for T = %d quarters (m8 uses this subset).\n",
  nrow(gdp_growth_4)
))
cat(sprintf(
  "Monthly employment growth: %d months from %s to %s (m11 uses this).\n",
  nrow(emp_growth), min(emp_growth$date), max(emp_growth$date)
))
