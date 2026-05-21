// m10: m8 (4-signal: E, I, P, hours) + m4 (stochastic volatility) hybrid.
//   y_t^E = mu_t + eps_t^E,             eps ~ N(0, exp(h_{t,E}/2)^2)
//   y_t^I = mu_t + eps_t^I,             eps ~ N(0, exp(h_{t,I}/2)^2)
//   y_t^P = mu_t + eps_t^P,             eps ~ N(0, exp(h_{t,P}/2)^2)
//   y_t^U = alpha + beta * mu_t + eps_t^U,  eps ~ N(0, exp(h_{t,U}/2)^2)
// Each of 4 series has stationary AR(1) on log-variance (Kim-Shephard-Chib).
// Sample: T = 189 post-1979 (hours data starts ~1979).

data {
  int<lower=1> T;
  matrix[T, 3] y_gdp;
  vector[T] y_U;
}
parameters {
  real c;
  real<lower=-1, upper=1> rho;
  real<lower=0> tau;
  real alpha;
  real<lower=0> beta;
  vector[4] mu_h;
  vector<lower=-1, upper=1>[4] phi;
  vector<lower=0>[4] omega;
  vector[T] mu_raw;
  matrix[T, 4] h_raw;
}
transformed parameters {
  vector[T] mu;
  matrix[T, 4] h;
  {
    real mu_uncond = c / (1 - rho);
    real sd_uncond = tau / sqrt(1 - rho * rho);
    mu[1] = mu_uncond + sd_uncond * mu_raw[1];
    for (t in 2:T)
      mu[t] = c + rho * mu[t-1] + tau * mu_raw[t];
  }
  for (k in 1:4) {
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
  alpha ~ normal(-1, 1);
  beta  ~ normal(1, 0.5);
  mu_h  ~ normal(2, 1);
  phi   ~ uniform(-1, 1);
  omega ~ normal(0, 0.5);

  mu_raw ~ std_normal();
  to_vector(h_raw) ~ std_normal();

  for (k in 1:3)
    y_gdp[, k] ~ normal(mu, exp(0.5 * h[, k]));
  y_U ~ normal(alpha + beta * mu, exp(0.5 * h[, 4]));
}
generated quantities {
  real mu_bar = c / (1 - rho);
  matrix[T, 4] sigma_t = exp(0.5 * h);
  matrix[T, 4] y_rep;
  vector[T] log_lik;
  for (t in 1:T) {
    log_lik[t] = 0;
    for (k in 1:3) {
      y_rep[t, k] = normal_rng(mu[t], sigma_t[t, k]);
      log_lik[t] += normal_lpdf(y_gdp[t, k] | mu[t], sigma_t[t, k]);
    }
    y_rep[t, 4] = normal_rng(alpha + beta * mu[t], sigma_t[t, 4]);
    log_lik[t] += normal_lpdf(y_U[t] | alpha + beta * mu[t], sigma_t[t, 4]);
  }
}
