# ============================================================
# Day 4: Evaluate and visualize
# Input:  obp_2025_preds.csv (from Day 3)
# Output: three charts (PNG) + player stories for the write-up
# ============================================================

library(tidyverse)

obp <- read_csv("obp_2025_preds.csv", show_col_types = FALSE)
league_avg <- weighted.mean(obp$obp_apr, obp$opps_apr)

rays_navy  <- "#092C5C"
rays_light <- "#8FBCE6"

# ---- Chart 1: Prediction error by method ---------------------
rmse <- function(pred) sqrt(mean((pred - obp$obp_rest)^2))

errors <- tibble(
  method = c("Raw April OBP", "League average", "Empirical Bayes",
             "brms hierarchical", "brms + April walk rate"),
  rmse = c(rmse(obp$obp_apr), rmse(rep(league_avg, nrow(obp))),
           rmse(obp$eb_est), rmse(obp$brms_est), rmse(obp$brms_bb_est))
) %>%
  mutate(method = fct_reorder(method, rmse, .desc = TRUE),
         best = rmse == min(rmse))

c1 <- ggplot(errors, aes(x = rmse, y = method, fill = best)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.4f", rmse)), hjust = -0.1, size = 3.5) +
  scale_fill_manual(values = c(`TRUE` = rays_navy, `FALSE` = rays_light), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Shrinkage cuts OBP prediction error by 40%",
       subtitle = "Error predicting May-Sept OBP from April, 2025 hitters (RMSE, lower is better)",
       x = "RMSE", y = NULL) +
  theme_minimal()
print(c1)
ggsave("day4_error_by_method.png", c1, width = 8, height = 4, dpi = 150)

# ---- Chart 2: Shrinkage shrinks as sample size grows -----------
# Arrow from raw April OBP to the model's estimate. Short samples
# get pulled hard toward league average; long ones barely move.
c2 <- ggplot(obp) +
  geom_hline(yintercept = league_avg, linetype = "dashed", color = "grey50") +
  geom_segment(aes(x = opps_apr, xend = opps_apr, y = obp_apr, yend = brms_est),
               arrow = arrow(length = unit(0.06, "inches")),
               color = rays_navy, alpha = 0.5) +
  geom_point(aes(x = opps_apr, y = obp_apr), color = rays_light, size = 1) +
  labs(title = "Small samples get pulled hardest toward league average",
       subtitle = "Each arrow: raw April OBP (dot) to model estimate (arrowhead); dashed = league average",
       x = "April plate appearances (OBP opportunities)", y = "OBP") +
  theme_minimal()
print(c2)
ggsave("day4_shrinkage_arrows.png", c2, width = 8, height = 5, dpi = 150)

# ---- Chart 3: Who truly gets on base? (the Moneyball list) ------
top15 <- obp %>%
  slice_max(brms_est, n = 15) %>%
  mutate(Name = fct_reorder(Name, brms_est))

c3 <- ggplot(top15, aes(y = Name)) +
  geom_segment(aes(x = brms_est, xend = obp_rest, yend = Name), color = "grey70") +
  geom_point(aes(x = obp_apr, color = "Raw April"), size = 2) +
  geom_point(aes(x = brms_est, color = "Model estimate (April only)"), size = 3) +
  geom_point(aes(x = obp_rest, color = "Actual May-Sept"), size = 2, shape = 17) +
  scale_color_manual(values = c("Raw April" = rays_light,
                                "Model estimate (April only)" = rays_navy,
                                "Actual May-Sept" = "#F5D130")) +
  labs(title = "Top 15 on-base hitters by model estimate after April",
       x = "OBP", y = NULL, color = NULL) +
  theme_minimal() +
  theme(legend.position = "bottom")
print(c3)
ggsave("day4_top15_true_obp.png", c3, width = 8, height = 6, dpi = 150)

# How many of the model's top 15 were still above average May-Sept?
hit_rate <- mean(top15$obp_rest > league_avg)
cat("Model's top 15: ", scales::percent(hit_rate),
    " finished May-Sept above league-average OBP\n", sep = "")

# Compare: top 15 by raw April OBP
raw_top15 <- obp %>% slice_max(obp_apr, n = 15)
cat("Raw April top 15: ", scales::percent(mean(raw_top15$obp_rest > league_avg)),
    " finished May-Sept above league-average OBP\n\n", sep = "")

# ---- Player stories: biggest moves by the model -----------------
cat("Biggest model corrections (candidates for your 3 player stories):\n")
obp %>%
  mutate(model_move = brms_est - obp_apr,
         model_err  = abs(brms_est - obp_rest),
         raw_err    = abs(obp_apr - obp_rest),
         model_closer = model_err < raw_err) %>%
  arrange(desc(abs(model_move))) %>%
  select(Name, opps_apr, obp_apr, brms_est, obp_rest, model_closer) %>%
  mutate(across(c(obp_apr, brms_est, obp_rest), ~ round(.x, 3))) %>%
  head(8) %>%
  print()

cat("\nShare of hitters where the model beat raw April:",
    scales::percent(mean(abs(obp$brms_est - obp$obp_rest) < abs(obp$obp_apr - obp$obp_rest))), "\n")
