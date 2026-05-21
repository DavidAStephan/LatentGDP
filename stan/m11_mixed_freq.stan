// m11: Mixed-frequency Banbura-Modugno-style dynamic factor with 1 monthly indicator.
//   Latent monthly growth mu_m (AR(1) at monthly frequency).
//   Monthly employment growth loads on mu_m:
//     y_emp_m = alpha_emp + beta_emp * mu_m + eps_emp_m
//   Quarterly GDP measures load on the average of 3 monthly latents:
//     y_q^k = (mu_{m_q} + mu_{m_q - 1} + mu_{m_q - 2}) / 3 + eps_q^k
// (Mariano-Murasawa simplified aggregation - exact growth aggregation has
//  weights 1/3, 2/3, 1, 2/3, 1/3 across 5 months; we use the 3-month average.)

data {
  int<lower=1> T_m;
  int<lower=1> T_q;
  array[T_q] int<lower=3, upper=T_m> q_end_m;   // last-month index per quarter
  matrix[T_q, 3] y_q;
  vector[T_m] y_emp;
}
parameters {
  real c;
  real<lower=-1, upper=1> rho;
  real<lower=0> tau;
  vector<lower=0>[3] sigma_q;
  real alpha_emp;
  real<lower=0> beta_emp;
  real<lower=0> sigma_emp;
  vector[T_m] mu_raw;
}
transformed parameters {
  vector[T_m] mu_m;
  vector[T_q] mu_q;
  {
    real mu_uncond = c / (1 - rho);
    real sd_uncond = tau / sqrt(1 - rho * rho);
    mu_m[1] = mu_uncond + sd_uncond * mu_raw[1];
    for (m in 2:T_m)
      mu_m[m] = c + rho * mu_m[m-1] + tau * mu_raw[m];
  }
  for (q in 1:T_q) {
    int m_end = q_end_m[q];
    mu_q[q] = (mu_m[m_end] + mu_m[m_end - 1] + mu_m[m_end - 2]) / 3.0;
  }
}
model {
  c          ~ normal(0.3, 0.5);    // monthly drift; long-run mean = c/(1-rho)
  rho        ~ normal(0.9, 0.1);    // monthly persistence is high a priori
  tau        ~ normal(0, 5);        // monthly innovation sd (annualised %)
  sigma_q    ~ normal(0, 2);
  alpha_emp  ~ normal(-1.5, 1.5);   // productivity wedge between GDP and emp growth
  beta_emp   ~ normal(1, 0.5);
  sigma_emp  ~ normal(0, 5);
  mu_raw     ~ std_normal();

  y_emp ~ normal(alpha_emp + beta_emp * mu_m, sigma_emp);
  for (k in 1:3)
    y_q[, k] ~ normal(mu_q, sigma_q[k]);
}
generated quantities {
  real mu_bar_m = c / (1 - rho);    // long-run monthly latent (in annualised %)
  matrix[T_q, 3] y_q_rep;
  vector[T_m] y_emp_rep;
  vector[T_q] log_lik_q;
  vector[T_m] log_lik_m;
  for (m in 1:T_m) {
    y_emp_rep[m] = normal_rng(alpha_emp + beta_emp * mu_m[m], sigma_emp);
    log_lik_m[m] = normal_lpdf(y_emp[m] | alpha_emp + beta_emp * mu_m[m], sigma_emp);
  }
  for (q in 1:T_q) {
    log_lik_q[q] = 0;
    for (k in 1:3) {
      y_q_rep[q, k] = normal_rng(mu_q[q], sigma_q[k]);
      log_lik_q[q] += normal_lpdf(y_q[q, k] | mu_q[q], sigma_q[k]);
    }
  }
}
