# NOTES

## Paper

RBA RDP 2014-12, "Estimating the Australian Output Gap and Other State-Space
Refinements to GDP Measurement", by Daniel Rees, David Lancaster & Richard Finlay.
https://www.rba.gov.au/publications/rdp/2014/2014-12.html

## Data (run on 2026-05-21)

ABS Cat. 5206.0, Table 24 (Selected Analytical Series). Pulls GDP - {E,I,P} based,
chain volume measures, seasonally adjusted. Sample: 1959 Q4 to 2025 Q4 levels,
T = 265 quarters of 400 x dlog growth rates.

Sample stats (annualised %):
- means ~ 3.2 across all three approaches
- sd: g_E 6.0, g_I 5.1, g_P 4.8
- pairwise correlations ~ 0.6

The 2020 Q2/Q3 COVID quarters (~ +/- 25%) are extreme outliers - they dominate the
likelihood under any constant-variance model.

## Fits

| Spec | mu_bar | rho  | tau  | sig_E | sig_I | sig_P | Diagnostics |
|------|--------|------|------|-------|-------|-------|-------------|
| m1   | 3.24   | -    | 4.02 | 4.10  | 3.25  | 2.66  | clean |
| m2   | 3.13   | 0.04 | 4.03 | 4.11  | 3.26  | 2.66  | clean; rho indistinguishable from 0 |
| m3   | 3.13   | 0.05 | 4.09 | 4.34  | 3.09  | 2.37  | tau/sigma[3]/Omega row 3 R-hat ~1.02 |
| m4   | -      | 0.05 | 4.09 | -     | -     | -     | 4 divs; phi[3] R-hat 1.30 (bimodal) |
| m5   | 3.15   | 0.08 | 4.02 | 3.54  | 2.99  | 2.52  | clean - best diagnostics in 3-measure block |
| m6   | 3.13   | 0.05 | 4.01 | 4.21  | 3.37  | 2.57  | clean (structural restriction; rho_EI = 0.09) |
| m7   | 3.27   | 0.10 | 3.56 | 4.15  | 3.28  | 2.65  | clean; tau drops with COVID quarters absorbed |
| m8   | 2.86   | 0.12 | 3.64 | 2.86  | 3.08  | 1.85  | clean; T=189 post-1979 sample; +hours signal |
| m9   | -      | 0.06 | 4.04 | -     | -     | -     | structural Sigma + SV; 4 divs; E-BFMI borderline; **best LOO** |
| m10  | -      | 0.30 | 2.64 | -     | -     | -     | 4-signal + SV; **R-hat 1.4-1.5 - overparameterised** |
| m11  | -      | -    | -    | -     | -     | -     | mixed-freq monthly latent; clean; sigma_q = (2.88, 3.10, 1.86) |

For m11 the parameters above are at monthly frequency and don't compare
directly to the others. Long-run monthly latent mu_bar_m = 2.65; rho = 0.49
(monthly persistence ≈ 0.12 at quarterly aggregation, consistent with m8).
beta_emp = 0.61 (monthly employment loads on latent with this coefficient).

For m4, measurement-error sd is time-varying; mu_h_k posterior means give long-run
sd = exp(mu_h / 2): E 2.95, I 2.36, P 1.76. Highly persistent (phi_E = 0.98, phi_I = 0.93).

For m5, the AR(1) measurement-error coefficients are negative:
- psi_E = -0.52, psi_I = -0.42, psi_P = -0.18
Negative serial correlation = mean-reverting measurement error - consistent with
statistical-agency overshoot / undershoot patterns and revisions.

Production has the smallest measurement-error sd in every spec - Production-side
GDP is the cleanest single signal of true growth. Expenditure has the largest.

## LOO model comparison

Three groups due to different samples:

### Group 1: 3-measure specs, T = 265

```
   elpd_diff se_diff elpd_loo p_loo
m9       0.0     0.0  -1997   328     <- structural Sigma + SV (BEST)
m4      -6.3     3.1  -2003   336     <- SV
m5    -168.8    23.7  -2165   215
m3    -208.2    29.6  -2205   257
m2    -242.6    24.2  -2239   208
m1    -242.9    23.5  -2240   208
m6    -245.8    24.8  -2242   208
m7    -246.8    22.6  -2243   208
```

- **m9 (structural Sigma + SV) is the best LOO model** - combining the
  identification-by-construction restriction (P-independent measurement
  error) with SV beats unrestricted SV by 6.3 elpd points. Small but
  meaningful: the structural restriction also frees up phi[3] from m4's
  bimodality.
- m4 close second.
- m5 (serial errors) third.
- m6 vs m9 shows the value of SV - the structural restriction alone (m6)
  loses ~3 elpd to m1/m2; adding SV (m9) gains ~246 elpd.

### Group 2: 4-measure specs, T = 189

```
    elpd_diff se_diff elpd_loo p_loo
m10     0.0     0.0  -1840   331     <- 4-signal + SV (NOMINALLY best)
m8    -97.7    21.3  -1938   160     <- 4-signal (no SV)
```

**Warning:** m10 has R-hat 1.4-1.5 on rho, tau, phi[1] and omega[1-3]; the
LOO ranking is not trustworthy. The 4-series-SV model is overparameterised
on T = 189 - too many SV processes competing with the AR(1) latent.

### m11 (mixed-frequency, standalone)

Quarterly log_lik LOO: elpd = -1465 (p_eff = 146)
Monthly log_lik LOO:   elpd = -1674 (p_eff = 135)

Cannot be combined with Groups 1-2 (different observation structure).

## Headline replication result

Full sample (T = 265, 1960-2025):

| Series                          | sd    | var / var(headline) |
|---------------------------------|-------|---------------------|
| Headline (mean of E, I, P)      | 4.55  | 1.00 |
| GDP(E)                          | 6.01  | 1.75 |
| GDP(I)                          | 5.11  | 1.26 |
| GDP(P)                          | 4.76  | 1.10 |
| Latent mu (m1)                  | 3.66  | 0.65 |
| Latent mu (m2)                  | 3.66  | 0.65 |
| Latent mu (m3)                  | 3.82  | 0.71 |
| Latent mu (m4, best LOO)        | 3.81  | 0.70 |
| Latent mu (m5)                  | 3.70  | 0.66 |
| Latent mu (m6, structural Sigma)| 3.64  | 0.64 |
| Latent mu (m7, COVID scale)     | 3.16  | **0.48** |
| Latent mu (m9, structural + SV) | 3.75  | 0.68 |

Subsample (T = 189, 1979-2025, 4-signal models):

| Series                          | sd    | var / var(headline) |
|---------------------------------|-------|---------------------|
| Headline (subsample)            | 3.96  | 1.00 |
| Latent mu (m8, 4-signal)        | 3.43  | 0.75 |
| Latent mu (m10, 4-signal + SV)  | 2.40  | 0.37 (suspect)      |

Mixed-frequency (T_q ≈ 190, 1978-2025):

| Series                          | sd    | var / var(headline) |
|---------------------------------|-------|---------------------|
| Latent mu_q (m11)               | 3.42  | 0.74 |

Across every spec the latent series is 30-35% less variable than headline and
55-65% less variable than GDP(E). This directly replicates the paper's claim
that "much of the quarter-to-quarter volatility in Australian GDP growth
reflects measurement error rather than true shifts in the level of economic
activity" - on 2025 vintage data.

## Identification issue in m3

In `m3_corr.stan` the model has weak identification between (i) movements in
mu_t and (ii) positively correlated measurement errors across approaches: a
common shift to all three observed series at time t can be explained either
way. With LKJ(2) the sampler produced ~2% divergences and E-BFMI of 0.02.
Tightening to LKJ(4) + adapt_delta=0.99 recovers most diagnostics but tau,
sigma[3], and the third row of Omega still have R-hat ~1.02. Posterior
correlations all straddle zero. A more principled fix (not implemented) would
be a structural restriction - e.g., allow only the E-I correlation (which
share national-accounts balancing items) and zero out E-P and I-P.

## Identification issue in m4

The initial random-walk SV parameterisation (h_t = h_{t-1} + omega*xi_t with
h_1 anchored at 2 log(sigma)) was unidentified - R-hat ~1.6 across the board.
Switched to stationary AR(1) on log-variance (Kim-Shephard-Chib), which fixed
everything except phi[3] (Production), which is bimodal because P's
measurement error has the lowest variance and weakest SV signal.

## Substantive surprises

1. The 1970s had ~5-8pp annualised measurement-error sd (peaking 1973-74 oil
   shock era). Current measurement-error sd is ~1-2pp - ABS data quality has
   improved enormously over 65 years.
2. m4 attributes COVID quarters to genuine mu_t movement, not measurement-error
   inflation. The SV path barely moves in 2020-21. The 1970s and mid-1990s are
   bigger spikes in measurement variance than COVID.
3. m7 disagrees with m4 about COVID. Given freedom to inflate the variance
   for just four pandemic quarters, the model concludes that only 2020 Q2
   needed scale-up (kappa = 8.3, posterior entirely above 1). 2020 Q3, Q4,
   and 2021 Q1 all have kappa < 1 - the three measures agreed strongly on
   the rebound. Substantively this means m7's latent mu treats the
   apparent -28% Q2 collapse as partly noise, smoothing the latent state
   considerably (variance ratio 0.48 vs ~0.65 for everything else).
4. m6's structural restriction (Cov(eps_P, .) = 0) is well-identified -
   rho_EI = 0.09 [-0.06, 0.23] - and the data is consistent with the
   construction-based assumption that Production has independent errors.
   m6 loses ~3 elpd to m1/m2 by LOO; the restriction is principled rather
   than data-driven.
5. m8 (4-signal): adding hours-worked drops sigma_P from 2.66 to 1.85 - a
   30% reduction in Production-side measurement error. alpha = -0.79,
   beta = 0.83 implies Australian productivity growth of ~1.3pp/yr, in
   line with historical estimates.
6. m9 demonstrates the value of combining restrictions: m6 alone loses to
   m1/m2; m4 alone wins by 236 elpd over m1; m9 (m6 + m4) wins another 6
   elpd over m4. The structural restriction also fixes m4's bimodal phi[3]
   posterior - Production's SV is cleanly identified once cross-series
   covariance no longer competes for explanation.
7. m10 (4-signal + SV) is overparameterised for T = 189. Lesson: extension
   stacking doesn't always work - SV needs sample size to identify its T*K
   log-variance trajectory. On T = 189 with 4 series there are too many
   degrees of freedom relative to the data.
8. m11's monthly latent path concentrates the COVID Q2 2020 collapse into
   a single deep month (April 2020, ~-45% annualised). The model uses the
   monthly employment data to identify when within the quarter the
   collapse happened. This is the value-add of mixed-frequency models for
   real-time / nowcasting use.

## Sampler settings

- 4 chains x (2000 warmup + 2000 sampling) = 8000 post-warmup draws per model.
- adapt_delta = 0.99 for m3, m4, m5; default for m1, m2.
- Seed = 1 for reproducibility.

## Files

- `R/01_fetch_data.R` - pulls ABS 5206.0 Table 24
- `R/02_fit_models.R` - fits all 5 specs
- `R/03_compare.R`    - LOO + variance decomposition table
- `R/04_figures.R`    - figures
- `stan/m{1..11}_*.stan` - the 11 specifications (m6-m11 are extensions from literature review)
  - m1-m5: original replication of Rees-Lancaster-Finlay
  - m6: structural Sigma restriction (novel cheap extension)
  - m7: Lenza-Primiceri COVID variance scale
  - m8: 4-signal (Rees-Lancaster-Finlay Model 4 - hours worked added)
  - m9: m6 + SV (best LOO model on full sample)
  - m10: m8 + SV (overparameterised; documented as negative result)
  - m11: Mixed-frequency Banbura-Modugno style with monthly employment
- `output/fit_m{1..11}.rds` - saved CmdStanFit objects
- `output/figures/`   - generated PNGs
- `output/tables/variance_decomposition.csv`
- `priors.md`         - prior choices
