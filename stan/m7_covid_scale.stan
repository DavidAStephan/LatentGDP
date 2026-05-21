// m7: AR(1) latent growth with Lenza-Primiceri COVID variance scaling.
//   y_t^k = mu_t + eps_t^k,   eps_t^k ~ N(0, (kappa_t * sigma_k)^2)
//   kappa_t = 1 for normal quarters, kappa_q free for each COVID quarter.
// Same scale across the three approaches for a given quarter - the COVID shock
// hit data quality symmetrically, by assumption. Allows a clean ablation against
// m4 (SV): does just scaling a handful of pandemic quarters reach SV's fit?

data {
  int<lower=1> T;
  int<lower=1> K;
  matrix[T, K] y;
  int<lower=0> n_covid;
  array[n_covid] int<lower=1, upper=T> covid_idx;
}
parameters {
  real c;
  real<lower=-1, upper=1> rho;
  real<lower=0> tau;
  vector<lower=0>[K] sigma;
  vector<lower=0>[n_covid] kappa;        // variance scale at each COVID quarter
  vector[T] mu_raw;
}
transformed parameters {
  vector[T] mu;
  vector[T] kappa_t = rep_vector(1.0, T);
  for (i in 1:n_covid) kappa_t[covid_idx[i]] = kappa[i];
  {
    real mu_uncond = c / (1 - rho);
    real sd_uncond = tau / sqrt(1 - rho * rho);
    mu[1] = mu_uncond + sd_uncond * mu_raw[1];
    for (t in 2:T)
      mu[t] = c + rho * mu[t-1] + tau * mu_raw[t];
  }
}
model {
  c     ~ normal(1.5, 1);
  rho   ~ normal(0.5, 0.3);
  tau   ~ normal(0, 2);
  sigma ~ normal(0, 2);
  kappa ~ lognormal(0, 1);          // median 1, supports order-of-magnitude scaling
  mu_raw ~ std_normal();

  for (k in 1:K)
    y[, k] ~ normal(mu, sigma[k] * kappa_t);
}
generated quantities {
  real mu_bar = c / (1 - rho);
  matrix[T, K] y_rep;
  vector[T] log_lik;
  for (t in 1:T) {
    log_lik[t] = 0;
    for (k in 1:K) {
      real sd_eff = sigma[k] * kappa_t[t];
      y_rep[t, k] = normal_rng(mu[t], sd_eff);
      log_lik[t] += normal_lpdf(y[t, k] | mu[t], sd_eff);
    }
  }
}
