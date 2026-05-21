// m1: baseline — three noisy measures of an iid latent growth rate.
//   y_t^k = mu_t + eps_t^k,   eps_t^k ~ N(0, sigma_k^2)
//   mu_t ~ N(mu_bar, tau^2)   iid across t

data {
  int<lower=1> T;
  int<lower=1> K;              // 3: E, I, P
  matrix[T, K] y;
}
parameters {
  vector[T] mu;
  real mu_bar;
  real<lower=0> tau;
  vector<lower=0>[K] sigma;
}
model {
  mu_bar ~ normal(3, 2);
  tau    ~ normal(0, 2);
  sigma  ~ normal(0, 2);

  mu ~ normal(mu_bar, tau);
  for (k in 1:K)
    y[, k] ~ normal(mu, sigma[k]);
}
generated quantities {
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
