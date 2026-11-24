# Map of assigned farm locations, coloured by species model, over the country's land polygon and dissolved EEZ outline. One png per country in `assigned_farms`.
# Requires scripts/00_globals.R to have been sourced (`assigned_farms`, `land_poly_files`, `models_pal`, `models_lab`, `farm_map_theme()`, bbox helpers).
# Reads:  data/EEZ_data_with_FAO_regions.qs, data/land_polygons_plotting/<ISO3>.qs
# Writes: plots/farm_maps/Map_farms_EEZ_<ISO3>.png

farm_map_dir <- here("plots/farm_maps")

# Dissolving the FAO-region pieces into one geometry per country fails under spherical (s2) geometry, so do the union planar and restore s2 afterwards.
sf_use_s2(FALSE)
EEZ_by_FAO_full <- here("data/EEZ_data_with_FAO_regions.qs") %>%
  qd_read() %>%
  st_transform(crs = 4326) %>%
  st_make_valid() %>% 
  group_by(ISO3_Code) %>% 
  summarise(.groups = "drop")
sf_use_s2(TRUE)

farm_location_map <- function(this_iso) {
  these_farms  <- assigned_farms %>% filter(ISO3_Code == this_iso)
  this_country <- unique(these_farms$country)

  # Hong Kong is the only region without its own ISO code - it will inherit China's
  this_eez <- if (this_iso == "HKG") {
    EEZ_by_FAO_full %>% filter(ISO3_Code == "CHN")
  } else {
    EEZ_by_FAO_full %>% filter(ISO3_Code == this_iso)
  }

  # Countries straddling 180° (e.g. FJI) need their data shifted to 0..360 to match the bbox
  these_farms <- shift_for_bbox(these_farms, this_iso)
  this_eez    <- shift_for_bbox(this_eez, this_iso, union = TRUE)
  this_land   <- land_poly_files %>%
    str_subset(paste0(this_iso, ".qs")) %>% 
    qs_read() %>%
    shift_for_bbox(this_iso)

  # Models present in this country, with a colour for each.
  models_here <- sort(unique(these_farms$model_name))
  country_pal <- models_pal[models_here]
  names(country_pal) <- models_here
  country_pal[is.na(country_pal)] <- "grey50"

  # `eez_layer` is drawn between the land and the farms so the border doesn't cover points
  p_eez <- ggplot() +
      geom_sf(data = this_land, fill = "grey85", colour = "grey55", linewidth = 0.2) +
      geom_sf(data = this_eez, fill = NA, colour = "grey30", linewidth = 0.4, linetype = "dotted") +
      geom_sf(data = these_farms, aes(colour = model_name), size = 1.5) +
      scale_colour_manual(values = country_pal, labels = models_lab) +
      do.call(coord_sf, bbox_lims(this_iso)) +
      farm_map_theme()

  ggsave(
    filename = file.path(farm_map_dir, paste0("Map_farms_EEZ_", this_iso, ".png")),
    plot = p_eez, 
    width = 16.5, 
    height = 16.5, 
    units = "cm",
    dpi = 300, 
    bg = "white"
  )
}

walk(unique(assigned_farms$ISO3_Code), farm_location_map, .progress = T)
