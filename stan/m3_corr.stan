// m3: AR(1) latent growth with correlated measurement errors.
//   y_t = mu_t * 1_K + eps_t,        eps_t ~ MVN(0, Sigma)
//   Sigma = diag(sigma) * Omega * diag(sigma),  Omega ~ LKJ(2)
//   mu_t = c + rho * mu_{t-1} + eta_t,  eta_t ~ N(0, tau^2)
// Common shocks (e.g. balancing-item adjustments across approaches) get
// absorbed by Omega instead of leaking into mu_t.

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
  cholesky_factor_corr[K] L_Omega;
  vector[T] mu_raw;
}
transformed parameters {
  vector[T] mu;
  matrix[K, K] L_Sigma = diag_pre_multiply(sigma, L_Omega);
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
  L_Omega ~ lkj_corr_cholesky(4);   // tighter than LKJ(2): identification through
                                     // regularisation. m_t and corr(eps) are
                                     // weakly identified — see NOTES.md.
  mu_raw  ~ std_normal();

  for (t in 1:T)
    y[t]' ~ multi_normal_cholesky(rep_vector(mu[t], K), L_Sigma);
}
generated quantities {
  real mu_bar = c / (1 - rho);
  matrix[K, K] Omega = multiply_lower_tri_self_transpose(L_Omega);
  vector[T] log_lik;
  matrix[T, K] y_rep;
  for (t in 1:T) {
    vector[K] mu_vec = rep_vector(mu[t], K);
    log_lik[t] = multi_normal_cholesky_lpdf(y[t]' | mu_vec, L_Sigma);
    y_rep[t] = multi_normal_cholesky_rng(mu_vec, L_Sigma)';
  }
}
