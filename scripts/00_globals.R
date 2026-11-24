# Load all the packages and data needed for all visualisation scripts

library(tidyverse)
library(terra)
library(qs2)
library(here)
library(janitor)
library(sf)
library(readxl)
library(tidyterra)
library(cmocean)

source(here("scripts/src/other_functions.R"))

source(here("scripts/src/country_bboxes.R"))
country_bbox_data <- load_country_bbox_data(here("data/country_bbox_data.csv"))

land_poly_files <- here("data/land_polygons_plotting") %>% 
  list.files(full.names = T)

assigned_farms <- here("data/assigned_farms_final.qs") %>% 
  qs_read() %>% 
  arrange(ISO3_Code)

GLW_ls       <- list("GLW_1.5" = 2018:2037,   "GLW_2.0" = 2032:2051,   "GLW_3.0" = 2055:2074,  "GLW_4.0" = 2075:2094)
GLW_labels   <- c(   "GLW_1.5" = "1.5°C",     "GLW_2.0" = "2°C",       "GLW_3.0" = "3°C",      "GLW_4.0" = "4°C")
GLW_cols     <- c(   "1.5°C"   = "#E9A23B", "2°C"     = "#DB5F32", "3°C"    = "#B3243B", "4°C" = "#5C0F2E")
GLW_offsets  <- c(   "1.5°C"   = -0.24,       "2°C"     = -0.08,       "3°C"     = 0.08,       "4°C" = 0.24)
HS_lyr_names <- c("ref_2015_2024", names(GLW_ls))

report_theme <- function() {
  theme_classic(base_size = 10) +
    theme(
      text = element_text(family = "serif", colour = "black"),
      # plot.title            = element_text(face = "bold", size = 14),
      # plot.subtitle         = element_text(size = 10, margin = margin(b = 6)),
      legend.text           = element_text(),
      legend.title          = element_text(),
      legend.margin         = margin(b = -4),
      panel.grid.major.y    = element_blank(),
      panel.grid.minor      = element_blank(),
      panel.grid.major.x    = element_line(colour = "grey92", linewidth = 0.4),
      axis.text.y           = element_text(),
      axis.title.x          = element_text(margin = margin(t = 6), vjust = 1.5),
      axis.title.y          = element_text(vjust = 1.5),
      plot.margin           = margin(t = 0.5, r = 0.5, b = 0, l = 0.5, unit = "cm")
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
      legend.title = element_blank(),
      axis.title = element_blank()
    )
}

grid_map_theme <- function() {
  report_theme() +
    theme(
      legend.position       = "bottom",
      legend.title.position = "top",
      legend.title          = element_text(size = 7, hjust = 0.5),
      legend.text           = element_text(size = 4.5),
      legend.justification  = "center",
      legend.key.width      = unit(3.5, "lines"),
      legend.frame          = element_rect(colour = "black"),
      legend.ticks          = element_line(colour = "black"),
      legend.ticks.length   = unit(0.3, "lines"),
      axis.text             = element_blank(),
      axis.text.y           = element_blank(),
      axis.text.x           = element_blank(),
      axis.title            = element_blank(),
      axis.line             = element_blank(),
      axis.ticks            = element_blank(),
      strip.text            = element_text(size = 6),
      strip.text.y.left     = element_text(angle = 90),
      strip.text.y          = element_text(angle = -90)
    )
}

# Height (cm) for the dot-and-line GLW plots, scaled to the number of models on the y axis. `base` covers the title, legend and x axis; `min_height` stops 1-2 model plots looking squashed.
GLW_plot_height <- function(n_models, per_model = 1.75, base = 3.25, min_height = 6) {
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

models_lab <- c(
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
