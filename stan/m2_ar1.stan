// m2: AR(1) latent growth.
//   y_t^k = mu_t + eps_t^k,           eps_t^k ~ N(0, sigma_k^2)
//   mu_t  = c + rho * mu_{t-1} + eta_t,   eta_t ~ N(0, tau^2)
//   mu_1 drawn from the stationary distribution.
// Non-centred parameterisation on mu via mu_raw to avoid funnel pathologies.

data {
  int<lower=1> T;
  int<lower=1> K;
  matrix[T, K] y;
}
parameters {
  real c;
  real<lower=-1, upper=1> rho;
  real<lower=0> tau;
  vector<lower=0>[K] sigma;
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
  c     ~ normal(1.5, 1);          // c = mu_bar * (1 - rho); prior centred at mu_bar=3, rho=0.5
  rho   ~ normal(0.5, 0.3);
  tau   ~ normal(0, 2);
  sigma ~ normal(0, 2);

  mu_raw ~ std_normal();           // implies mu_1 ~ N(mu_uncond, sd_uncond^2),
                                   // mu_t | mu_{t-1} ~ N(c + rho*mu_{t-1}, tau^2)
  for (k in 1:K)
    y[, k] ~ normal(mu, sigma[k]);
}
generated quantities {
  real mu_bar = c / (1 - rho);
  matrix[T, K] y_rep;
  vector[T] log_lik;
  for (t in 1:T) {
    log_lik[t] = 0;
    for (k in 1:K) {
      y_rep[t, k] = normal_rng(mu[t], sigma[k]);
      log_lik[t] += normal_lpdf(y[t, k] | mu[t], sigma[k]);
    }
  }
}
