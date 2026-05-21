// m6: AR(1) latent growth with structurally-restricted measurement-error covariance.
//   y_t^E, y_t^I  | mu_t  ~ MVN([mu_t, mu_t], Sigma_EI)
//   y_t^P         | mu_t  ~ N(mu_t, sigma_P^2)
// Identification by construction: Production is built from independent industry
// value-added surveys, so its measurement error is independent of E and I.
// E and I share national-accounts balancing items, so rho_EI is free.

data {
  int<lower=1> T;
  int<lower=1> K;                    // K must be 3 here
  matrix[T, K] y;
}
transformed data {
  array[T] vector[2] y_EI;
  vector[T] y_P;
  for (t in 1:T) {
    y_EI[t] = y[t, 1:2]';
    y_P[t]  = y[t, 3];
  }
}
parameters {
  real c;
  real<lower=-1, upper=1> rho;
  real<lower=0> tau;
  vector<lower=0>[K] sigma;          // sigma[1]=E, [2]=I, [3]=P
  real<lower=-1, upper=1> rho_EI;    // only free off-diagonal in Sigma
  vector[T] mu_raw;
}
transformed parameters {
  vector[T] mu;
  matrix[2, 2] L_EI;
  L_EI[1, 1] = sigma[1];
  L_EI[2, 1] = sigma[2] * rho_EI;
  L_EI[1, 2] = 0;
  L_EI[2, 2] = sigma[2] * sqrt(1 - rho_EI * rho_EI);
  {
    real mu_uncond = c / (1 - rho);
    real sd_uncond = tau / sqrt(1 - rho * rho);
    mu[1] = mu_uncond + sd_uncond * mu_raw[1];
    for (t in 2:T)
      mu[t] = c + rho * mu[t-1] + tau * mu_raw[t];
  }
}
model {
  c       ~ normal(1.5, 1);
  rho     ~ normal(0.5, 0.3);
  tau     ~ normal(0, 2);
  sigma   ~ normal(0, 2);
  rho_EI  ~ normal(0, 0.5);
  mu_raw  ~ std_normal();

  for (t in 1:T)
    y_EI[t] ~ multi_normal_cholesky(rep_vector(mu[t], 2), L_EI);
  y_P ~ normal(mu, sigma[3]);
}
generated quantities {
  real mu_bar = c / (1 - rho);
  matrix[T, K] y_rep;
  vector[T] log_lik;
  for (t in 1:T) {
    vector[2] mu_vec = rep_vector(mu[t], 2);
    vector[2] yrep_EI = multi_normal_cholesky_rng(mu_vec, L_EI);
    y_rep[t, 1] = yrep_EI[1];
    y_rep[t, 2] = yrep_EI[2];
    y_rep[t, 3] = normal_rng(mu[t], sigma[3]);
    log_lik[t]  = multi_normal_cholesky_lpdf(y_EI[t] | mu_vec, L_EI)
                + normal_lpdf(y_P[t] | mu[t], sigma[3]);
  }
}
