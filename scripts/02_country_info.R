# Country-level summary table for the report: assigned farms and mean production per model, farms excluded after the production-run error check, and FAO-reported production (2015 onwards) with the share covered by modelled species. All countries are combined into a single csv.
# Requires scripts/00_globals.R to have been sourced (`assigned_farms`, `models_lab`, bbox helpers for `country_info()`).
# Reads:  data/assigned_farms_initial.qs, data/farm_exclusion_decisions.xlsx, data/FAO_production_data_with_models.qs
# Writes: tables/country_info_all.csv

# Farms excluded after the production run error check. These are no longer in `assigned_farms` (the final set), so map farm_ID -> ISO via the pre-exclusion file.
farm_iso_lookup <- here("data/assigned_farms_initial.qs") %>%
  qs_read() %>%
  st_drop_geometry() %>%
  distinct(farm_ID, ISO3_Code)

excluded_farms <- here("data/farm_exclusion_decisions.xlsx") %>%
  read_excel() %>%
  filter(Conclusion == "Exclude") %>%
  mutate(farm_ID = as.numeric(farmID)) %>%
  left_join(farm_iso_lookup, by = join_by(farm_ID))

country_summary <- function(iso, path = here("data/FAO_production_data_with_models.qs"), digits = 1) {
  d <- path %>% 
    qs_read() %>% 
    filter(period >= 2015 & ISO3_Code == iso) %>%
    mutate(model_name = case_when(
      model_name == "tuna" & ISO3_Code == "JPN" ~ "tuna_full",
      model_name == "tuna" & ISO3_Code != "JPN" ~ "tuna_ranch",
      is.na(model_name) ~ paste0("no_model_assigned_", species_name),
      TRUE ~ model_name
    )) %>% 
    group_by(ISO3_Code, country, model_name, Scientific_Name) %>% 
    reframe(
      value = sum(value),
      years = n_distinct(period)
    ) %>% 
    mutate(value = units::drop_units(value/years)) %>% 
    filter(value != 0) %>% 
    dplyr::select(-years)

  if (nrow(d) == 0) stop("No rows found for ISO3_Code '", iso, "'")

  total <- sum(d$value, na.rm = TRUE)

  # % of country total per model
  models <- d |>
    summarise(value = sum(value, na.rm = TRUE), .by = model_name) |>
    mutate(pct = 100 * value / total) |>
    arrange(desc(value))

  # % within each model per species
  species <- d |>
    summarise(value = sum(value, na.rm = TRUE), .by = c(model_name, Scientific_Name)) |>
    mutate(pct = 100 * value / sum(value), .by = model_name) |>
    arrange(model_name, desc(value))

  fmt_t <- \(x) format(round(x), big.mark = ",", trim = TRUE)
  fmt_p <- \(x) sprintf("%.*f%%", digits, x)

  cat(sprintf("%s (%s)\n", d$country[1], iso))
  cat(sprintf("Total annual production (2015-): %s t\n", fmt_t(total)))
  cat(sprintf("Number of models: %d\n", nrow(models)))

  for (i in seq_len(nrow(models))) {
    m <- models$model_name[i]
    cat(sprintf("\n  %s: %s t (%s of country total)\n",
                m, fmt_t(models$value[i]), fmt_p(models$pct[i])))

    sp <- filter(species, model_name == m)
    cat(sprintf("    - %s: %s t (%s of model)\n",
                sp$Scientific_Name, fmt_t(sp$value), fmt_p(sp$pct)), sep = "")
  }

  invisible(list(total = total, models = models, species = species))
}

country_info_table <- function(this_iso) {
  these_farms <- assigned_farms %>%
    st_drop_geometry() %>%
    filter(ISO3_Code == this_iso)
  models_here <- sort(unique(these_farms$model_name))

  # FAO reports "tuna", but farms are assigned "tuna_full" (JPN) or "tuna_ranch" (elsewhere)
  is_included <- function(m) {
    m %in% models_here | (m == "tuna" & any(str_starts(models_here, "tuna_")))
  }

  # 1. Assigned farms per model and the production each model represents
  farms_per_model <- these_farms %>%
    group_by(model_name) %>%
    reframe(
      n_farms = n(),
      production_perfarm_t = mean(prod_perfarm, na.rm = T)
    ) %>%
    arrange(desc(n_farms))

  # 2. Farms excluded due to fatal production run errors
  failed_farms <- excluded_farms %>%
    filter(ISO3_Code == this_iso) %>%
    group_by(model_name) %>%
    summarise(
      farms_excl = n(),
      reasons = paste(unique(reason), collapse = "; "),
      .groups = "drop"
    )
  
  # Join to the farms per model table
  farms_per_model <- farms_per_model %>% 
    left_join(failed_farms, by = join_by(model_name)) %>% 
    mutate(model_name = case_when(model_name %in% c("tuna_full", "tuna_ranch") ~ "tuna", T ~ model_name))

  # 3 & 4. FAO-reported production (2015-2024 mean): country total with the share covered by included models, and by species within model. country_summary() prints to the console; keep only its return value.
  fao <- tryCatch(
    {
      invisible(capture.output(res <- country_summary(this_iso)))
      res
    },
    error = function(e) NULL
  )

  fao_country <- if (is.null(fao)) tibble() else fao$models %>%
    reframe(
      production_t = sum(value),
      pct_included = 100 * sum(value[is_included(model_name)]) / sum(value)
    ) %>%
    mutate(model_name = "ALL", included = TRUE)

  fao_species <- if (is.null(fao)) tibble() else fao$species %>%
    transmute(
      model_name,
      species = Scientific_Name,
      production_t = value,
      pct_of_model = pct,
      included = is_included(model_name)
    )

  out <- bind_rows(fao_country, fao_species) %>%
    left_join(farms_per_model, by = join_by(model_name), all) %>% 
    mutate(
      ISO3_Code = this_iso,
      country = country_info(this_iso)$name,
      across(where(is.numeric), \(x) round(x, 1))
    )
  
  m_order <- out %>% arrange(-production_t) %>% pull(model_name)

  out %>% 
    arrange(
      -included, 
      match(model_name, m_order), 
      -pct_of_model
    )
}

map_dfr(unique(assigned_farms$ISO3_Code), country_info_table, .progress = T) %>% 
  relocate(country, .before = production_t) %>% 
  relocate(ISO3_Code, .before = country) %>% 
  write.csv(here("tables/country_info_all.csv"), na = "", row.names = FALSE)
