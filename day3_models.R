# ============================================================
# Day 3: Bayesian shrinkage models for April OBP
# Input:  obp_2025.csv (from Day 1)
# Output: obp_2025_preds.csv (each hitter's estimates, for Day 4)
#
# Three ways to estimate each hitter's "true" OBP from April only:
#   A. Empirical Bayes (beta-binomial)  - fast, simple shrinkage
#   B. brms hierarchical model          - same idea, fully Bayesian
#   C. brms + April walk rate           - adds plate discipline as a predictor
# ============================================================

library(tidyverse)
library(brms)

# CmdStan lives in a custom folder, so point to it every session
cmdstanr::set_cmdstan_path("E:/Clay_Data_Projects/cmdstan/cmdstan-2.40.0")
options(brms.backend = "cmdstanr", mc.cores = 4)

obp <- read_csv("obp_2025.csv", show_col_types = FALSE)

# ---- A. Empirical Bayes (beta-binomial) ----------------------
# Assume true OBPs across the league follow a Beta(a, b) distribution.
# Find the a, b that best explain the April data, then blend each
# hitter's April record with that league-wide prior.
neg_log_lik <- function(par) {
  a <- exp(par[1]); b <- exp(par[2])
  -sum(lbeta(obp$on_base_apr + a, obp$opps_apr - obp$on_base_apr + b) - lbeta(a, b))
}
fit_eb <- optim(c(log(30), log(60)), neg_log_lik)
a <- exp(fit_eb$par[1]); b <- exp(fit_eb$par[2])

cat("Prior mean OBP:", round(a / (a + b), 3), "\n")
cat("Prior strength: like adding", round(a + b),
    "league-average plate appearances to every hitter\n\n")

obp <- obp %>%
  mutate(eb_est = (on_base_apr + a) / (opps_apr + a + b))

# ---- B. brms hierarchical model ------------------------------
# Each hitter gets his own OBP, but those OBPs are pulled toward
# the league average. The data decide how hard to pull.
fit_b <- brm(
  on_base_apr | trials(opps_apr) ~ 1 + (1 | bbref_id),
  data = obp, family = binomial(),
  prior = prior(normal(0, 1), class = "sd"),
  seed = 2025, chains = 4, iter = 2000, refresh = 0
)
print(summary(fit_b))

# ---- C. Add April walk rate as a predictor --------------------
# Walk rate settles faster than OBP, so it can tell the model
# which hot starts are backed by real plate discipline.
obp <- obp %>% mutate(bb_z = as.numeric(scale(bb_rate_apr)))

fit_c <- brm(
  on_base_apr | trials(opps_apr) ~ 1 + bb_z + (1 | bbref_id),
  data = obp, family = binomial(),
  prior = c(prior(normal(0, 1), class = "sd"),
            prior(normal(0, 0.5), class = "b")),
  seed = 2025, chains = 4, iter = 2000, refresh = 0
)
print(summary(fit_c))

# ---- Each hitter's estimated true OBP --------------------------
# trials = 1 turns the expected count into a probability (an OBP)
est_true_obp <- function(fit) {
  fitted(fit, newdata = obp %>% mutate(opps_apr = 1))[, "Estimate"]
}
obp <- obp %>%
  mutate(
    brms_est    = est_true_obp(fit_b),
    brms_bb_est = est_true_obp(fit_c)
  )

# ---- Preview: which estimate predicts rest of season best? ----
rmse <- function(pred) sqrt(mean((pred - obp$obp_rest)^2))
league_avg <- sum(obp$on_base_apr) / sum(obp$opps_apr)

results <- tibble(
  method = c("Raw April OBP", "League average for everyone",
             "Empirical Bayes", "brms hierarchical", "brms + walk rate"),
  rmse = c(rmse(obp$obp_apr), rmse(rep(league_avg, nrow(obp))),
           rmse(obp$eb_est), rmse(obp$brms_est), rmse(obp$brms_bb_est))
) %>%
  mutate(vs_raw = scales::percent(1 - rmse / rmse[1], accuracy = 1)) %>%
  arrange(rmse)

cat("\nPrediction error (lower is better); vs_raw = error cut vs raw April:\n")
print(results)

# ---- Save for Day 4 ---------------------------------------------
obp %>%
  select(bbref_id, Name, opps_apr, obp_apr, bb_rate_apr, obp_rest,
         eb_est, brms_est, brms_bb_est) %>%
  write_csv("obp_2025_preds.csv")
saveRDS(list(fit_b = fit_b, fit_c = fit_c), "day3_fits.rds")
cat("\nSaved obp_2025_preds.csv and day3_fits.rds\n")
