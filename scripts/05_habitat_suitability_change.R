# Grid maps of relative change in habitat suitability (HS) at each global warming level (GLW) vs the 2015-2024 reference period, for each country: GLWs across, species models down (with farm markers), with a production-weighted row first (no farm markers). Grids with many models are split across several pngs according to the per-country page size in `HS_page_params`.
# The colour scale is capped at the 95th percentile of |change|.
# Requires scripts/00_globals.R to have been sourced (`assigned_farms`, `GLW_ls`, `GLW_labels`, `HS_lyr_names`, `models_lab`, `report_theme()`, `weighted_HS()`, bbox helpers).
# Reads:  data/habitat_suitability_decadal/<ISO3>/<model>/MR_{ref_2015_2024,GLW_*}.tif
#         data/land_polygons_plotting/<ISO3>.qs, data/coastal_polygons_plotting/<ISO3>.qs
# Writes: plots/habitat_suitability_maps/HS_change_grid_<ISO3>[_p<i>of<n>].png

HS_out_dir <- here("plots/habitat_suitability_maps")

# ── Per-country page layout (cm) ──────────────────────────────────────────
# page_width  = width of the plot area in the report; always 4 panel columns (one per GLW), so it sets the panel size and hence figure height.
# page_height = usable height of the page; sets how many species rows fit on a page and therefore how many grid pngs are saved per country (including space for a caption).
# Portrait = 16 x 24.5, landscape = 24.5 x 16. Edit by hand as needed.
HS_page_params <- data.frame(ISO3_Code = unique(assigned_farms$ISO3_Code)) %>% 
  mutate(
    page_width = case_when(
      ISO3_Code == "CHL" ~ 14.0,
      T ~ 16.5
    ),
    page_height = case_when(
      ISO3_Code == "CHL" ~ 22.5,
      T ~ 21.9
    )
  )

# Vertical space (cm) taken by the GLW strip on top plus the legend underneath, and horizontal space taken by the left-hand panel strip and gaps between columns.
# Tune these if the saved pngs have too much / too little white space.
HS_overhead_h <- 2.75
HS_side_w     <- 0.75

# Shift a -180..180 raster to 0..360 (terra::rotate() only goes the other way)
shift_raster_360 <- function(r) {
  e <- ext(r)
  west <- crop(r, ext(-180, 0, e$ymin, e$ymax))
  east <- crop(r, ext(0, 180, e$ymin, e$ymax))
  ext(west) <- c(180, 360, e$ymin, e$ymax)
  merge(east, west)
}

# this_iso <- "NZL"
HS_change_maps <- function(this_iso) {
  pg <- filter(HS_page_params, ISO3_Code == this_iso)
  these_farms <- assigned_farms %>% filter(ISO3_Code == this_iso)
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

  # Simplified, validated land from data-prep-scripts/detailed_land.R; the full detailed_land_polys are far too heavy to shift or render for big countries
  land_file  <- here("data/land_polygons_plotting", paste0(this_iso, ".qs"))
  coast_file <- here("data/coastal_polygons_plotting", paste0(this_iso, ".qs"))
  if (!file.exists(land_file) || !file.exists(coast_file)) {
    stop(this_iso, ": missing plot land or coastal zone polygons")
  }

  # Countries straddling 180° (e.g. FJI) need everything shifted to 0..360 to match the bbox
  shift_raster <- crosses_antimeridian(this_iso)
  these_farms  <- shift_for_bbox(these_farms, this_iso)
  this_land    <- qs_read(land_file)  %>% shift_for_bbox(this_iso)
  coast_zone   <- qs_read(coast_file) %>% shift_for_bbox(this_iso)

  # One SpatRaster per species: layers = ref + each GLW, scaled to 0-1
  HS_rasts <- map(
    set_names(HS_models),
    function(m) {
      r <- rast(file.path(HS_path, m, paste0("MR_", HS_lyr_names, ".tif"))) / 365
      names(r) <- HS_lyr_names
      # if (shift_raster) r <- shift_raster_360(r)
      r
    }
  )

  # Relative change at each GLW vs the reference period
  HS_change <- map(HS_rasts, \(r) (r[[names(GLW_ls)]] - r[["ref_2015_2024"]]) / r[["ref_2015_2024"]])

  HS_weights <- these_farms %>%
    st_drop_geometry() %>%
    group_by(model_name) %>% 
    reframe(value = sumna(value)) %>%
    filter(model_name %in% HS_models)
  HS_weights <- set_names(HS_weights$value, HS_weights$model_name)[HS_models]
  HS_change_weighted <- weighted_HS(HS_change, HS_weights)

  # Long-format change values for every panel (weighted mean first).
  # Used for the grid plot and for the colour limit shared by all plots.
  panels       <- c(list(weighted = HS_change_weighted), HS_change)
  panel_labels <- c(weighted = "Production-weighted", models_lab[HS_models])
  change_df <- imap(panels, \(r, nm) {
    r %>% 
      as.data.frame(xy = TRUE, na.rm = FALSE) %>%
      pivot_longer(all_of(names(GLW_ls)), names_to = "lyr", values_to = "change") %>%
      filter(!is.na(change)) %>%
      mutate(panel = nm)
  }) %>%
    list_rbind() %>%
    mutate(panel = factor(panel, levels = names(panels)))

  # Colour limits are capped at the 95th percentile of |change| across all species and GLWs: a few cells with near-zero reference HS have huge relative changes (>10000%) that would otherwise flatten the colour scale. Values beyond the cap are squished to the end colours rather than dropped.
  cap_prob <- 0.95
  lim <- quantile(abs(change_df$change), probs = cap_prob, names = FALSE)

  # Reversed so blue = increase, red = decrease
  HS_change_fill <- scale_fill_gradientn(
    limits = c(-lim, lim), colours = rev(cmocean("balance")(256)),
    labels = scales::label_percent(), na.value = "transparent",
    oob = scales::squish, name = "Change in habitat suitability"
  )

  # A page of the grid figure: GLWs across, `which_panels` down (weighted mean first on page 1)
  plot_HS_change_grid <- function(which_panels) {
    # No `weighted` level in the farm data, so the weighted row gets no markers
    farm_pts <- these_farms %>%
      filter(model_name %in% which_panels) %>%
      mutate(panel = factor(model_name, levels = names(panels)))

    ggplot() +
      geom_raster(data = filter(change_df, panel %in% which_panels), aes(x, y, fill = change)) +
      geom_sf(data = this_land, fill = "grey85", colour = "grey55", linewidth = 0.2) +
      geom_sf(data = farm_pts, shape = 4, size = 0.7) +
      facet_grid(panel ~ lyr, labeller = labeller(panel = panel_labels, lyr = GLW_labels)) +
      HS_change_fill +
      do.call(coord_sf, bbox_lims(this_iso)) +
      labs(x = NULL, y = NULL) +
      grid_map_theme()
  }

  # ── Figure sizing (cm) ────────────────────────────────────────────────────
  # Every figure is page_width wide with 4 panel columns, so the row height follows from the map aspect ratio and all panels come out the same size.
  lims    <- bbox_lims(this_iso)
  aspect  <- diff(lims$ylim) / (diff(lims$xlim) * cos(mean(lims$ylim) * pi / 180))
  row_h   <- if (this_iso %in% c("MYS", "IDN")) {((pg$page_width - HS_side_w) / 3.75) * aspect} else {((pg$page_width - HS_side_w) / 4) * aspect}
  fig_h   <- function(n_rows) {HS_overhead_h + (n_rows * row_h)}

  row_panels   <- if (length(HS_models) == 1) {HS_models} else {names(panels)}
  n_total      <- length(row_panels)

  if (n_total %in% 1:3) {
    # If there's only one or two models, height considerations are irrelevant
    ggsave(
      filename = file.path(HS_out_dir, paste0("HS_change_grid_", this_iso, ".png")),
      plot = plot_HS_change_grid(row_panels), 
      width = pg$page_width, 
      height = fig_h(n_total), 
      units = "cm",
      dpi = 300, 
      bg = "white"
    )

  } else {
    # If there's more, need to decide how many panels to output
    rows_per_page <- max(1, floor((pg$page_height - HS_overhead_h) / row_h))
    n_pages       <- ceiling(n_total / rows_per_page)

    page_sizes <- n_total %/% n_pages + (seq_len(n_pages) <= n_total %% n_pages)
    pages      <- split(row_panels, rep(seq_len(n_pages), page_sizes))


    for (i in seq_along(pages)) {
      n_rows_i <- length(pages[[i]])
      ggsave(
        filename = file.path(HS_out_dir, paste0("HS_change_grid_", this_iso, paste0("_p", i, "of", length(pages)), ".png")),
        plot = plot_HS_change_grid(pages[[i]]), 
        width = pg$page_width, 
        height = fig_h(n_rows_i), 
        units = "cm",
        dpi = 300, 
        bg = "white"
      )
    }
  }  
}

walk(unique(assigned_farms$ISO3_Code), HS_change_maps, .progress = T)

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
