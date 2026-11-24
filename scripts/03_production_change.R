# Dot-and-line plot of projected change in harvested biomass per model at each global warming level (GLW), one png per focus country. Assumes scripts_for_outputs/00_run_all.R has already been run (provides `assigned_farms`, `focus_countries`, `GLW_ls`, `GLW_labels`, and paths from src/dirs.R).

prod_plot_dir <- here("plots/production_change")

# this_iso <- unique(assigned_farms$ISO3_Code)[4]
production_change_plot <- function(this_iso) {
  these_farms <- assigned_farms %>%
    st_drop_geometry() %>%
    filter(ISO3_Code == this_iso)

  cons_data_files <- here("data/farm_production_consolidated", paste0(this_iso, "_", unique(these_farms$model_name), ".qs"))
  missing <- cons_data_files[!file.exists(cons_data_files)]
  if (length(missing) > 0) {
    stop(this_iso, ": no consolidated production file for ", paste(basename(missing), collapse = ", "))
  }
  if (length(cons_data_files) == 0) {
    stop(this_iso, ": no production data, skipping plot")
  }

  farm_data <- get_country_data(cons_data_files) %>%
    semi_join(these_farms, by = join_by(farm_ID))

  # Models ordered by total 2025 biomass, largest first
  model_order <- farm_data %>%
    group_by(model_name) %>%
    reframe(biomass_2025 = sumna(biomass_2025)) %>%
    arrange(-biomass_2025) %>%
    pull(model_name)

  # Mean change per farm within each GLW window, then median + IQR across farms per model
  plt_data <- map2_dfr(
    GLW_ls, names(GLW_ls),
    function(yrs, nm) {
      farm_data %>%
        filter(year %in% yrs) %>%
        group_by(farm_ID, model_name) %>%
        reframe(biomass_change_pct = mean(biomass_change_pct, na.rm = T)) %>%
        mutate(GLW = nm)
    }
  ) %>%
    mutate(GLW = factor(GLW, levels = names(GLW_labels), labels = GLW_labels)) %>%
    group_by(model_name, GLW) %>%
    reframe(
      median = median(biomass_change_pct, na.rm = T),
      q25 = quantile(biomass_change_pct, 0.25, na.rm = T),
      q75 = quantile(biomass_change_pct, 0.75, na.rm = T)
    )

  # Production-weighted row (top of plot): each model's median/IQR averaged by its share of current production (`value`), matching the weighted HS maps. Omitted for single-model countries.
  if (length(model_order) > 1) {
    prod_w <- these_farms %>% 
      group_by(model_name) %>%
      reframe(value = meanna(value)) %>% 
      filter(model_name %in% model_order)
    plt_data <- plt_data %>%
      inner_join(prod_w, by = "model_name") %>%
      group_by(GLW) %>%
      reframe(across(c(median, q25, q75), \(x) weighted.mean(x, value, na.rm = TRUE))) %>%
      mutate(model_name = "weighted") %>%
      bind_rows(plt_data, .)
    model_order <- c("weighted", model_order)
  }
  row_labels <- c(weighted = "Production-weighted", models_lab)

  plt_data <- plt_data %>%
    mutate(
      model_name = factor(model_name, levels = rev(model_order)),
      y = as.numeric(model_name) + GLW_offsets[as.character(GLW)]
    )

  plt_limits <- pct_limits(c(plt_data$q25, plt_data$q75))
  plt_breaks <- pct_breaks(c(plt_data$q25, plt_data$q75))

  p <- plt_data %>%
    ggplot(aes(x = y, y = median, colour = GLW)) +
    geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.5, linetype = "dashed") +
    geom_segment(aes(y = q25, yend = q75), linewidth = 0.8) +
    geom_point(aes(y = median), size = 2.3) +
    scale_colour_manual(values = GLW_cols, name = "Global warming level: ") +
    scale_y_continuous(
      breaks = plt_breaks,
      labels = scales::label_percent(),
      limits = plt_limits,
      expand = expansion(0)
    ) +
    scale_x_continuous(
      breaks = seq_along(rev(model_order)),
      labels = row_labels[rev(model_order)],
      expand = expansion(add = 0.5)
    ) +
    coord_flip() +
    labs(
      # title = paste0("Projected change in harvested biomass: ", country_info(this_iso)$name, " (", this_iso, ")"),
      y = "Projected change (%)",
      x = NULL
    ) +
    guides(colour = guide_legend(override.aes = list(linewidth = 0, size = 3))) +
    prod_change_theme()

  ggsave(
    filename = file.path(prod_plot_dir, paste0("production_change_GLW_", this_iso, ".png")),
    plot = p, 
    width = 16.5, 
    height = GLW_plot_height(length(model_order)), 
    units = "cm",
    dpi = 300, 
    bg = "white"
  )
}

walk(unique(assigned_farms$ISO3_Code), production_change_plot, .progress = T)

# For troubleshooting ------------------------------------------------------------------------------------
# Capture warnings and isolate the ISOs they're coming from
# iso_warnings <- map(set_names(unique(assigned_farms$ISO3_Code)), function(iso) {
#   w <- character()
#   withCallingHandlers(
#     production_change_plot(iso),
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
