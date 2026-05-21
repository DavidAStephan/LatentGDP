// m4: AR(1) latent growth with stationary-SV measurement errors.
//   y_t^k = mu_t + eps_t^k,           eps_t^k ~ N(0, exp(h_{t,k}/2)^2)
//   h_{t,k} = mu_h_k + phi_k * (h_{t-1,k} - mu_h_k) + omega_k * xi_{t,k}
//   h_{1,k} ~ N(mu_h_k, omega_k^2 / (1 - phi_k^2))    (stationary init)
// Stationary AR(1) on log-variance (Kim-Shephard-Chib). Drops the unidentified
// random-walk parameterisation tried earlier — see NOTES.md.

data {
  int<lower=1> T;
  int<lower=1> K;
  matrix[T, K] y;
}
parameters {
  real c;
  real<lower=-1, upper=1> rho;
  real<lower=0> tau;
  vector[K] mu_h;                    // long-run log-variance per series
  vector<lower=-1, upper=1>[K] phi;  // persistence of log-variance
  vector<lower=0>[K] omega;          // sd of log-variance innovations
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
  c     ~ normal(1.5, 1);
  rho   ~ normal(0.5, 0.3);
  tau   ~ normal(0, 2);
  mu_h  ~ normal(2, 1);              // log-var ~ 2 -> sd ~ exp(1) ~ 2.7
  phi   ~ uniform(-1, 1);            // weakly informative; prior on a half-life via posterior
  omega ~ normal(0, 0.5);

  mu_raw ~ std_normal();
  to_vector(h_raw) ~ std_normal();

  for (k in 1:K)
    y[, k] ~ normal(mu, exp(0.5 * h[, k]));
}
generated quantities {
  real mu_bar = c / (1 - rho);
  matrix[T, K] sigma_t = exp(0.5 * h);
  matrix[T, K] y_rep;
  vector[T] log_lik;
  for (t in 1:T) {
    log_lik[t] = 0;
    for (k in 1:K) {
      y_rep[t, k] = normal_rng(mu[t], sigma_t[t, k]);
      log_lik[t] += normal_lpdf(y[t, k] | mu[t], sigma_t[t, k]);
    }
  }
}
