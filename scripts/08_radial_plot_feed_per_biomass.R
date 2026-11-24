# Radial bar chart of % change in feed required per unit biomass by EEZ, grouped by region, with one panel per scenario (GLW). 

# Get data
country_farms <- assigned_farms %>% 
  st_drop_geometry() %>% 
  distinct(ISO3_Code, farm_ID) %>% 
  mutate(farm_ID = as.integer(farm_ID))

country_regions <- assigned_farms %>% 
  st_drop_geometry() %>% 
  distinct(ISO3_Code, country) %>% 
  mutate(
    region = case_when(
      ISO3_Code %in% c("BHR", "BGD", "BRN", "KHM", "CHN", "CYP", "PRK", "GEO", "HKG", "IND", "IDN", "IRN", "ISR", "JPN", "KWT", "LBN", "MYS", "MDV", "MMR", "OMN", "PAK", "PSE", "PHL", "QAT", "KOR", "SAU", "SGP", "LKA", "TWN", "THA", "TLS", "TUR", "ARE", "VNM") ~ "Asia",
      ISO3_Code %in% c("ARG", "BLZ", "BRA", "CAN", "CHL", "COL", "CRI", "CUB", "DOM", "ECU", "SLV", "GLP", "GTM", "GUY", "HND", "MTQ", "MEX", "NIC", "PAN", "PER", "KNA", "SUR", "USA", "VEN") ~ "Americas",
      ISO3_Code %in% c("ALB", "HRV", "DNK", "EST", "FRO", "FIN", "FRA", "GRC", "ISL", "IRL", "ITA", "MLT", "MNE", "NOR", "PRT", "RUS", "ESP", "SWE", "GBR") ~ "Europe",
      ISO3_Code %in% c("DZA", "CPV", "EGY", "GHA", "KEN", "MDG", "MUS", "MYT", "MAR", "MOZ", "NGA", "REU", "SEN", "SYC", "ZAF", "TUN", "TZA") ~ "Africa",
      ISO3_Code %in% c("AUS", "FJI", "PYF", "GUM", "KIR", "NRU", "NCL", "NZL", "MNP", "PLW", "PNG", "WSM", "SLB", "TUV", "VUT") ~ "Oceania"
    ),
    # Use some abbreviations for some of the countries with very long names
    country = case_when(
      ISO3_Code == "PRK" ~ "D. P. R. Korea",
      ISO3_Code == "ARE" ~ "U. A. E.",
      ISO3_Code == "USA" ~ "U. S. A.",
      ISO3_Code == "TZA" ~ "U. R. Tanzania",
      ISO3_Code == "MNP" ~ "N. Mariana Islands",
      ISO3_Code == "KNA" ~ "St. Kitts and Nevis",
      T ~ country
    )
  )

farm_data <- here("data/farm_production_consolidated") %>% 
  list.files(pattern = ".qs", full.names = T) %>% 
  map_dfr(get_country_data) %>% 
  full_join(country_farms, by = join_by(farm_ID)) %>% 
  dplyr::select(-c(biomass_2025, feed_prov_per_biomass_2025))

# Mean change per farm within each GLW window, then mean across farms per model, per country
consolidated_data <- map2_dfr(
  GLW_ls, names(GLW_ls),
  function(yrs, nm) {
    farm_data %>%
      filter(year %in% yrs) %>%
      group_by(ISO3_Code, farm_ID, model_name) %>%
      reframe(
        biomass_change_pct = meanna(biomass_change_pct),
        feed_prov_biom_change_pct = meanna(feed_prov_biom_change_pct)
      ) %>%
      mutate(GLW = nm)
  }) %>%
  mutate(GLW = factor(GLW, levels = names(GLW_labels), labels = GLW_labels)) %>%
  group_by(ISO3_Code, model_name, GLW) %>%
  reframe(
    biomass_change_pct = meanna(biomass_change_pct),
    feed_prov_biom_change_pct = meanna(feed_prov_biom_change_pct)
  )

weight_info <- assigned_farms %>% 
  st_drop_geometry() %>% 
  group_by(ISO3_Code, model_name) %>% 
  reframe(value = meanna(value)) %>% 
  group_by(ISO3_Code) %>% 
  mutate(total_value = sumna(value)) %>% 
  ungroup() %>% 
  mutate(weight = value/total_value)

plt_data <- consolidated_data %>% 
  left_join(weight_info, by = join_by(ISO3_Code, model_name)) %>% 
  left_join(country_regions, by = join_by(ISO3_Code)) %>% 
  group_by(region, ISO3_Code, country, GLW) %>% 
  reframe(
    biomass_change_pct = weighted.mean(biomass_change_pct, w = weight),
    feed_prov_biom_change_pct = weighted.mean(feed_prov_biom_change_pct, w = weight)
  )

plot_radial <- function(df, var_name, rings, breaks,  bin_labels, bin_cols,
    sort_by    = NULL,     # scenario used to order EEZs within a region (default: last level)
    region_gap = 2,        # empty slots between regions
    hole       = 0.4,      # size of empty centre, as a fraction of the outer ring
    label_size = 1.5,
    facet_nrow = 2,         # layout of scenario panels
    panel_gap  = -4.5,        # spacing between panels in lines; negative lets the empty corners overlap
    cap        = NULL       # optional cap on |var_change|; capped bars are marked with an asterisk
) {
  df <- df %>%
    mutate(GLW      = factor(GLW),
           region   = factor(region),
           # colour bins use the uncapped signed change; only bar length is capped
           bin      = cut(var_change, breaks = breaks, labels = bin_labels, right = TRUE, include.lowest = TRUE),
           mag      = abs(var_change),
           capped   = !is.null(cap) & mag > cap,
           mag      = if (is.null(cap)) mag else pmin(mag, cap))

  GLW_levels  <- levels(df$GLW)
  n_scen      <- length(GLW_levels)
  if (is.null(sort_by)) sort_by <- GLW_levels[n_scen]

  # ---- angular positions: one slot per EEZ, gaps between regions ----------
  # The first gap (at 12 o'clock) holds the ring labels.
  eez_pos <- df %>%
    filter(GLW == sort_by) %>%
    arrange(region, var_change) %>%            # most negative first within region
    group_by(region) %>%
    mutate(i = row_number()) %>%
    ungroup() %>%
    mutate(r_idx = as.integer(region),
           x     = region_gap + (r_idx - 1) * region_gap + cumsum(rep(1, n()))) %>%
    dplyr::select(region, country, x)

  n_slots <- max(eez_pos$x) + region_gap / 2   # total slots around the circle
  plot_df <- df %>% 
    left_join(eez_pos, by = c("region", "country")) %>%
    mutate(xb = x, width = 0.9)

  # ---- geometry for labels ------------------------------------------------
  r_max   <- max(c(rings, plot_df$mag), na.rm = TRUE)
  y_hole  <- -hole * max(rings)
  y_lab   <- r_max * 1.08

  # text angle so labels radiate outward, flipped on the left half
  ang <- function(x) 90 - 360 * (x - 0.5) / n_slots
  name_lab <- eez_pos %>%
    mutate(angle = ang(x),
           left  = angle < -90,
           angle = if_else(left, angle + 180, angle),
           hjust = if_else(left, 1, 0))

  # region labels sit outside the country names, at the angular midpoint of each region
  y_region <- r_max * 1.85
  region_lab <- eez_pos %>%
    group_by(region) %>%
    summarise(x = mean(range(x)), .groups = "drop")

  # scenario label drawn in the centre of each panel (y_hole maps to the origin)
  scen_lab <- tibble(GLW = factor(GLW_levels, levels = GLW_levels), x = 1, y = y_hole)

  # plotmath %+-% gives a font-safe "±"
  ring_lab <- tibble(x = region_gap / 2 + 0.5, y = rings, lab = paste0("''%+-%'", round(rings * 100), "%'"))

  # ---- plot ---------------------------------------------------------------
  ggplot(plot_df) +
    geom_hline(yintercept = c(0, rings), colour = "grey85", linewidth = 0.3) +
    geom_tile(
      aes(x = xb, y = mag / 2, height = mag, width = width, fill = bin), 
      colour = "white", linewidth = 0.2
    ) +
    # asterisk just beyond the end of any capped bar
    geom_text(
      data = filter(plot_df, capped),
      aes(x = xb, y = mag * 1.03, label = "*"),
      size = label_size * 2, vjust = 0.8
    ) +
    geom_text(
      data = ring_lab, 
      aes(x = x, y = y, label = lab), 
      colour = "grey55", size = label_size, vjust = -0.3, parse = TRUE
    ) +
    geom_text(data = name_lab,
              aes(x = x, y = y_lab, label = country, angle = angle, hjust = hjust),
              size = label_size) +
    geom_text(data = region_lab, aes(x = x, y = y_region, label = region), size = label_size * 1.4, fontface = "bold") +
    geom_text(data = scen_lab, aes(x = x, y = y, label = GLW), size = label_size * 2, fontface = "bold") +
    scale_fill_manual(
      values = setNames(bin_cols, bin_labels),
      limits = bin_labels, drop = FALSE,
      name = var_name
    ) +
    guides(fill = guide_legend(nrow = 1, label.position = "bottom")) +
    scale_x_continuous(limits = c(0.5, n_slots + 0.5), expand = c(0, 0)) +
    # upper limit tracks y_region so region labels are never dropped as out-of-range
    scale_y_continuous(limits = c(y_hole, y_region * 1.05), expand = c(0, 0)) +
    coord_polar(clip = "off") +
    facet_wrap(~ GLW, nrow = facet_nrow) +
    radial_plot_theme() +
    theme(panel.spacing = unit(panel_gap, "lines"),
          plot.margin   = margin(0, 0, 0, 0))
}

p_feed_per_biomass <- plot_radial(
    df         = plt_data %>% rename(var_change = feed_prov_biom_change_pct),
    var_name   = "Change in production-weighted feed required per biomass (%)",
    rings      = c(0.025, 0.05, 0.1, 0.2),
    breaks     = c(-Inf, -0.15, -0.05, 0, 0.05, 0.15, Inf), # colour bins on signed change
    bin_labels = c("\u2212 >15%", "\u2212 5-15%", "\u2212 <5%", "+ <5%",    "+ 5-15%", "+ >15%"),
    bin_cols   = c("#1F2A5C",     "#3A9A9C",     "#CFE8B0",    "#EFA143", "#D9662A",  "#B03A0E"),
    # Chile's 3 and 4 degree values (~1.8 and ~2.8) dwarf all others (< 0.25); cap and mark with "*"
    cap        = 0.25
)

ggsave(
  plot = p_feed_per_biomass,
  filename = here("plots/global_feed_required_change.png"),
  width = 16.5,
  height = 22.5,
  units = "cm",
  dpi = 300
)
