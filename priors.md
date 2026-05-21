# Priors

Units throughout: 400 × Δlog(GDP) = annualised quarterly growth in percent.
Australian quarterly real GDP growth (annualised) has historically been ~3% with
quarter-to-quarter swings of a few percentage points, so all priors are scaled to that.

## Baseline (m1)
| Parameter | Prior | Rationale |
|---|---|---|
| `mu_bar` | Normal(3, 2) | trend annualised growth ~3%, weakly informative |
| `tau`    | half-Normal(0, 2) | latent growth std dev; ±2σ admits up to ~4pp swings |
| `sigma_k`| half-Normal(0, 2) | measurement-error std dev per series |

## Extensions (added as specs are written)
- `rho` (m2): Normal(0.5, 0.3) truncated to (-1, 1).
- Off-diagonal Σ (m3): LKJ(2) on the correlation matrix.
- SV (m4): log σ²_{k,t} as a random walk, innovation std ~ half-Normal(0, 0.3).
- AR(1) measurement error (m5): φ_k ~ Normal(0, 0.5), |φ_k| < 1.

All priors are checked via prior predictive simulation before fitting.
