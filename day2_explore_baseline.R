# ============================================================
# Day 2: Explore April vs. rest-of-season OBP, set a baseline
# Input: obp_2025.csv (from Day 1)
# Output: two charts (PNG) + baseline error numbers
# ============================================================

library(tidyverse)

obp <- read_csv("obp_2025.csv", show_col_types = FALSE)

# ---- 1. League average OBP (weighted by opportunities) ------
league_obp_apr <- sum(obp$on_base_apr) / sum(obp$opps_apr)
cat("League April OBP (this sample):", round(league_obp_apr, 3), "\n")

# ---- 2. Chart: April OBP vs. rest-of-season OBP --------------
# Dashed line = "April predicted perfectly". Points flatter than
# that line mean April overstated the extremes.
p1 <- ggplot(obp, aes(x = obp_apr, y = obp_rest)) +
  geom_point(alpha = 0.6) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  geom_smooth(method = "lm", se = FALSE, color = "#092C5C") +
  labs(
    title = "April OBP overstates the extremes",
    subtitle = "2025 hitters; dashed line = April perfectly predicts rest of season",
    x = "April OBP", y = "Rest-of-season OBP"
  ) +
  theme_minimal()
print(p1)
ggsave("day2_april_vs_rest.png", p1, width = 7, height = 5, dpi = 150)

# How steep is the fitted line? 1.0 = no regression to the mean.
slope <- coef(lm(obp_rest ~ obp_apr, data = obp))[["obp_apr"]]
cat("Slope of rest-of-season on April OBP:", round(slope, 2),
    "(1.0 would mean April is fully trustworthy)\n")

# ---- 3. Baseline errors (RMSE) -------------------------------
rmse <- function(pred, actual) sqrt(mean((pred - actual)^2))

baseline <- tibble(
  method = c("Raw April OBP", "Everyone = league average"),
  rmse = c(
    rmse(obp$obp_apr, obp$obp_rest),
    rmse(rep(league_obp_apr, nrow(obp)), obp$obp_rest)
  )
)
print(baseline)
# If "league average" beats raw April, that's your first headline:
# a month of OBP is so noisy that ignoring it does better.

# ---- 4. Biggest April-to-rest drops and gains -----------------
cat("\nBiggest drops after April:\n")
obp %>%
  mutate(change = obp_rest - obp_apr) %>%
  arrange(change) %>%
  select(Name, opps_apr, obp_apr, obp_rest, change) %>%
  head(5) %>%
  print()

cat("\nBiggest gains after April:\n")
obp %>%
  mutate(change = obp_rest - obp_apr) %>%
  arrange(desc(change)) %>%
  select(Name, opps_apr, obp_apr, obp_rest, change) %>%
  head(5) %>%
  print()

# ---- 5. Does April walk rate predict rest-of-season OBP? ------
p2 <- ggplot(obp, aes(x = bb_rate_apr, y = obp_rest)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, color = "#8FBCE6") +
  labs(
    title = "April walk rate vs. rest-of-season OBP",
    x = "April BB%", y = "Rest-of-season OBP"
  ) +
  theme_minimal()
print(p2)
ggsave("day2_bb_rate_vs_rest.png", p2, width = 7, height = 5, dpi = 150)

cat("\nCorrelation with rest-of-season OBP:\n")
cat("  April OBP:", round(cor(obp$obp_apr, obp$obp_rest), 2), "\n")
cat("  April BB%:", round(cor(obp$bb_rate_apr, obp$obp_rest), 2), "\n")
