// m9: m6 (structural Sigma) + m4 (stochastic volatility) hybrid.
//   y_t^E, y_t^I | mu_t ~ MVN([mu_t, mu_t], Sigma_EI_t)
//   y_t^P       | mu_t ~ N(mu_t, sigma_{t,P}^2)
// Each sigma_{t,k} follows a stationary AR(1) on its log-variance.
// Correlation rho_EI between E and I errors is constant; P is independent
// (justified by ABS construction: P comes from independent industry surveys).

data {
  int<lower=1> T;
  int<lower=1> K;
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
  vector[K] mu_h;
  vector<lower=-1, upper=1>[K] phi;
  vector<lower=0>[K] omega;
  real<lower=-1, upper=1> rho_EI;
  vector[T] mu_raw;
  matrix[T, K] h_raw;
}
transformed parameters {
  vector[T] mu;
  matrix[T, K] h;
  {
    real mu_uncond = c / (1 - rho);
    real sd_uncond = tau / sqrt(1 - rho * rho);
    mu[1] = mu_uncond + sd_uncond * mu_raw[1];
    for (t in 2:T)
      mu[t] = c + rho * mu[t-1] + tau * mu_raw[t];
  }
  for (k in 1:K) {
    real h_sd_uncond = omega[k] / sqrt(1 - phi[k] * phi[k]);
    h[1, k] = mu_h[k] + h_sd_uncond * h_raw[1, k];
    for (t in 2:T)
      h[t, k] = mu_h[k] + phi[k] * (h[t-1, k] - mu_h[k]) + omega[k] * h_raw[t, k];
  }
}
model {
  c       ~ normal(1.5, 1);
  rho     ~ normal(0.5, 0.3);
  tau     ~ normal(0, 2);
  mu_h    ~ normal(2, 1);
  phi     ~ uniform(-1, 1);
  omega   ~ normal(0, 0.5);
  rho_EI  ~ normal(0, 0.5);
  mu_raw  ~ std_normal();
  to_vector(h_raw) ~ std_normal();

  for (t in 1:T) {
    real s_E = exp(0.5 * h[t, 1]);
    real s_I = exp(0.5 * h[t, 2]);
    real s_P = exp(0.5 * h[t, 3]);
    matrix[2, 2] L_EI;
    L_EI[1, 1] = s_E;
    L_EI[2, 1] = s_I * rho_EI;
    L_EI[1, 2] = 0;
    L_EI[2, 2] = s_I * sqrt(1 - rho_EI * rho_EI);

    y_EI[t] ~ multi_normal_cholesky(rep_vector(mu[t], 2), L_EI);
    y_P[t]  ~ normal(mu[t], s_P);
  }
}
generated quantities {
  real mu_bar = c / (1 - rho);
  matrix[T, K] sigma_t = exp(0.5 * h);
  matrix[T, K] y_rep;
  vector[T] log_lik;
  for (t in 1:T) {
    real s_E = sigma_t[t, 1];
    real s_I = sigma_t[t, 2];
    real s_P = sigma_t[t, 3];
    matrix[2, 2] L_EI;
    L_EI[1, 1] = s_E;
    L_EI[2, 1] = s_I * rho_EI;
    L_EI[1, 2] = 0;
    L_EI[2, 2] = s_I * sqrt(1 - rho_EI * rho_EI);
    vector[2] mu_vec = rep_vector(mu[t], 2);
    vector[2] yrep_EI = multi_normal_cholesky_rng(mu_vec, L_EI);
    y_rep[t, 1] = yrep_EI[1];
    y_rep[t, 2] = yrep_EI[2];
    y_rep[t, 3] = normal_rng(mu[t], s_P);
    log_lik[t]  = multi_normal_cholesky_lpdf(y_EI[t] | mu_vec, L_EI)
                + normal_lpdf(y_P[t] | mu[t], s_P);
  }
}
