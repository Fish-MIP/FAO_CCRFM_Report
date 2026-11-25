# FAO_CCRFM_Report

This repository contains summary data and code to produce the figures and tables included in the *Climate change risks to interconnected food production systems with a focus on fed mariculture* report prepared for the FAO.

For the main project repositories with full data analysis, see [Sustainable-Aquafeeds-Project/climate_risks_to_fed_mariculture](https://github.com/Sustainable-Aquafeeds-Project/climate_risks_to_fed_mariculture.git) and [Sustainable-Aquafeeds-Project/climate_risks_fed_food](https://github.com/Sustainable-Aquafeeds-Project/climate_risks_fed_food.git). 

## How to use this repository

All scripts included in this repository were developed in `R` version 4.3.0. Please ensure you have this `R` version or later installed in your computer. The project uses [renv](https://rstudio.github.io/renv/) for package version control. Open the project in R and run the following to install the correct versions of all required packages:

```R
> install.packages("renv")
> renv::restore()
```

Scripts within `scripts` are numbered in the order they are intended to run. `00_globals.R` must be sourced first; scripts `01`–`08` are independent of one another but all assume the packages, data and helper loaded by `00_globals.R` are in the environment.

## Accessing data

The raw data outputs are not stored on GitHub. To access them, please contact [Tormey Reimer](tormey.reimer@utas.edu.au) or [Julia Blanchard](julia.blanchard@utas.edu.au).

## Accessing supporting data

To produce the data and maps in this repository, we used the following publicly available datasets:  
- Exclusive Economic Zones (EEZs) boundaries (version 11) from the Flanders Marine Institute [[1]](#1)  
- Global basemaps and international boundaries from OpenStreetMap [[2]](#2)
- Global aquaculture production data (2015-2024) from the FAO [[3]](#3) 
- FAO statistical areas for fishery purposes [[4]](#4)

## Repository structure

```
.
├── .Rprofile
├── .renvignore
├── renv.lock, renv/
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

## References

<a id="1">[1]</a> 
Flanders Marine Institute. (2019). Maritime Boundaries Geodatabase: Maritime Boundaries and Exclusive Economic Zones (200NM), version 11. Available online at [https://www.marineregions.org/](https://www.marineregions.org/). [https://doi.org/10.14284/386](https://doi.org/10.14284/386).    
  
<a id="2">[2]</a> 
OpenStreetMap. (2026). Land Polygons [Data set]. https://osmdata.openstreetmap.de/

<a id="3">[3]</a> 
FAO. (2026). FishStat: Global Fishery and Aquaculture Statistics [Data set]. Fisheries and Aquaculture Division, Rome. https://www.fao.org/fishery/fishstat/en
  
<a id="4">[4]</a> 
FAO. (2020). FAO Statistical Areas for Fishery Purposes. In: FAO Fisheries and Aquaculture Department [online]. Rome. [http://www.fao.org/fishery/area/search/en](http://www.fao.org/fishery/area/search/en).  
