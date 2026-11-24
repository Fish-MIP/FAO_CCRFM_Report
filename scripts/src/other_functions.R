# This script is a collection of random/helper functions that may be used by other scripts. They're just here so they don't take up too much room.

sumna <- function(x) {sum(x, na.rm = T)}
maxna <- function(x) {max(x, na.rm = T)}
minna <- function(x) {min(x, na.rm = T)}
meanna <- function(x) {mean(x, na.rm = T)}
medianna <- function(x) {median(x, na.rm = T)}
sdna <- function(x) {sd(x, na.rm = T)}
rangena <- function(x) {range(x, na.rm = T)}

get_country_data <- function(fnms) {
  model_names <- str_extract(basename(fnms), "(?<=_).*(?=\\.qs$)")
  cons_data   <- map2_dfr(fnms, model_names, function(fn, mn) {qs_read(fn) %>% mutate(model_name = mn)}) %>% 
    dplyr::select(-feed_prov)

  cons_data_2025 <- cons_data %>% 
    filter(year == 2025) %>% 
    dplyr::select(-c(year)) %>% 
    rename(
      biomass_2025               = biomass,
      feed_prov_per_biomass_2025 = feed_prov_per_biomass
    )

  left_join(
    cons_data,
    cons_data_2025,
    by = join_by(farm_ID, model_name)
  ) %>% 
  mutate(
    biomass_change             = biomass - biomass_2025,
    biomass_change_pct         = biomass_change/biomass_2025,
    feed_prov_biom_change      = feed_prov_per_biomass - feed_prov_per_biomass_2025,
    feed_prov_biom_change_pct  = feed_prov_biom_change/feed_prov_per_biomass_2025
  )
}

# Mean across species rasters, weighted by each model's current production
weighted_HS <- function(rasts, weights) {
  w <- weights / sum(weights)
  Reduce(`+`, map2(rasts, w, \(r, wi) r * wi))
}

# Percentage y-axis helpers ---------------------------------------------------
#
# Limits are rounded outward to a "round" percentage just outside the data range, and breaks run between them in 10% steps, or 5% steps if 10% would give too few breaks. Values are assumed to be proportions (0.85 = 85%).
#
# pct_limits() and pct_breaks() can be passed straight to scale_y_continuous(limits = , breaks = ), or use scale_y_pct() for both.

# Internal: choose step and compute rounded limits from a numeric vector
.pct_axis <- function(x,
                      steps = c(0.10, 0.05),
                      min_breaks = 5,
                      strict = FALSE,
                      clamp = c(0, 1)) {
  rng <- range(x, na.rm = TRUE, finite = TRUE)
  if (!all(is.finite(rng))) stop("`x` has no finite values.")
  steps <- sort(steps, decreasing = TRUE)

  round_out <- function(step) {
    # round() guards against floating point, e.g. 0.85 / 0.05 = 16.9999...
    lo <- floor(round(rng[1] / step, 8)) * step
    hi <- ceiling(round(rng[2] / step, 8)) * step
    if (strict) {
      if (isTRUE(all.equal(lo, rng[1]))) lo <- lo - step
      if (isTRUE(all.equal(hi, rng[2]))) hi <- hi + step
    }
    if (hi == lo) { lo <- lo - step; hi <- hi + step }  # constant data
    # Don't let rounding push past the clamp (e.g. 0% / 100%), unless the
    # data are already outside it on that side
    if (!is.null(clamp)) {
      if (rng[1] >= clamp[1]) lo <- max(lo, clamp[1])
      if (rng[2] <= clamp[2]) hi <- min(hi, clamp[2])
    }
    c(lo, hi)
  }

  # Use the largest step that still gives at least `min_breaks` breaks; fall back to the smallest step
  for (step in steps) {
    lim <- round_out(step)
    n <- round((lim[2] - lim[1]) / step) + 1
    if (n >= min_breaks) break
  }
  list(limits = round(lim, 10), step = step)
}

# Rounded limits. Works as `limits =` in scale_y_continuous() (it receives the data range) or on a raw data vector.
pct_limits <- function(x, ...) {
  .pct_axis(x, ...)$limits
}

# Breaks between the rounded limits. Works as `breaks =` in scale_y_continuous() (it receives the limits) or on a raw data vector.
pct_breaks <- function(x, ...) {
  ax <- .pct_axis(x, ...)
  lim <- ax$limits
  # Breaks on multiples of the step, in case clamping left an odd limit
  first <- ceiling(round(lim[1] / ax$step, 8)) * ax$step
  round(seq(first, lim[2] + 1e-9, by = ax$step), 10)
}

# Convenience wrapper: percentage scale with rounded limits and breaks. `...` goes to scale_y_continuous(); pass axis options via `axis_args`, e.g. axis_args = list(steps = c(0.1, 0.05), strict = TRUE).
scale_y_pct <- function(...,
                        axis_args = list(),
                        accuracy = 1,
                        expand = c(0, 0)) {
  # expand = c(0, 0) so the axis ends exactly on the rounded limits. ggplot passes the *expanded* range to the breaks function, so any expansion can make pct_breaks() pick a different step than pct_limits() did.
  scale_y_continuous(
    limits = function(x) do.call(pct_limits, c(list(x), axis_args)),
    breaks = function(x) do.call(pct_breaks, c(list(x), axis_args)),
    labels = scales::label_percent(accuracy = accuracy),
    expand = expand,
    ...
  )
}
