// m8: AR(1) latent growth with a 4th signal - hours worked (Rees-Lancaster-
// Finlay's "Model 4" specification).
//   y_t^E = mu_t + eps_t^E
//   y_t^I = mu_t + eps_t^I
//   y_t^P = mu_t + eps_t^P
//   y_t^U = alpha + beta * mu_t + eps_t^U      (Hours worked, %dlog ann.)
// alpha and beta let the labour-market signal load on the latent state with
// its own scale - hours growth doesn't track GDP growth one-for-one because
// of productivity trend.

data {
  int<lower=1> T;
  matrix[T, 3] y_gdp;       // E, I, P
  vector[T] y_U;            // hours worked
}
parameters {
  real c;
  real<lower=-1, upper=1> rho;
  real<lower=0> tau;
  vector<lower=0>[3] sigma_gdp;
  real<lower=0> sigma_U;
  real alpha;
  real<lower=0> beta;       // sign restriction: hours growth rises with GDP growth
  vector[T] mu_raw;
}
transformed parameters {
  vector[T] mu;
  {
    real mu_uncond = c / (1 - rho);
    real sd_uncond = tau / sqrt(1 - rho * rho);
    mu[1] = mu_uncond + sd_uncond * mu_raw[1];
    for (t in 2:T)
      mu[t] = c + rho * mu[t-1] + tau * mu_raw[t];
  }
}
model {
  c          ~ normal(1.5, 1);
  rho        ~ normal(0.5, 0.3);
  tau        ~ normal(0, 2);
  sigma_gdp  ~ normal(0, 2);
  sigma_U    ~ normal(0, 2);
  alpha      ~ normal(-1, 1);   // productivity trend ~1pp/yr; hours growth = GDP - prod
  beta       ~ normal(1, 0.5);
  mu_raw     ~ std_normal();

  for (k in 1:3)
    y_gdp[, k] ~ normal(mu, sigma_gdp[k]);
  y_U ~ normal(alpha + beta * mu, sigma_U);
}
generated quantities {
  real mu_bar = c / (1 - rho);
  matrix[T, 4] y_rep;
  vector[T] log_lik;
  for (t in 1:T) {
    log_lik[t] = 0;
    for (k in 1:3) {
      y_rep[t, k] = normal_rng(mu[t], sigma_gdp[k]);
      log_lik[t] += normal_lpdf(y_gdp[t, k] | mu[t], sigma_gdp[k]);
    }
    y_rep[t, 4] = normal_rng(alpha + beta * mu[t], sigma_U);
    log_lik[t] += normal_lpdf(y_U[t] | alpha + beta * mu[t], sigma_U);
  }
}
