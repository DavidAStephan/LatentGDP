# Production fit: m9 only (structural Sigma + SV).
# Runs in CI quarterly after each ABS 5206.0 release.
# Fits the single LOO-best model and saves draws for downstream use.

suppressPackageStartupMessages({
  library(cmdstanr)
  library(posterior)
})

dir.create("output", showWarnings = FALSE, recursive = TRUE)

gdp_growth <- readRDS("data/processed/gdp_growth.rds")

stan_data <- list(
  T = nrow(gdp_growth),
  K = 3,
  y = as.matrix(gdp_growth[, c("g_E", "g_I", "g_P")])
)

mod <- cmdstan_model("stan/m9_struct_sv.stan")
fit <- mod$sample(
  data = stan_data,
  chains = 4,
  parallel_chains = 4,
  iter_warmup = 2000,
  iter_sampling = 2000,
  seed = 1,
  refresh = 500,
  adapt_delta = 0.99,
  max_treedepth = 12
)

# Persist for the estimate writer; not committed (see .gitignore).
fit$save_object(file = "output/fit_production.rds")

cat("\n=== m9 production fit ===\n")
print(fit$summary(variables = c("mu_bar", "rho", "tau", "rho_EI")))
diag <- fit$diagnostic_summary()
print(diag)

# Hard-fail CI on divergences > 1% so a broken fit doesn't get published.
total_divs <- sum(diag$num_divergent)
total_draws <- 4 * 2000
if (total_divs / total_draws > 0.01) {
  stop(sprintf(
    "Fit quality gate failed: %d divergences (%.2f%%) exceeds 1%% threshold.",
    total_divs, 100 * total_divs / total_draws
  ))
}
cat(sprintf("\nFit quality gate passed: %d divergences (%.2f%%).\n",
            total_divs, 100 * total_divs / total_draws))
