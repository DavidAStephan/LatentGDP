// m5: AR(1) latent growth with serially correlated measurement errors.
//   y_t^k = mu_t + eps_t^k,
//   eps_t^k = psi_k * eps_{t-1,k} + u_t^k,    u_t^k ~ N(0, sigma_k^2)
//   eps_1^k ~ N(0, sigma_k / sqrt(1 - psi_k^2))   (stationary init)
//
// eps is marginalised via quasi-differencing:
//   y_t - psi * y_{t-1}  =  (mu_t - psi * mu_{t-1})  +  u_t
// so we never sample eps as a parameter — only mu, sigma, psi, rho, tau, c.

data {
  int<lower=1> T;
  int<lower=1> K;
  matrix[T, K] y;
}
parameters {
  real c;
  real<lower=-1, upper=1> rho;
  real<lower=0> tau;
  vector<lower=0>[K] sigma;            // sd of u (innovation)
  vector<lower=-1, upper=1>[K] psi;    // measurement-error persistence
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
  c     ~ normal(1.5, 1);
  rho   ~ normal(0.5, 0.3);
  tau   ~ normal(0, 2);
  sigma ~ normal(0, 2);
  psi   ~ normal(0, 0.5);

  mu_raw ~ std_normal();

  for (k in 1:K) {
    y[1, k] ~ normal(mu[1], sigma[k] / sqrt(1 - psi[k] * psi[k]));
    for (t in 2:T)
      y[t, k] ~ normal(mu[t] + psi[k] * (y[t-1, k] - mu[t-1]), sigma[k]);
  }
}
generated quantities {
  real mu_bar = c / (1 - rho);
  vector[K] eps_sd = sigma ./ sqrt(1 - psi .* psi);   // unconditional sd of eps
  matrix[T, K] y_rep;
  vector[T] log_lik;
  for (t in 1:T) {
    log_lik[t] = 0;
    for (k in 1:K) {
      real mu_pred;
      real sd_pred;
      if (t == 1) {
        mu_pred = mu[1];
        sd_pred = sigma[k] / sqrt(1 - psi[k] * psi[k]);
      } else {
        mu_pred = mu[t] + psi[k] * (y[t-1, k] - mu[t-1]);
        sd_pred = sigma[k];
      }
      log_lik[t] += normal_lpdf(y[t, k] | mu_pred, sd_pred);
      y_rep[t, k] = normal_rng(mu_pred, sd_pred);
    }
  }
}
