# ============================================================
# Day 1: Pull 2025 hitter data for the OBP shrinkage project
# Splits: April (season start to Apr 30) vs. rest of season
# Source: Baseball-Reference via the baseballr package
# ============================================================

library(tidyverse)
library(baseballr)

# ---- 1. Pull the two date splits ---------------------------
# 2025 opened with the Tokyo Series on March 18; regular season ended Sept 28.
april <- bref_daily_batter(t1 = "2025-03-18", t2 = "2025-04-30")
rest  <- bref_daily_batter(t1 = "2025-05-01", t2 = "2025-09-28")

# ---- 2. Keep only what the OBP model needs -----------------
# OBP = (H + BB + HBP) / (AB + BB + HBP + SF)
# "on_base" = successes, "opps" = attempts (the OBP denominator)
prep <- function(df) {
  df %>%
    transmute(
      bbref_id,
      Name,
      PA,
      BB,
      on_base = H + BB + HBP,
      opps    = AB + BB + HBP + SF,
      obp_bref = OBP          # Baseball-Reference's own OBP, for checking
    )
}

april_clean <- prep(april)
rest_clean  <- prep(rest)

# ---- 3. Join April to rest-of-season, one row per hitter ----
obp <- april_clean %>%
  inner_join(rest_clean, by = c("bbref_id", "Name"),
             suffix = c("_apr", "_rest")) %>%
  filter(opps_apr >= 50, opps_rest >= 200) %>%   # sample-size cutoffs
  mutate(
    obp_apr  = on_base_apr  / opps_apr,
    obp_rest = on_base_rest / opps_rest,
    bb_rate_apr = BB_apr / PA_apr               # walk rate, used later as a predictor
  )

# ---- 4. Sanity checks ---------------------------------------
cat("Hitters kept:", nrow(obp), "\n")   # expect a few hundred

# Our OBP should match Baseball-Reference's (differences ~0)
obp %>%
  summarise(max_diff_apr = max(abs(obp_apr - obp_bref_apr), na.rm = TRUE))

# Quick look at the best April on-base hitters
obp %>%
  arrange(desc(obp_apr)) %>%
  select(Name, opps_apr, obp_apr, obp_rest) %>%
  head(10)

# ---- 5. Save for Day 2 --------------------------------------
write_csv(obp, "obp_2025.csv")
cat("Saved obp_2025.csv to:", getwd(), "\n")
