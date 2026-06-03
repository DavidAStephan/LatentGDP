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

# Y-axis range covering normal recessions / booms but clipping COVID's
# outliers; the annotation flags what's off-scale. Units are quarter-on-quarter
# growth (100 x dlog), so the band is 1/4 of the annualised scale.
YLIM <- c(-2.5, 2.5)
covid_note <- "COVID: 2020 Q2 ~-7%, Q3 ~+5.5% (off-scale)"

# Full sample chart
p_full <- ggplot(estimates, aes(x = date)) +
  geom_hline(yintercept = 0, colour = "grey80") +
  geom_line(aes(y = headline_mean), colour = "grey55", alpha = 0.7) +
  geom_ribbon(aes(ymin = mu_q05, ymax = mu_q95),
              alpha = 0.25, fill = "steelblue") +
  geom_line(aes(y = mu_median), colour = "steelblue", linewidth = 0.5) +
  coord_cartesian(ylim = YLIM) +
  annotate("text", x = as.Date("2020-12-01"), y = YLIM[2] - 0.5,
           label = covid_note, size = 3, hjust = 1, colour = "grey40") +
  labs(
    title = "Australian latent GDP growth, 1960-present",
    subtitle = "Model m9 (structural Sigma + SV). Blue = posterior median + 90% CI. Grey = headline.",
    x = NULL, y = "quarter-on-quarter growth, %",
    caption = paste("Data: ABS 5206.0 Table 24. Run:", diag$run_time_utc, "UTC.")
  )
ggsave("docs/chart_latent.png", p_full, width = 10, height = 5, dpi = 150)

# Recent view: skip COVID entirely so the chart shows post-pandemic dynamics
# at a useful y-scale.
recent <- estimates |> filter(date >= as.Date("2022-01-01"))
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
    title = "Latent GDP vs three ABS measures - post-2022",
    x = NULL, y = "quarter-on-quarter %", colour = NULL
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
    .eq { background: #f7f7f7; border-left: 3px solid #c0c8d8;
          padding: 0.5rem 0.9rem; margin: 0.5rem 0;
          font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
          font-size: 0.92rem; white-space: pre-wrap; }
    a { color: #1f6feb; }
    footer { color: #888; font-size: 0.85rem; margin-top: 2rem;
             border-top: 1px solid #eee; padding-top: 1rem; }
  </style>
</head>
<body>
  <h1>Latent Australian GDP growth, %s</h1>
  <div class="card">
    <p class="headline">%s</p>
    <p class="ci">90%% credible interval: %s (quarter-on-quarter growth)</p>
    <p class="meta">Headline (mean of E, I, P): %+.2f%%. Latent series variance is %.0f%% of headline variance across the full sample.</p>
  </div>

  <h2>Observed measures for %s</h2>
  <table>
    <tr><td>GDP(E) expenditure-based</td><td><strong>%+.2f%%</strong></td></tr>
    <tr><td>GDP(I) income-based</td>     <td><strong>%+.2f%%</strong></td></tr>
    <tr><td>GDP(P) production-based</td> <td><strong>%+.2f%%</strong></td></tr>
  </table>

  <h2>Recent quarters (post-2022)</h2>
  <img src="chart_recent.png" alt="Latent GDP growth vs three measures, post-2022">

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

  <h3>Historical estimate, 1960-present</h3>
  <img src="chart_latent.png" alt="Latent GDP growth vs headline, 1960-present">

  <h3>Downloads</h3>
  <ul>
    <li><a href="estimates.csv">estimates.csv</a> - full quarterly time series with 90%% CI</li>
    <li><a href="estimates_latest.json">estimates_latest.json</a> - latest quarter headline</li>
    <li><a href="diagnostics.json">diagnostics.json</a> - sampler diagnostics for the latest fit</li>
  </ul>

  <h2>Model details</h2>

  <p>The production model is m9: an AR(1) latent growth state observed
  through three measurement equations, with stochastic volatility on
  each measurement-error variance and a construction-based zero
  restriction on the (E, I) vs P covariance.</p>

  <h3>Observation equations</h3>
  <p>At time t, the three observed ABS measures relate to latent growth
  &mu;<sub>t</sub> via:</p>
  <div class="eq">(y<sub>t</sub><sup>E</sup>, y<sub>t</sub><sup>I</sup>) | &mu;<sub>t</sub>  ~  MVN([&mu;<sub>t</sub>, &mu;<sub>t</sub>],  &Sigma;<sub>EI,t</sub>)
y<sub>t</sub><sup>P</sup>           | &mu;<sub>t</sub>  ~  N(&mu;<sub>t</sub>, &sigma;<sub>P,t</sub><sup>2</sup>)</div>

  <p>where &Sigma;<sub>EI,t</sub> has standard deviations
  &sigma;<sub>E,t</sub>, &sigma;<sub>I,t</sub> on the diagonal and a
  constant correlation &rho;<sub>EI</sub> off-diagonal. E and I share
  &rho;<sub>EI</sub> because their measurement errors flow through the
  same national-accounts balancing process. P is built from independent
  industry value-added surveys, so
  Cov(&epsilon;<sub>P</sub>, &epsilon;<sub>E</sub>) =
  Cov(&epsilon;<sub>P</sub>, &epsilon;<sub>I</sub>) = 0 by construction
  rather than by fit - this is the &quot;structural Sigma&quot; piece.</p>

  <h3>Latent state</h3>
  <p>Latent growth follows a stationary AR(1):</p>
  <div class="eq">&mu;<sub>t</sub> = c + &rho; &middot; &mu;<sub>t-1</sub> + &eta;<sub>t</sub>,    &eta;<sub>t</sub> ~ N(0, &tau;<sup>2</sup>)
&mu;<sub>1</sub> drawn from its stationary distribution.</div>

  <h3>Stochastic volatility</h3>
  <p>Each series&apos; log-variance is itself a stationary AR(1)
  (Kim&ndash;Shephard&ndash;Chib parameterisation):</p>
  <div class="eq">h<sub>k,t</sub> = &mu;<sub>h,k</sub> + &phi;<sub>k</sub> &middot; (h<sub>k,t-1</sub> - &mu;<sub>h,k</sub>) + &omega;<sub>k</sub> &middot; &xi;<sub>k,t</sub>
&sigma;<sub>k,t</sub><sup>2</sup> = exp(h<sub>k,t</sub>)</div>

  <p>This is what lets the COVID quarters get absorbed into
  time-varying &sigma;<sub>k,t</sub> instead of distorting &mu;<sub>t</sub>.
  The 1970s and mid-1990s also show elevated &sigma;<sub>k,t</sub> -
  not just COVID.</p>

  <h3>Priors</h3>
  <p>The model is estimated in <em>annualised</em> growth units
  (400&times;dlog); the figures shown on this page are quarter-on-quarter
  (100&times;dlog), i.e. the latent state divided by 4. The priors below are
  therefore stated in the model&apos;s annualised units &ndash; weakly
  informative, calibrated to Australian quarterly growth being ~3%% trend
  (annualised) with innovations of a few percentage points:</p>
  <div class="eq">c           ~ N(1.5, 1)
&rho;           ~ N(0.5, 0.3)    constrained to (-1, 1)
&tau;           ~ half-N(0, 2)
&mu;<sub>h,k</sub>         ~ N(2, 1)
&phi;<sub>k</sub>          ~ Uniform(-1, 1)
&omega;<sub>k</sub>          ~ half-N(0, 0.5)
&rho;<sub>EI</sub>         ~ N(0, 0.5)    constrained to (-1, 1)</div>

  <h3>Why this specification</h3>
  <p>We fit 11 specifications (m1&ndash;m11) and compared them via LOO
  cross-validation. Key findings:</p>
  <ul>
    <li>Adding SV to the baseline (m4 over m1/m2) buys ~240 elpd - the
      single biggest improvement.</li>
    <li>The structural restriction on &Sigma; alone (m6) costs ~3 elpd
      vs baseline but cleanly identifies the E&ndash;I correlation
      separately from the latent state.</li>
    <li>m9 (= m6 + SV) wins another 6 elpd over m4 alone and fixes a
      bimodal &phi;<sub>P</sub> posterior that m4 has - Production&apos;s
      SV is now cleanly identified once cross-series covariance no
      longer competes for explanation.</li>
  </ul>

  <p>Full research record (all 11 specs, including failed extensions like
  m10 and the mixed-frequency m11) at
  <a href="https://github.com/DavidAStephan/LatentGDP/blob/master/NOTES.md">NOTES.md</a>.
  Stan source at
  <a href="https://github.com/DavidAStephan/LatentGDP/blob/master/stan/m9_struct_sv.stan">stan/m9_struct_sv.stan</a>.</p>

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
