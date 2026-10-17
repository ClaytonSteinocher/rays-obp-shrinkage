# ============================================================
# Spatial add-on: Was it luck or skill?
# Spray charts of every ball in play for Carson Kelly (the model's
# biggest correct call) and Aaron Judge (its failure case),
# April vs. May-Sept 2025, plus expected stats from Statcast.
#
# Input:  obp_2025_preds.csv (for each player's Baseball-Reference ID)
# Output: day5_spray_kelly_judge.png, day5_luck_vs_skill.csv
# ============================================================

library(tidyverse)
library(baseballr)

players <- c("Carson Kelly", "Aaron Judge")

# ---- 1. Look up each player's MLBAM ID (Statcast's player ID) ----
obp <- read_csv("obp_2025_preds.csv", show_col_types = FALSE)

get_mlbam <- function(bbref_id) {
  lu <- playername_lookup(bbref_id)
  as.numeric(lu[[grep("mlbam", names(lu), value = TRUE)[1]]][1])
}

ids <- obp %>%
  filter(Name %in% players) %>%
  select(Name, bbref_id) %>%
  mutate(mlbam = map_dbl(bbref_id, get_mlbam))
print(ids)
# If an mlbam value is NA: find the player on baseballsavant.mlb.com;
# the number at the end of his page's URL is the MLBAM ID. Enter it by hand.

# ---- 2. Pull every ball in play for the 2025 regular season ------
pull_bip <- function(name, id) {
  statcast_search_batters(start_date = "2025-03-18", end_date = "2025-09-28",
                          batterid = id) %>%
    filter(game_type == "R", type == "X", !is.na(hc_x)) %>%   # X = ball in play
    mutate(Name = name)
}
bip <- map2_dfr(ids$Name, ids$mlbam, pull_bip)

# ---- 3. Convert Statcast hit coordinates to feet from home plate ---
# Standard transform: home plate at (0, 0), +y toward center field,
# +x toward right field. Spray angle: 0 = straightaway center.
bip <- bip %>%
  mutate(
    period = factor(if_else(game_date <= as.Date("2025-04-30"), "April", "May-Sept"),
                    levels = c("April", "May-Sept")),
    x = 2.5 * (hc_x - 125.42),
    y = 2.5 * (198.27 - hc_y),
    spray_angle = atan2(x, y) * 180 / pi,
    hit = events %in% c("single", "double", "triple", "home_run"),
    result = factor(if_else(hit, "Hit", "Out"), levels = c("Hit", "Out")),
    pulled = if_else(stand == "R", spray_angle < -15, spray_angle > 15)
  )

# ---- 4. Luck vs. skill table ---------------------------------------
# hit_rate = share of balls in play that became hits (including HR)
# xba      = Statcast's expected average from exit velocity + launch angle
# luck_gap = hit_rate - xba; a big positive gap = hits the contact didn't earn
luck <- bip %>%
  group_by(Name, period) %>%
  summarise(
    balls_in_play = n(),
    hit_rate = mean(hit),
    xba      = mean(estimated_ba_using_speedangle, na.rm = TRUE),
    luck_gap = hit_rate - xba,
    avg_exit_velo = mean(launch_speed, na.rm = TRUE),
    hard_hit_pct  = mean(launch_speed >= 95, na.rm = TRUE),
    pull_pct      = mean(pulled, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(across(c(hit_rate, xba, luck_gap), ~ round(.x, 3)),
         across(c(avg_exit_velo), ~ round(.x, 1)),
         across(c(hard_hit_pct, pull_pct), ~ round(.x, 2)))

print(luck, width = Inf)
write_csv(luck, "day5_luck_vs_skill.csv")

# ---- 5. Spray chart ----------------------------------------------
# Simple field outline: foul lines, infield diamond, and an outfield
# fence that runs ~330 ft down the lines to ~400 ft in center.
theta <- seq(-45, 45, length.out = 100) * pi / 180
fence <- tibble(r = 330 + 70 * cos(2 * theta), x = r * sin(theta), y = r * cos(theta))
foul  <- tibble(x = c(-233, 0, 233), y = c(233, 0, 233))
diamond <- tibble(x = c(0, 63.6, 0, -63.6, 0), y = c(0, 63.6, 127.3, 63.6, 0))

labels <- luck %>%
  mutate(label = sprintf("Hit rate %.3f | xBA %.3f", hit_rate, xba))

spray <- ggplot(bip, aes(x, y)) +
  geom_path(data = fence, color = "grey60") +
  geom_path(data = foul, color = "grey60") +
  geom_path(data = diamond, color = "grey75") +
  geom_point(aes(color = result, shape = result), size = 1.8, alpha = 0.8) +
  geom_text(data = labels, aes(x = 0, y = -40, label = label),
            inherit.aes = FALSE, size = 3) +
  scale_color_manual(values = c(Hit = "#F5D130", Out = "#092C5C")) +
  scale_shape_manual(values = c(Hit = 17, Out = 16)) +
  facet_grid(Name ~ period) +
  coord_fixed(xlim = c(-260, 260), ylim = c(-60, 470)) +
  labs(title = "Luck or skill? Every ball in play, April vs. rest of season (2025)",
       subtitle = "Hit rate on contact vs. Statcast expected average (xBA) from exit velocity and launch angle",
       color = NULL, shape = NULL) +
  theme_void() +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold", size = 11),
        plot.title = element_text(face = "bold"),
        plot.margin = margin(10, 10, 10, 10))
print(spray)
ggsave("day5_spray_kelly_judge.png", spray, width = 9, height = 9, dpi = 150, bg = "white")

cat("\nSaved day5_spray_kelly_judge.png and day5_luck_vs_skill.csv\n")
