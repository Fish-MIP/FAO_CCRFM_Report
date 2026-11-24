# FAO_CCRFM_Report
Repository for code and data outputs developed as part of the FAO project "Climate change risks to interconnected food production systems with a focus on fed mariculture".

For the main project repository, see [Fish-MIP/FAO_CC_Risks_to_Fed_Mariculture](https://github.com/Fish-MIP/FAO_CC_Risks_to_Fed_Mariculture).

## Repository structure

```
.
├── .Rprofile                 # Activates renv on startup
├── .renvignore               # Excludes data/ and plots/ subfolders from renv's dependency scan
├── renv.lock, renv/          # Package library lockfile and renv bootstrap
├── LICENSE
├── data/ 
│   ├── assigned_farms_final.qs            # Final farm locations (sf): ISO3 code, species model, production value
│   ├── assigned_farms_initial.qs          # Farm set before error-check exclusions
│   ├── farm_exclusion_decisions.xlsx      # Farms excluded after the production-run error check, with reasons
│   ├── FAO_production_data_with_models.qs # FAO production by country/species, mapped to species models
│   ├── EEZ_data_with_FAO_regions.qs       # EEZ polygons split by FAO region, keyed by ISO3 code
│   ├── country_bbox_data.csv              # Per-country bounding boxes
│   ├── land_polygons_plotting/            # Simplified land polygon per country
│   ├── coastal_polygons_plotting/         # 0.75-degree coastal zone per country
│   ├── coastal_zone_50kms/                # ~50 km coastal zone per country
│   ├── farm_production_consolidated/      # Consolidated farm production per country x model
│   └── habitat_suitability_decadal/       # Habitat suitability rasters
├── plots/
│   ├── farm_maps/                         # Outputs of 01_map_of_farms.R: Map_farms_EEZ_<ISO3>.png
│   ├── production_change/                 # Outputs of 03_production_change.R: production_change_GLW_<ISO3>.png
│   ├── feed_per_biomass_change/           # Outputs of 04_feed_per_biomass_change.R: feed_per_biomass_change_GLW_<ISO3>.png
│   ├── habitat_suitability_maps/          # Outputs of 05_habitat_suitability_change.R: HS_change_grid_<ISO3>[_p<i>of<n>].png
│   ├── global_production_change.png       # Output of 07_radial_plot_production.R
│   └── global_feed_required_change.png    # Output of 08_radial_plot_feed_per_biomass.R
├── tables/
│   ├── country_info_all.csv               # Output of 02_country_info.R
│   └── HS_change_stats_all.csv            # Output of 06_habitat_suitability_change_stats.R
└── scripts/
    ├── 00_globals.R
    ├── 01_map_of_farms.R
    ├── 02_country_info.R
    ├── 03_production_change.R
    ├── 04_feed_per_biomass_change.R
    ├── 05_habitat_suitability_change.R
    ├── 06_habitat_suitability_change_stats.R
    ├── 07_radial_plot_production.R
    ├── 08_radial_plot_feed_per_biomass.R
    └── src/
        ├── country_bboxes.R
        └── other_functions.R
```

The `habitat_suitability_decadal` rasters include decadal means (`MR_dec_<start>_<end>.tif`), the 2015–2024 reference period (`MR_ref_2015_2024.tif`) and each global warming level (`MR_GLW_<level>.tif`); only the reference and GLW layers are used by the scripts.

## Scripts

Scripts are numbered in the order they are intended to run. `00_globals.R` must be sourced first; scripts `01`–`08` are independent of one another but all assume the packages, data and helpers it loads are in the environment.

| Script | Description |
|---|--------------------------------------|
| `scripts/00_globals.R` | Loads packages required, sources both `src/` helper files, and loads the shared data for all other scripts. Defines some global variables and display functions for plots. |
| `scripts/01_map_of_farms.R` | For each country in `assigned_farms`, draws a map of farm locations coloured by species model over the country's land polygon and EEZ, cropped to the country bounding box. Handles countries straddling the antimeridian. Writes one PNG per country to `plots/farm_maps/`. |
| `scripts/02_country_info.R` | Builds a country-level summary table for report tables: number of assigned farms and mean production per model, farms excluded after the production error check (from `farm_exclusion_decisions.xlsx` and `assigned_farms_initial.qs`), and FAO-reported production (2015 onwards, from `FAO_production_data_with_models.qs`) with the share covered by modelled species. Writes `tables/country_info_all.csv`. |
| `scripts/03_production_change.R` | Dot-and-line plot of projected change in harvested biomass per species model at each GLW (median and IQR across farms), plus a production-weighted row for multi-model countries. Reads `data/farm_production_consolidated/`. Writes one PNG per country to `plots/production_change/`. |
| `scripts/04_feed_per_biomass_change.R` | Same layout as `03_production_change.R`, but for projected change in feed required per unit of harvested biomass. Writes one PNG per country to `plots/feed_per_biomass_change/`. |
| `scripts/05_habitat_suitability_change.R` | Maps of relative change in habitat suitability (HS) at each GLW versus the 2015–2024 reference period, faceted by species model (with farm markers) and including a production-weighted panel. Splits large grids across multiple pages using per-country page sizes (`HS_page_params`), and caps the colour scale at the 95th percentile of absolute change. Writes PNGs to `plots/habitat_suitability_maps/`. |
| `scripts/06_habitat_suitability_change_stats.R` | Summary statistics behind the HS maps: mean HS in the reference period and at each GLW, and percent change, per species model and production-weighted. Computed on the raw rasters for two zones per country: the whole EEZ and within ~50 km of the coast (`data/coastal_zone_50kms/`). Writes `tables/HS_change_stats_all.csv`. |
| `scripts/07_radial_plot_production.R` | Global radial (circular) bar chart of projected change in production-weighted harvested biomass per country, one panel per GLW. Writes `plots/global_production_change.png`. |
| `scripts/08_radial_plot_feed_per_biomass.R` | Global radial (circular) bar chart of projected change in production-weighted harvested biomass per country, one panel per GLW. Writes `plots/global_feed_required_change.png`. |
| `scripts/src/country_bboxes.R` | Helper functions for per-country bounding boxes keyed by ISO3 code: `load_country_bbox_data()` reads `data/country_bbox_data.csv` into a nested list; `bbox()`, `bbox_poly()` and `bbox_lims()` return the padded box as an `st_bbox`, polygon, or `coord_sf()` limits; `crosses_antimeridian()` and `shift_for_bbox()` handle countries straddling 180°; `label_point()` returns label anchors as sf points; `save_map()` saves a ggplot with a fixed panel size. Boxes come from Natural Earth 1:10m Admin 0 padded by ~100 km. |
| `scripts/src/other_functions.R` | Small shared helpers: NA-safe summary wrappers (`sumna()`, `meanna()`, etc.); `get_country_data()`, which reads consolidated production files and computes change in biomass and feed-per-biomass relative to 2025; `weighted_HS()`, a production-weighted mean of HS rasters; and `pct_limits()`, `pct_breaks()` and `scale_y_pct()` for rounded percentage axes. |

## Setup

The project uses [renv](https://rstudio.github.io/renv/). Open the project in R and run `renv::restore()` to install the packages recorded in `renv.lock`. All paths are resolved relative to the project root with `here()`
