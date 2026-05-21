# Generates the static site under docs/:
#   docs/index.html          - landing page with headline + chart
#   docs/chart_latent.png    - historical mu vs headline
#   docs/chart_recent.png    - zoomed view of last ~5 years
# Assumes output_estimate.R has already written docs/estimates*.json/csv.

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
  library(ggplot2)
})

theme_set(theme_minimal(base_size = 11))

estimates <- read.csv("docs/estimates.csv") |>
  mutate(date = as.Date(date))
latest    <- read_json("docs/estimates_latest.json", simplifyVector = TRUE)
diag      <- read_json("docs/diagnostics.json", simplifyVector = TRUE)

# Full sample chart
p_full <- ggplot(estimates, aes(x = date)) +
  geom_hline(yintercept = 0, colour = "grey80") +
  geom_line(aes(y = headline_mean), colour = "grey55", alpha = 0.7) +
  geom_ribbon(aes(ymin = mu_q05, ymax = mu_q95),
              alpha = 0.25, fill = "steelblue") +
  geom_line(aes(y = mu_median), colour = "steelblue", linewidth = 0.5) +
  labs(
    title = "Australian latent GDP growth, 1960-present",
    subtitle = "Model m9 (structural Sigma + SV). Blue = posterior median + 90% CI. Grey = headline.",
    x = NULL, y = "annualised quarterly growth, %",
    caption = paste("Data: ABS 5206.0 Table 24. Run:", diag$run_time_utc, "UTC.")
  )
ggsave("docs/chart_latent.png", p_full, width = 10, height = 5, dpi = 150)

# Recent zoom
recent <- estimates |> filter(date >= max(date) - 365 * 6)
p_recent <- ggplot(recent, aes(x = date)) +
  geom_hline(yintercept = 0, colour = "grey80") +
  geom_line(aes(y = g_E, colour = "GDP(E)"), alpha = 0.5) +
  geom_line(aes(y = g_I, colour = "GDP(I)"), alpha = 0.5) +
  geom_line(aes(y = g_P, colour = "GDP(P)"), alpha = 0.5) +
  geom_ribbon(aes(ymin = mu_q05, ymax = mu_q95),
              alpha = 0.3, fill = "black") +
  geom_line(aes(y = mu_median), colour = "black", linewidth = 0.8) +
  scale_colour_manual(values = c(
    "GDP(E)" = "#d95f02", "GDP(I)" = "#1b9e77", "GDP(P)" = "#7570b3"
  )) +
  labs(
    title = "Latent GDP vs three ABS measures - last 6 years",
    x = NULL, y = "annualised %", colour = NULL
  )
ggsave("docs/chart_recent.png", p_recent, width = 10, height = 5, dpi = 150)

# Pretty-print the headline number with sign-aware colour for HTML
mu <- latest$mu_median
mu_colour <- if (mu > 0) "#1b9e77" else "#d62728"
mu_str <- sprintf("%+.2f%%", mu)
ci_str <- sprintf("[%+.2f, %+.2f]", latest$mu_q05, latest$mu_q95)

html <- sprintf('<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Latent Australian GDP growth</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
           max-width: 880px; margin: 2rem auto; padding: 0 1rem; color: #222;
           line-height: 1.5; }
    h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
    .headline { font-size: 3rem; font-weight: 600; color: %s; margin: 0; }
    .ci { color: #666; font-size: 1.1rem; }
    .meta { color: #888; font-size: 0.9rem; margin-top: 0.5rem; }
    .card { background: #f7f7f7; padding: 1.2rem 1.5rem;
            border-radius: 8px; margin: 1rem 0; }
    table { border-collapse: collapse; margin: 0.5rem 0; }
    td { padding: 0.2rem 0.6rem 0.2rem 0; }
    td:first-child { color: #666; }
    img { max-width: 100%%; height: auto; display: block; margin: 1rem 0; }
    code { background: #eee; padding: 0.1rem 0.3rem; border-radius: 3px; }
    a { color: #1f6feb; }
    footer { color: #888; font-size: 0.85rem; margin-top: 2rem;
             border-top: 1px solid #eee; padding-top: 1rem; }
  </style>
</head>
<body>
  <h1>Latent Australian GDP growth, %s</h1>
  <div class="card">
    <p class="headline">%s</p>
    <p class="ci">90%% credible interval: %s (annualised quarterly growth)</p>
    <p class="meta">Headline (mean of E, I, P): %+.2f%%. Latent series variance is %.0f%% of headline variance across the full sample.</p>
  </div>

  <h2>Observed measures for %s</h2>
  <table>
    <tr><td>GDP(E) expenditure-based</td><td><strong>%+.2f%%</strong></td></tr>
    <tr><td>GDP(I) income-based</td>     <td><strong>%+.2f%%</strong></td></tr>
    <tr><td>GDP(P) production-based</td> <td><strong>%+.2f%%</strong></td></tr>
  </table>

  <h2>Historical estimate</h2>
  <img src="chart_latent.png" alt="Latent GDP growth vs headline, 1960-present">

  <h2>Last six years</h2>
  <img src="chart_recent.png" alt="Latent GDP growth vs three measures, recent">

  <h2>About</h2>
  <p>This page publishes a Bayesian state-space estimate of Australian
  quarterly GDP growth that filters measurement error out of the three
  independent ABS measures (Expenditure, Income, Production-based GDP).
  The model is m9 from <a href="https://github.com/davidstephan/LatentGDP">this
  repo</a>: an AR(1) latent state with stochastic volatility on the
  measurement-error variances and a construction-based zero restriction
  on the Production-side error covariance. Background: RBA RDP 2014-12
  (Rees, Lancaster &amp; Finlay).</p>

  <p>Data: ABS Cat. 5206.0 Table 24 (Selected Analytical Series),
  seasonally adjusted, chain volume measures. The page is rebuilt
  automatically after each quarterly release.</p>

  <h3>Downloads</h3>
  <ul>
    <li><a href="estimates.csv">estimates.csv</a> - full quarterly time series with 90%% CI</li>
    <li><a href="estimates_latest.json">estimates_latest.json</a> - latest quarter headline</li>
    <li><a href="diagnostics.json">diagnostics.json</a> - sampler diagnostics for the latest fit</li>
  </ul>

  <footer>
    Last updated %s UTC. CmdStan %s. %d divergences out of %d draws.
    Sample %s to %s (T = %d quarters).
  </footer>
</body>
</html>
',
  mu_colour, latest$quarter, mu_str, ci_str,
  latest$headline_mean, 100 * latest$variance_ratio_vs_headline,
  latest$quarter,
  latest$observed$g_E, latest$observed$g_I, latest$observed$g_P,
  diag$run_time_utc, diag$cmdstan_version,
  diag$num_divergent, 4 * diag$iter_per_chain,
  diag$sample_start, diag$sample_end, diag$T
)

writeLines(html, "docs/index.html")
cat("Site built at docs/:\n",
    "  index.html, chart_latent.png, chart_recent.png\n",
    "  estimates.csv, estimates_latest.json, diagnostics.json\n", sep = "")
