suppressPackageStartupMessages({
  library(cmdstanr)
  library(posterior)
  library(dplyr)
})

gdp_growth   <- readRDS("data/processed/gdp_growth.rds")
gdp_growth_4 <- readRDS("data/processed/gdp_growth_with_hours.rds")

# Standard 3-measure data block (m1-m7)
stan_data <- list(
  T = nrow(gdp_growth),
  K = 3,
  y = as.matrix(gdp_growth[, c("g_E", "g_I", "g_P")])
)

# m7 needs the COVID quarter indices.
covid_dates <- as.Date(c("2020-06-01", "2020-09-01", "2020-12-01", "2021-03-01"))
covid_idx <- which(gdp_growth$date %in% covid_dates)
stopifnot(length(covid_idx) == length(covid_dates))
stan_data_m7 <- c(stan_data, list(n_covid = length(covid_idx), covid_idx = covid_idx))

# m8 uses the 4-measure subsample (~189 quarters, post-1979).
stan_data_m8 <- list(
  T = nrow(gdp_growth_4),
  y_gdp = as.matrix(gdp_growth_4[, c("g_E", "g_I", "g_P")]),
  y_U   = gdp_growth_4$g_U
)

specs <- list(
  m1 = list(file = "stan/m1_baseline.stan",         data = stan_data,    extras = list(),
            params = c("mu_bar", "tau", "sigma")),
  m2 = list(file = "stan/m2_ar1.stan",              data = stan_data,    extras = list(),
            params = c("mu_bar", "c", "rho", "tau", "sigma")),
  m3 = list(file = "stan/m3_corr.stan",             data = stan_data,    extras = list(adapt_delta = 0.99),
            params = c("mu_bar", "rho", "tau", "sigma", "Omega")),
  m4 = list(file = "stan/m4_sv.stan",               data = stan_data,    extras = list(adapt_delta = 0.99, max_treedepth = 12),
            params = c("mu_bar", "rho", "tau", "mu_h", "phi", "omega")),
  m5 = list(file = "stan/m5_serial.stan",           data = stan_data,    extras = list(adapt_delta = 0.99),
            params = c("mu_bar", "rho", "tau", "sigma", "psi", "eps_sd")),
  m6 = list(file = "stan/m6_structural_corr.stan",  data = stan_data,    extras = list(adapt_delta = 0.99),
            params = c("mu_bar", "rho", "tau", "sigma", "rho_EI")),
  m7 = list(file = "stan/m7_covid_scale.stan",      data = stan_data_m7, extras = list(adapt_delta = 0.99),
            params = c("mu_bar", "rho", "tau", "sigma", "kappa")),
  m8 = list(file = "stan/m8_labour.stan",           data = stan_data_m8, extras = list(adapt_delta = 0.99),
            params = c("mu_bar", "rho", "tau", "sigma_gdp", "sigma_U", "alpha", "beta"))
)

fit_one <- function(name, spec) {
  cat("\n===== ", name, " =====\n", sep = "")
  mod <- cmdstan_model(spec$file)
  args <- c(
    list(data = spec$data, chains = 4, parallel_chains = 4,
         iter_warmup = 2000, iter_sampling = 2000, seed = 1, refresh = 1000),
    spec$extras
  )
  fit <- do.call(mod$sample, args)
  fit$save_object(file = sprintf("output/fit_%s.rds", name))
  print(fit$summary(variables = spec$params))
  print(fit$diagnostic_summary())
  invisible(fit)
}

for (nm in names(specs)) fit_one(nm, specs[[nm]])
