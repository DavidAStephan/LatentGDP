# LatentGDP

A Bayesian state-space estimate of Australian quarterly GDP growth that
filters measurement error out of the three independent ABS measures
(Expenditure, Income, Production-based). Replicates and extends RBA RDP
2014-12 (Rees, Lancaster & Finlay).

The latest estimate is published automatically after each ABS 5206.0 release at:

**https://davidstephan.github.io/LatentGDP/** *(update once Pages is enabled)*

## What this measures

The headline ABS GDP figure is the *average* of three independently
constructed quarterly measures: GDP(E), GDP(I), GDP(P). They disagree at
the quarter-by-quarter level. This project treats *true* GDP growth as a
latent state observed through three noisy signals, and infers it
Bayesianly. The resulting series is materially less volatile than headline
GDP - across all model specifications, latent variance is 30-35% lower.
Most quarter-to-quarter volatility in published GDP is measurement noise,
not real economic activity.

## Production model

`stan/m9_struct_sv.stan` - AR(1) latent growth with stochastic volatility
on each measurement-error variance plus a construction-based zero
restriction on Production's covariance with the other two measures
(Production is built from independent industry surveys, so its
measurement error is plausibly independent of E and I's balancing-item
noise).

This won the LOO comparison against six other specifications. See
[NOTES.md](NOTES.md) for the full research record (m1-m11).

## Pipeline

```
R/01_fetch_data.R      ABS 5206.0 Table 24 + 6202.0 Table 1
R/fit_production.R     fits m9, hard-fails CI if divergences > 1%
R/output_estimate.R    writes docs/estimates.csv + estimates_latest.json
R/build_site.R         renders docs/index.html + charts
```

The full research suite (m1-m11) is in `R/02_fit_models.R` /
`R/03_compare.R` / `R/04_figures.R` for reproducing the comparison.

## Automation

GitHub Actions workflow at `.github/workflows/recompute.yml`:

- **Schedule:** Wednesdays at 02:00 UTC (covers the typical first-Wednesday
  release window for 5206.0)
- **Manual trigger:** via the Actions tab in GitHub
- **Side effects:** commits updated `docs/` to main and redeploys GitHub Pages
- **Quality gate:** fails if the fit has > 1% divergent transitions

First run takes ~10 min (CmdStan toolchain install + Stan compile);
subsequent runs ~5 min with cache hits.

## To enable Pages on first deploy

1. Push this repo to GitHub
2. Settings -> Pages -> Source: "GitHub Actions"
3. Trigger the workflow manually once (Actions tab -> "Recompute latent
   GDP estimate" -> Run workflow)
4. After it finishes, the URL above will be live

## Local reproduction

```bash
# One-time
Rscript -e 'install.packages(c("readabs","posterior","loo","bayesplot","jsonlite","dplyr","tidyr","ggplot2")); install.packages("cmdstanr", repos = c("https://stan-dev.r-universe.dev","https://cloud.r-project.org")); cmdstanr::install_cmdstan()'

# Each quarter
Rscript R/01_fetch_data.R
Rscript R/fit_production.R
Rscript R/output_estimate.R
Rscript R/build_site.R
```

## References

- Rees, Lancaster & Finlay (2014), "Estimating the Australian Output Gap
  and Other State-Space Refinements to GDP Measurement", RBA RDP 2014-12.
  https://www.rba.gov.au/publications/rdp/2014/2014-12.html
- Aruoba, Diebold, Nalewaik, Schorfheide & Song (2016), "Improving GDP
  Measurement: A Measurement-Error Perspective", J. Econometrics 191(2).
- ABS Cat. 5206.0, Australian National Accounts: National Income,
  Expenditure and Product.
