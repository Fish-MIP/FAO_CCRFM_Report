# Summary statistics of habitat suitability (HS) for each country: mean HS in the reference period (2015-2024) and at each global warming level (GLW), plus the % change from the reference period, per species model and production-weighted. All countries are combined into a single csv.
# Two zones per country:
#   - "EEZ":          every cell of the country's HS rasters
#   - "coastal_50km": sea cells within ~50 km of the country's coastline, using the precomputed polygons in data/coastal_zone_50kms. Those are a 62.5 km buffer (50 km + half a 0.25-degree cell) around the detailed land polygons, so cells whose edge touches the 50 km zone but whose centre does not are still included. Cells near other countries' coasts are excluded.
# Stats are calculated on the raw rasters (no coastal gap-filling, which extrapolates).
# Requires scripts/00_globals.R to have been sourced (`assigned_farms`, `GLW_ls`, `HS_lyr_names`, `weighted_HS()`, bbox helpers for `country_info()`).
# Reads:  data/habitat_suitability_decadal/<ISO3>/<model>/MR_{ref_2015_2024,GLW_*}.tif, data/coastal_zone_50kms/<ISO3>.qs
# Writes: tables/HS_change_stats_all.csv

# Mean HS per period for each species raster plus the production-weighted stack, and the % change from the reference period. One row per model, wide by period.
summarise_HS <- function(rasts, weighted) {
  map2_dfr(
    c(rasts, list(production_weighted = weighted)),
    c(names(rasts), "production_weighted"),
    function(r, nm) {
      global(r, "mean", na.rm = TRUE) %>%
        rownames_to_column("period") %>%
        mutate(model_name = nm)
    }
  ) %>%
    rename(mean_HS = mean) %>%
    group_by(model_name) %>%
    mutate(
      change_pct = 100 * (mean_HS - mean_HS[period == "ref_2015_2024"]) / mean_HS[period == "ref_2015_2024"]
    ) %>%
    ungroup() %>%
    pivot_wider(
      id_cols = model_name,
      names_from = period,
      values_from = c(mean_HS, change_pct),
      names_glue = "{.value}_{period}"
    ) %>%
    dplyr::select(-change_pct_ref_2015_2024)
}

# this_iso <- unique(assigned_farms$ISO3_Code)[1]
HS_change_stats <- function(this_iso) {
  these_farms <- assigned_farms %>%
    st_drop_geometry() %>%
    filter(ISO3_Code == this_iso)
  models_here <- sort(unique(these_farms$model_name))

  # Species farmed here that have a complete set of HS rasters (ref + every GLW)
  HS_path   <- here("data/habitat_suitability_decadal", this_iso)
  HS_models <- keep(models_here, \(m) {
    all(file.exists(file.path(HS_path, m, paste0("MR_", HS_lyr_names, ".tif"))))
  })
  if (length(HS_models) == 0) {
    stop(this_iso, ": no habitat suitability rasters")
  }
  no_HS <- setdiff(models_here, HS_models)
  if (length(no_HS) > 0) {
    stop(this_iso, ": no complete HS rasters for ", paste(no_HS, collapse = ", "))
  }

  # One SpatRaster per species: layers = ref + each GLW, scaled to 0-1
  HS_rasts <- map(
    HS_models,
    function(m) {
      r <- rast(file.path(HS_path, m, paste0("MR_", HS_lyr_names, ".tif"))) / 365
      names(r) <- HS_lyr_names
      r
    }
  ) %>% setNames(HS_models)

  HS_weights <- these_farms %>%
    group_by(model_name) %>% 
    mutate(value = sumna(value)) %>%
    filter(model_name %in% HS_models)
  HS_weights  <- set_names(HS_weights$value, HS_weights$model_name)[HS_models]
  HS_weighted <- weighted_HS(HS_rasts, HS_weights)

  # 1. Whole EEZ
  eez_stats <- summarise_HS(HS_rasts, HS_weighted) %>%
    mutate(zone = "EEZ")

  # 2. Within ~50 km of this country's coast
  coast_file <- here("data/coastal_zone_50kms", paste0(this_iso, ".qs"))
  coastal_stats <- if (!file.exists(coast_file)) {
    stop(this_iso, ": no coastal_zone_50 polygon found, coastal stats not calculated")
  } else {
    # terra::mask() needs a SpatVector, not an sf/sfc object
    coast_zone <- qs_read(coast_file) %>%
      vect() %>%
      project(crs(HS_weighted))

    summarise_HS(
      map(HS_rasts, \(r) mask(r, coast_zone)),
      mask(HS_weighted, coast_zone)
    ) %>%
      mutate(zone = "coastal_50km")
  }

  out <- bind_rows(eez_stats, coastal_stats) %>%
    mutate(
      ISO3_Code = this_iso,
      country = country_info(this_iso)$name,
      production_weight = unname(HS_weights[model_name] / sum(HS_weights)),
      across(c(starts_with("mean_HS"), starts_with("change_pct")), \(x) round(x, 3))
    ) %>%
    dplyr::select(
      zone, ISO3_Code, country, model_name, production_weight,
      starts_with("mean_HS"), starts_with("change_pct")
    )
  
  out %>% 
    arrange(zone, -production_weight)
}

map_dfr(unique(assigned_farms$ISO3_Code), HS_change_stats, .progress = T) %>% 
  relocate(zone, .after = country) %>% 
  dplyr::select(-c("mean_HS_ref_2015_2024", "mean_HS_GLW_1.5", "mean_HS_GLW_2.0", "mean_HS_GLW_3.0", "mean_HS_GLW_4.0")) %>% 
  write.csv(here("tables/HS_change_stats_all.csv"), na = "", row.names = FALSE)

# For troubleshooting ------------------------------------------------------------------------------------
# Capture warnings and isolate the ISOs they're coming from
# iso_warnings <- map(set_names(unique(assigned_farms$ISO3_Code)), function(iso) {
#   w <- character()
#   withCallingHandlers(
#     HS_change_maps(iso),
#     warning = function(cnd) {
#       w <<- c(w, conditionMessage(cnd))
#       invokeRestart("muffleWarning")
#     }
#   )
#   w
# }, .progress = TRUE)

# iso_warnings |>
#   keep(\(x) length(x) > 0) |>
#   imap_dfr(\(w, iso) tibble(ISO = iso, warning = w)) |>
#   count(ISO, warning, sort = TRUE)
