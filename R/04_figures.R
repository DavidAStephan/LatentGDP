suppressPackageStartupMessages({
  library(cmdstanr)
  library(posterior)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

theme_set(theme_minimal(base_size = 11))

gdp_growth   <- readRDS("data/processed/gdp_growth.rds") |>
  mutate(headline = (g_E + g_I + g_P) / 3)
gdp_growth_4 <- readRDS("data/processed/gdp_growth_with_hours.rds") |>
  mutate(headline = (g_E + g_I + g_P) / 3)

names_full <- c("m1", "m2", "m3", "m4", "m5", "m6", "m7", "m9")
labels_m <- c(
  m1 = "m1: baseline", m2 = "m2: AR(1) latent",
  m3 = "m3: free corr errors", m4 = "m4: SV",
  m5 = "m5: serial errors", m6 = "m6: structural Sigma",
  m7 = "m7: COVID scale", m8 = "m8: 4-signal (+hours)",
  m9 = "m9: structural Sigma + SV", m10 = "m10: 4-signal + SV",
  m11 = "m11: mixed-frequency"
)

mu_summary <- function(fit, nm, dates) {
  d <- fit$draws("mu", format = "draws_matrix")
  tibble(
    date = dates, model = labels_m[nm],
    mean = colMeans(d),
    lo = apply(d, 2, quantile, 0.05),
    hi = apply(d, 2, quantile, 0.95)
  )
}

mu_full <- bind_rows(lapply(names_full, function(nm) {
  mu_summary(readRDS(sprintf("output/fit_%s.rds", nm)), nm, gdp_growth$date)
}))

p1 <- ggplot(mu_full, aes(x = date)) +
  geom_hline(yintercept = 0, colour = "grey80") +
  geom_line(data = gdp_growth, aes(y = headline),
            colour = "grey50", alpha = 0.6) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.25, fill = "steelblue") +
  geom_line(aes(y = mean), colour = "steelblue", linewidth = 0.4) +
  facet_wrap(~ model, ncol = 1) +
  labs(
    title = "Latent GDP growth (blue, 90% CI) vs headline (grey)",
    subtitle = "Annualised quarterly growth, %. Headline = mean of GDP(E,I,P).",
    x = NULL, y = NULL
  )
ggsave("output/figures/01_latent_vs_headline.png",
       p1, width = 10, height = 14, dpi = 150)

# m4 SV path (unchanged from before)
fit_m4 <- readRDS("output/fit_m4.rds")
sigma_t_draws <- fit_m4$draws("sigma_t", format = "draws_matrix")
T_ <- nrow(gdp_growth)
sigma_t_mean <- matrix(colMeans(sigma_t_draws), nrow = T_, ncol = 3)
colnames(sigma_t_mean) <- c("E", "I", "P")
sv_df <- as_tibble(sigma_t_mean) |>
  mutate(date = gdp_growth$date) |>
  pivot_longer(c(E, I, P), names_to = "approach", values_to = "sigma_t")
p2 <- ggplot(sv_df, aes(x = date, y = sigma_t, colour = approach)) +
  geom_line(linewidth = 0.6) +
  labs(title = "m4: posterior-mean measurement-error sd over time",
       x = NULL, y = expression(sigma[t]), colour = "Approach")
ggsave("output/figures/02_m4_sv_path.png",
       p2, width = 9, height = 4, dpi = 150)

# m7 kappa posterior
fit_m7 <- readRDS("output/fit_m7.rds")
kappa_draws <- fit_m7$draws("kappa", format = "draws_matrix")
covid_labels <- c("2020 Q2", "2020 Q3", "2020 Q4", "2021 Q1")
kappa_df <- as_tibble(as.matrix(kappa_draws)) |>
  setNames(covid_labels) |>
  pivot_longer(everything(), names_to = "quarter", values_to = "kappa") |>
  mutate(quarter = factor(quarter, levels = covid_labels))
p3 <- ggplot(kappa_df, aes(x = kappa, fill = quarter)) +
  geom_density(alpha = 0.5) +
  geom_vline(xintercept = 1, colour = "grey50", linetype = 2) +
  facet_wrap(~ quarter, ncol = 1, scales = "free_y") +
  coord_cartesian(xlim = c(0, 20)) +
  guides(fill = "none") +
  labs(title = "m7: posterior of COVID-quarter variance multipliers (kappa)",
       subtitle = "Dashed line = no inflation. Only 2020 Q2 needed scale-up.",
       x = expression(kappa), y = NULL)
ggsave("output/figures/04_m7_kappa.png", p3, width = 8, height = 6, dpi = 150)

# m8 standalone: 4-signal latent path vs all 4 observed series
fit_m8 <- readRDS("output/fit_m8.rds")
mu_m8 <- mu_summary(fit_m8, "m8", gdp_growth_4$date)
gdp4_long <- gdp_growth_4 |>
  select(date, `GDP(E)` = g_E, `GDP(I)` = g_I, `GDP(P)` = g_P,
         `Hours worked` = g_U) |>
  pivot_longer(-date, names_to = "series", values_to = "growth")
p4 <- ggplot(mu_m8, aes(x = date)) +
  geom_hline(yintercept = 0, colour = "grey80") +
  geom_line(data = gdp4_long, aes(y = growth, colour = series), alpha = 0.55) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.3, fill = "black") +
  geom_line(aes(y = mean), colour = "black", linewidth = 0.7) +
  scale_colour_manual(values = c(
    "GDP(E)" = "#d95f02", "GDP(I)" = "#1b9e77",
    "GDP(P)" = "#7570b3", "Hours worked" = "#e7298a"
  )) +
  labs(
    title = "m8: 4-signal latent growth (black, 90% CI) vs observed series",
    subtitle = "Post-1979 sample. Hours loaded as alpha + beta*mu (annualised %).",
    x = NULL, y = "%", colour = NULL
  )
ggsave("output/figures/05_m8_4signal.png", p4,
       width = 10, height = 5, dpi = 150)

# m5 COVID zoom (unchanged from before, but rebuilt for consistency)
mu_m5 <- mu_full |>
  filter(model == labels_m["m5"], date >= as.Date("2018-01-01"))
gdp_zoom <- gdp_growth |> filter(date >= as.Date("2018-01-01"))
p5 <- ggplot(mu_m5, aes(x = date)) +
  geom_hline(yintercept = 0, colour = "grey80") +
  geom_line(data = gdp_zoom, aes(y = g_E, colour = "GDP(E)"), alpha = 0.6) +
  geom_line(data = gdp_zoom, aes(y = g_I, colour = "GDP(I)"), alpha = 0.6) +
  geom_line(data = gdp_zoom, aes(y = g_P, colour = "GDP(P)"), alpha = 0.6) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.3, fill = "black") +
  geom_line(aes(y = mean), colour = "black", linewidth = 0.8) +
  scale_colour_manual(values = c("GDP(E)" = "#d95f02",
                                  "GDP(I)" = "#1b9e77", "GDP(P)" = "#7570b3")) +
  labs(title = "m5 latent (black, 90% CI) and three GDP measures, 2018-onwards",
       x = NULL, y = "annualised %", colour = NULL)
ggsave("output/figures/03_m5_covid_zoom.png", p5,
       width = 9, height = 5, dpi = 150)

# m11 monthly latent path
fit_m11 <- readRDS("output/fit_m11.rds")
emp_growth <- readRDS("data/processed/employment_growth_monthly.rds")
gdp_growth_full <- readRDS("data/processed/gdp_growth.rds") |>
  mutate(headline = (g_E + g_I + g_P) / 3)

mu_m_draws <- fit_m11$draws("mu_m", format = "draws_matrix")
m_dates <- emp_growth |>
  filter(date <= max(gdp_growth_full$date)) |>
  pull(date)
mu_m_df <- tibble(
  date = m_dates,
  mean = colMeans(mu_m_draws),
  lo   = apply(mu_m_draws, 2, quantile, 0.05),
  hi   = apply(mu_m_draws, 2, quantile, 0.95)
)
p6 <- ggplot(mu_m_df, aes(x = date)) +
  geom_hline(yintercept = 0, colour = "grey80") +
  geom_line(data = filter(gdp_growth_full, date >= min(m_dates)),
            aes(y = headline), colour = "grey55", alpha = 0.7) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.3, fill = "darkorange") +
  geom_line(aes(y = mean), colour = "darkorange", linewidth = 0.5) +
  labs(
    title = "m11: monthly latent growth (orange, 90% CI) vs quarterly headline (grey)",
    subtitle = "Mixed-frequency model with monthly employment as a 4th signal",
    x = NULL, y = "annualised %"
  )
ggsave("output/figures/06_m11_monthly_path.png", p6,
       width = 10, height = 5, dpi = 150)

cat("Figures written to output/figures/:\n",
    "  01_latent_vs_headline.png  (all full-sample specs including m9)\n",
    "  02_m4_sv_path.png\n",
    "  03_m5_covid_zoom.png\n",
    "  04_m7_kappa.png\n",
    "  05_m8_4signal.png\n",
    "  06_m11_monthly_path.png\n", sep = "")
