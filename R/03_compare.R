suppressPackageStartupMessages({
  library(cmdstanr)
  library(posterior)
  library(loo)
  library(dplyr)
  library(tidyr)
})

# Three LOO groups due to different samples:
#   G1: T=265 (1960-2025), 3-measure log_lik       -> m1,m2,m3,m4,m5,m6,m7,m9
#   G2: T=189 (1979-2025), 4-measure log_lik       -> m8, m10
#   G3: mixed-frequency,  monthly+quarterly        -> m11 (reported separately)

names_g1 <- c("m1", "m2", "m3", "m4", "m5", "m6", "m7", "m9")
names_g2 <- c("m8", "m10")
names_all <- c(names_g1, names_g2, "m11")

fits <- lapply(names_all, function(nm) readRDS(sprintf("output/fit_%s.rds", nm)))
names(fits) <- names_all

loo_one <- function(f, var = "log_lik") {
  ll <- f$draws(var, format = "draws_matrix")
  loo(as.matrix(ll), r_eff = relative_eff(exp(as.matrix(ll)),
      chain_id = rep(1:4, each = nrow(ll) / 4)))
}

cat("\n=== LOO group 1: 3-measure specs (T = 265) ===\n")
loos_g1 <- lapply(fits[names_g1], loo_one)
print(loo_compare(loos_g1), simplify = FALSE)

cat("\n=== LOO group 2: 4-measure specs (T = 189) ===\n")
loos_g2 <- lapply(fits[names_g2], loo_one)
print(loo_compare(loos_g2), simplify = FALSE)

cat("\n=== m11 (mixed-frequency) LOO - reported standalone ===\n")
loo_m11_q <- loo_one(fits$m11, var = "log_lik_q")
loo_m11_m <- loo_one(fits$m11, var = "log_lik_m")
cat("Quarterly LOO: elpd =", round(loo_m11_q$estimates["elpd_loo", "Estimate"], 1),
    "p =",   round(loo_m11_q$estimates["p_loo",    "Estimate"], 1), "\n")
cat("Monthly   LOO: elpd =", round(loo_m11_m$estimates["elpd_loo", "Estimate"], 1),
    "p =",   round(loo_m11_m$estimates["p_loo",    "Estimate"], 1), "\n")

# ---- Variance decomposition --------------------------------------------
gdp_growth   <- readRDS("data/processed/gdp_growth.rds")
gdp_growth_4 <- readRDS("data/processed/gdp_growth_with_hours.rds")
headline_full <- rowMeans(gdp_growth[,   c("g_E", "g_I", "g_P")])
headline_sub  <- rowMeans(gdp_growth_4[, c("g_E", "g_I", "g_P")])

variance_table <- tibble(
  series = c("Headline (full)", "GDP(E) full", "GDP(I) full", "GDP(P) full"),
  sample = "T=265 (1960-2025)",
  var    = c(var(headline_full), var(gdp_growth$g_E),
             var(gdp_growth$g_I), var(gdp_growth$g_P))
)
for (nm in names_g1) {
  mu_post <- colMeans(fits[[nm]]$draws("mu", format = "draws_matrix"))
  variance_table <- bind_rows(variance_table,
    tibble(series = paste0("Latent mu (", nm, ")"),
           sample = "T=265 (1960-2025)", var = var(mu_post)))
}
variance_table <- bind_rows(variance_table,
  tibble(series = "Headline (4-signal subsample)", sample = "T=189 (1979-2025)",
         var = var(headline_sub)))
for (nm in names_g2) {
  mu_post <- colMeans(fits[[nm]]$draws("mu", format = "draws_matrix"))
  variance_table <- bind_rows(variance_table,
    tibble(series = paste0("Latent mu (", nm, ")"),
           sample = "T=189 (1979-2025)", var = var(mu_post)))
}
# m11 has quarterly-aggregated latent
mu_q_post <- colMeans(fits$m11$draws("mu_q", format = "draws_matrix"))
variance_table <- bind_rows(variance_table,
  tibble(series = "Latent mu_q (m11, mixed-freq)",
         sample = "T_q~190 (1978-2025)", var = var(mu_q_post)))

headline_var <- c(`T=265 (1960-2025)` = var(headline_full),
                  `T=189 (1979-2025)` = var(headline_sub),
                  `T_q~190 (1978-2025)` = var(headline_sub))
variance_table <- variance_table |>
  mutate(sd = sqrt(var), ratio_vs_headline = var / headline_var[sample])

cat("\n=== Variance of growth series (annualised %, by sample) ===\n")
print(variance_table, n = Inf)
write.csv(variance_table, "output/tables/variance_decomposition.csv", row.names = FALSE)
saveRDS(loos_g1, "output/loos_g1.rds")
saveRDS(loos_g2, "output/loos_g2.rds")
