# Load all the packages and data needed for all visualisation scripts

library(tidyverse)
library(qs2)
library(here)
library(janitor)
library(sf)

source(here("scripts/src/country_bboxes.R"))
country_bbox_data <- load_country_bbox_data(here("data/country_bbox_data.csv"))

assigned_farms <- file.path(prepdata_path, "assigned_farms_final.qs") %>% 
  qs_read() %>% 
  arrange(ISO3_Code)

GLW_ls <- list(
  "GLW_1.5" = 2018:2037,
  "GLW_2.0" = 2032:2051,
  "GLW_3.0" = 2055:2074,
  "GLW_4.0" = 2075:2094
)
GLW_labels <- c("GLW_1.5" = "1.5°C", "GLW_2.0" = "2°C", "GLW_3.0" = "3°C", "GLW_4.0" = "4°C")

report_theme <- function() {
  theme_classic(base_size = 10) +
    theme(
      # plot.title            = element_text(face = "bold", size = 14),
      # plot.subtitle         = element_text(size = 10, margin = margin(b = 6)),
      legend.text           = element_text(size = 9),
      legend.title          = element_text(size = 10),
      legend.margin         = margin(b = -4),
      panel.grid.major.y    = element_blank(),
      panel.grid.minor      = element_blank(),
      panel.grid.major.x    = element_line(colour = "grey92", linewidth = 0.4),
      axis.text.y           = element_text(colour = "grey25", size = 10),
      axis.title.x          = element_text(margin = margin(t = 6)),
      plot.margin           = margin(10, 15, 10, 10)
    )
  }

prod_change_theme <- function() {
  report_theme() +
    theme(
      legend.position       = "top",
      legend.justification  = "center",
    )
}

farm_map_theme <- function() {
  report_theme() +
    theme(
      legend.position       = "bottom",
      legend.justification  = "center",
    )
}

grid_map_theme <- function() {
  report_theme() +
    theme(
      legend.position       = "bottom",
      legend.justification  = "center",
      axis.text = element_blank(),
      axis.title = element_blank(),
      axis.ticks = element_blank()
    )
}

# Height (inches) for the dot-and-line GLW plots, scaled to the number of models on the y axis.
# `base` covers the title, legend and x axis; `min_height` stops 1-2 model plots looking squashed.
GLW_plot_height <- function(n_models, per_model = 0.7, base = 1.25, min_height = 2.5) {
  max(min_height, base + per_model * n_models)
}

models_pal <- c(
  tuna_ranch = "#6E3B5A",
  atlantic_salmon = "#B6DEFF",
  whiteleg_shrimp = "#4286F9",
  grouper = "#6E3B5A",
  tuna_full = "#FF16E5",
  rainbow_trout = "#FBCA00",
  tiger_prawn = "#FBCA00",
  european_seabass = "#26FF0D",
  mud_crab = "#B6DEFF",
  japanese_amberjack  = "#EC4042",
  seabream = "#0DB981",
  asian_seabass = "#26FF0D",
  drum_croaker = "#FF16E5",
  olive_flounder = "#FEDCC3",
  golden_pompano = "#B900FF",
  milkfish = "#FF72B2",
  nile_tilapia = "#FEDCC3"
)

models_labs <- c(
  tuna_ranch = "Tuna (ranched)",
  atlantic_salmon = "Atlantic salmon",
  whiteleg_shrimp = "Shrimp",
  grouper = "Grouper",
  tuna_full = "Tuna (full-cycle)",
  rainbow_trout = "Trout",
  tiger_prawn = "Prawns",
  european_seabass = "Temperate basses",
  japanese_amberjack = "Amberjack/Yellowtail",
  drum_croaker = "Drums/Croakers",
  seabream = "Breams",
  mud_crab = "Crabs",
  golden_pompano = "Pompano",
  nile_tilapia = "Tilapia",
  olive_flounder = "Flatfishes",
  asian_seabass = "Tropical/hybrid basses",
  milkfish = "Milkfish"
)

# Step 2: Create maps of the farm locations
source(here("scripts_for_outputs/01_map_of_farms.R"))

# Step 3: Collate country summary tables (farms per model, excluded farms, FAO production) into one csv per country
source(here("scripts_for_outputs/02_country_info.R"))

# Step 4: Dot-and-line plot of projected biomass change per model at each GLW
source(here("scripts_for_outputs/03_production_change.R"))

# Step 5: Dot-and-line plot of projected change in feed per unit biomass per model at each GLW
source(here("scripts_for_outputs/04_feed_per_biomass_change.R"))

# Step 6: Maps of change in habitat suitability at each GLW, per species and production-weighted
source(here("scripts_for_outputs/05_habitat_suitability_change.R"))

# Step 7: Tables of mean habitat suitability and % change at each GLW (whole EEZ and within 50 km of the coast)
source(here("scripts_for_outputs/06_habitat_suitability_change_stats.R"))
