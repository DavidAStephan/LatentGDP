# Writes machine-readable outputs from the production fit:
#   docs/estimates.csv             - full mu_t time series with 90% CI
#   docs/estimates_latest.json     - latest quarter headline numbers
#   docs/diagnostics.json          - run metadata (date, sampler diagnostics)
# These are the stable contract for downstream consumers of the estimate.

suppressPackageStartupMessages({
  library(cmdstanr)
  library(posterior)
  library(dplyr)
  library(jsonlite)
})

fit        <- readRDS("output/fit_production.rds")
gdp_growth <- readRDS("data/processed/gdp_growth.rds")

mu_draws <- fit$draws("mu", format = "draws_matrix")

estimates <- tibble(
  date          = gdp_growth$date,
  g_E           = gdp_growth$g_E,
  g_I           = gdp_growth$g_I,
  g_P           = gdp_growth$g_P,
  headline_mean = (gdp_growth$g_E + gdp_growth$g_I + gdp_growth$g_P) / 3,
  mu_median     = apply(mu_draws, 2, median),
  mu_q05        = apply(mu_draws, 2, quantile, 0.05),
  mu_q95        = apply(mu_draws, 2, quantile, 0.95),
  mu_q25        = apply(mu_draws, 2, quantile, 0.25),
  mu_q75        = apply(mu_draws, 2, quantile, 0.75)
)

dir.create("docs", showWarnings = FALSE, recursive = TRUE)
write.csv(estimates, "docs/estimates.csv", row.names = FALSE)

# Latest-quarter headline JSON (the thing the site shows up top).
latest <- tail(estimates, 1)
headline_var <- var(estimates$headline_mean)
mu_var       <- var(estimates$mu_median)

latest_json <- list(
  quarter           = format(as.Date(latest$date), "%Y Q%q"),
  date              = as.character(latest$date),
  mu_median         = round(latest$mu_median, 2),
  mu_q05            = round(latest$mu_q05, 2),
  mu_q95            = round(latest$mu_q95, 2),
  headline_mean     = round(latest$headline_mean, 2),
  observed = list(
    g_E = round(latest$g_E, 2),
    g_I = round(latest$g_I, 2),
    g_P = round(latest$g_P, 2)
  ),
  variance_ratio_vs_headline = round(mu_var / headline_var, 3),
  units = "annualised quarterly growth, % (400 x dlog of chain volume measures)",
  model = "m9: structural Sigma (Cov(eps_P, .) = 0) + stochastic volatility",
  data_source = "ABS 5206.0 Table 24, seasonally adjusted, chain volume measures"
)
# format(.., "%Y Q%q") returns "%q" literally on some platforms; build by hand.
m <- as.integer(format(as.Date(latest$date), "%m"))
y <- as.integer(format(as.Date(latest$date), "%Y"))
latest_json$quarter <- sprintf("%d Q%d", y, ((m - 1) %/% 3) + 1)

write_json(latest_json, "docs/estimates_latest.json",
           pretty = TRUE, auto_unbox = TRUE, digits = 4)

# Diagnostics JSON for the badge / status banner.
diag <- fit$diagnostic_summary()
diag_json <- list(
  run_time_utc      = format(Sys.time(), tz = "UTC"),
  cmdstan_version   = cmdstan_version(),
  T                 = nrow(gdp_growth),
  sample_start      = as.character(min(estimates$date)),
  sample_end        = as.character(max(estimates$date)),
  num_divergent     = sum(diag$num_divergent),
  num_max_treedepth = sum(diag$num_max_treedepth),
  ebfmi_min         = round(min(diag$ebfmi), 3),
  chains            = length(diag$ebfmi),
  iter_per_chain    = 2000
)
write_json(diag_json, "docs/diagnostics.json",
           pretty = TRUE, auto_unbox = TRUE, digits = 4)

cat(sprintf(
  "\nLatest estimate: %s mu = %.2f%% [%.2f, %.2f] (90%% CI)\n",
  latest_json$quarter, latest_json$mu_median,
  latest_json$mu_q05, latest_json$mu_q95
))
cat(sprintf("Headline (mean of E,I,P): %.2f%%\n", latest_json$headline_mean))
cat(sprintf("Variance ratio (mu vs headline): %.3f\n",
            latest_json$variance_ratio_vs_headline))
