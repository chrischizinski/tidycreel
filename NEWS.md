# tidycreel 2.3.0 "Northern Pike" (2026-06-22)

## Breaking changes

* `estimate_harvest_rate()` and `estimate_release_rate()` now default to
  `use_trips = "complete"` (previously `use_trips = "all"`). For standard
  (non-bus-route) designs that supply `trip_status`, HPUE and RPUE are now
  estimated from completed-trip interviews only. This is the statistically
  preferred default: incomplete-trip rates underestimate harvest and release
  when anglers keep or release additional fish after being interviewed (Hansen &
  Van Kirk 2010). The previous all-interview behavior is no longer the default
  but remains fully available.

  **To restore the previous behavior**, pass `use_trips = "all"` explicitly:

  ```r
  estimate_harvest_rate(design, use_trips = "all")
  estimate_release_rate(design, use_trips = "all")
  ```

  Designs without a `trip_status` column are unaffected (the argument has no
  effect). Bus-route designs already defaulted to `"complete"` and are
  unchanged. Closes #69.

## Documentation

* Added a Quarto Creel Report starter template scaffold that uses the
  `tidycreel` design, validation, summary, and plotting helpers end to end.

# tidycreel 2.2.0 "Goldeye" (2026-06-17)

## New features

* `simulate_creel_data()` now returns a `$schedule` component — a full-season
  calendar (one row per season day) with columns `date` (Date), `day_type`
  (character), and `sampled` (logical). Pass directly to `creel_design()` as
  the `calendar` argument for a complete round-trip simulation pipeline with no
  manual column construction. Unsampled days receive a `day_type` drawn
  proportionally from the `day_types` distribution. Closes #68.

  ```r
  sim <- simulate_creel_data(params = my_params, day_types = c(weekday = 5/7, weekend = 2/7))
  design <- creel_design(sim$schedule, date = date, strata = day_type) |>
    add_counts(sim$counts) |>
    add_interviews(sim$interviews,
      catch = "catch_total", effort = "hours_fished", harvest = "catch_kept",
      trip_status = "trip_status", n_anglers = "n_anglers", interview_type = "roving")
  ```

  **Note:** this changes the return structure from three components
  (`interviews`, `counts`, `catch`) to four (`schedule`, `interviews`,
  `counts`, `catch`). Code that checks names by position should switch to
  name-based access.

## Documentation

* `simulate_creel_data()` `day_types` parameter now explicitly documents that
  the argument must be a named **numeric** vector (not a character vector), with
  a worked example showing the correct form `c(weekday = 5/7, weekend = 2/7)`.
* `@examples` block expanded with a multi-stratum simulation and the full
  round-trip pipeline from `simulate_creel_data()` through `creel_design()`,
  `add_counts()`, and `add_interviews()`.

## Bug fixes / closed issues

* `standardize_species()`: added `custom_codes` argument (named character vector
  applied as a second AFS-NA pass), expanded AFS lookup table with Freshwater
  Drum (`"FRD"`), and corrected misleading "supply a custom code map"
  documentation that implied a non-existent function argument. Closes #66.
* `estimate_harvest_rate()` / `estimate_release_rate()`: added `use_trips`
  argument (`"all"` default, `"complete"` to restrict) with `cli_inform` notice
  showing trip-status breakdown. Documented livewell-observable rationale and
  downward-bias risk (Hansen & Van Kirk 2010). Closes #65. Future default flip
  to `"complete"` tracked as #69.

# tidycreel 2.1.0 "Sauger" (2026-06-17)

## New features

* `estimate_catch_rate()` now auto-routes roving designs: when
  `add_interviews(..., interview_type = "roving")` is set and `use_trips` /
  `estimator` are not explicitly supplied, the function defaults to
  `use_trips = "all"` and `estimator = "mor"` (Hoenig et al. 1997), using all
  interviewed trips via mean-of-ratios rather than restricting to complete trips.
  Access-point designs (`interview_type = "access"`, the default) are unaffected.
  Explicit `use_trips` or `estimator` arguments always override the auto-route.
  Closes #67.

* New `use_trips = "all"` option for `estimate_catch_rate()`: uses every
  interview (complete + incomplete) with the MOR estimator. Previously only
  `"complete"`, `"incomplete"`, and `"diagnostic"` were accepted.

## Bug fixes

* `estimate_catch_rate(by = species)` returned all-zero estimates when catch
  data contained only `"harvested"` and `"released"` rows (no `"caught"` rows).
  Fix was in source since v2.0.0 but the installed binary at the site-library
  was stale; reinstalling now picks up the correct aggregation logic. Closes #64.

## Documentation

* `add_interviews()` `interview_type` parameter description corrected: now
  accurately states that `"roving"` triggers automatic estimator routing rather
  than carrying the false claim that the flag was "stored metadata only".
* `estimate_catch_rate()` `use_trips` parameter and Details section updated to
  document `"all"`, roving auto-routing, and the access vs. roving distinction.

## Versioning

Starting with this release, tidycreel follows semantic versioning
(MAJOR.MINOR.PATCH) and names each MINOR release after a fish species native to
Nebraska or the Great Plains. v2.1.0 is named for the Sauger
(*Sander canadensis*), a walleye relative common in Nebraska's large rivers.

# tidycreel 1.9.0 (2026-05-25)

## New features

* `estimate_angler_trips()` — estimates angler trip counts (angler days) from effort and mean trip length using Delta Method variance propagation.
* `estimate_effort_per_acre()` — computes effort density (angler-hours per acre) by stratum from an extrapolated effort estimate and supplied acreage.
* `summarize_boat_composition()` — returns percent angler boats by month and day type, computed from raw count fields c_AnglerBoats and c_NonAngBoats.
* `summarize_by_zip()` — tabulates interview count and percentage by zip code from the ii_ZipCode interview field.
* `summarize_by_county()` — maps zip codes to counties via zipcodeR and returns interview count and percentage by county; emits an informative error when zipcodeR is not installed.

## Documentation

* pkgdown site rebuilt at v1.9.0; all new functions appear in the reference index.
* tidycreel.connect bridge vignette updated: install block added (remotes::install_github), stale "not yet public" availability language removed throughout.
* GitHub bug report issue template gains an R version field (required).

## Tech debt

* WRITE-11: write_estimates() xlsx export path now covered by a passing round-trip test guarded with skip_if_not_installed("writexl") (TD-01 carry-forward from v1.8.0).

# tidycreel 1.4.0 (2026-04-23)

## Quality, testing, and release readiness

* Closed the priority rOpenSci blocker set for the current release line:
  named condition classes at the key `cli_abort()` sites, formal lifecycle
  badges on experimental APIs, a valid `inst/CITATION`, and removal of the
  `scales` dependency from the package surface.
* Demoted `lubridate` from `Imports` to `Suggests` and added runtime install
  guards at user-facing schedule entry points.
* Threaded `rlang::caller_env()` through the top-level bus-route estimator
  internals and relocated `get_site_contributions()` into the estimation layer
  to tighten call-frame quality and layering.
* Added `@family` tags across the exported surface so the pkgdown reference is
  grouped by workflow topic rather than a flat function list.
* Added snapshot regression coverage for `print.creel_design()`,
  `print.creel_estimates_mor()`, and `print.creel_schedule()`.
* Added `quickcheck`-based property tests and generator helpers covering the
  highest-value implemented invariants: INV-01, INV-02, INV-03, INV-04, and
  INV-06.
* Added a CI-backed coverage gate with a documented local baseline of `86.27%`,
  Codecov configuration, and a project target of `85%`.

# tidycreel 1.3.0

## New features

* `estimate_catch_rate()` now accepts `estimator = "mortr"` for truncated
  mean-of-ratios (MORtr), which applies `truncate_at` as a mandatory threshold
  and labels the method `"mean-of-ratios-truncated-cpue"`.
* `estimate_catch_rate()` gains a `targeted` argument (default `TRUE`). Setting
  `targeted = FALSE` excludes zero-catch trips before MOR/MORtr estimation for
  incidental species workflows.
* `power_creel()` provides a unified tidy entry point for pre-survey
  sample-size planning, wrapping `creel_n_effort()`, `creel_n_cpue()`, and
  `creel_power()` into a single consistent interface with `mode = "effort_n"`,
  `"cpue_n"`, or `"power"`.
* `compare_designs()` compares multiple survey designs side by side from a
  named list of `creel_estimates` objects. An `autoplot()` method renders a
  forest plot of point estimates with confidence intervals.
* `as_hybrid_svydesign()` constructs a hybrid access + roving survey design
  from combined access-point and roving-route count data.
* `compare_variance()` computes Taylor linearization vs. replicate (bootstrap
  or jackknife) standard errors side-by-side for any `creel_estimates` object.
* `adjust_nonresponse()` applies nonresponse weighting to a `creel_design` and
  records per-stratum diagnostics.
* `est_effort_camera()` adds ratio-calibrated camera/time-lapse effort indexing.
* `est_length_distribution()` adds weighted catch-at-length / size-structure
  estimation from attached length data.
* `autoplot.creel_length_distribution()` adds a plotting surface for weighted
  size-structure estimates.
* `theme_creel()` and `creel_palette()` add package-standard plot styling.

## Data validation and cleaning

* `validate_creel_data()` adds field-level schema validation for creel inputs.
* `standardize_species()` adds canonical species-code standardisation helpers.
* `validation_report()` adds formatted validation summaries that can be exported
  alongside other report-ready outputs.
* `creel_counts_toy` and `creel_interviews_toy` are now bundled example datasets
  for examples, tests, and documentation.

## Documentation and reporting

* Added a glossary vignette for package terminology and workflow language.
* Added a survey design toolbox vignette covering planning and pre-season tools.
* Added a flexdashboard report template scaffold under
  `inst/rmarkdown/templates/creel-dashboard/`.
* Expanded pkgdown/reference discoverability for the newer estimation,
  visualisation, and reporting surfaces.
* The full pkgdown site now rebuilds cleanly after normalizing older vignette
  header/title inconsistencies.

## Improvements

* `plot_design()` now supports multi-strata designs.
* Main estimator `autoplot()` methods now support opt-in
  `theme = "creel"` styling without changing default behavior.
* Single-PSU strata produce a structured, actionable error instead of an opaque
  `survey:::onestrat` message.
* Fixed a bug in the `aerial-glmm` vignette downstream estimation chunk where
  `example_aerial_interviews` was paired with the wrong design object.

## Dependencies

* **ggplot2** added to `Imports` to support the `autoplot.*` methods.
* **flexdashboard** added to `Suggests` for the optional report template.

## Tests

* Expanded test coverage for the newer estimation, validation, plotting, and
  reporting surfaces shipped through the current 1.3.0 development line.

# tidycreel 1.2.0 (2026-04-08)

## New features

* `summary.creel_estimates()` converts any estimate object to a `creel_summary`
  with human-readable column names (`Estimate`, `SE`, `CI Lower`, `CI Upper`,
  `N`). Includes `print.creel_summary()` and `as.data.frame.creel_summary()`
  methods. Works for effort, CPUE, harvest rate, total catch, and grouped
  variants.

* `flag_outliers()` identifies extreme values in a numeric column using
  Tukey's IQR fence (`k = 1.5` default). Returns the input data frame with
  `is_outlier`, `outlier_reason`, `fence_low`, and `fence_high` columns
  appended, and emits a `cli` summary of flagged rows. Handles `n < 4`,
  empty input, and zero-row data frames gracefully.

* `ggplot2::autoplot.creel_estimates()` produces a point-and-errorbar plot
  from any `creel_estimates` object. Ungrouped estimates show a single point
  with confidence interval; grouped estimates show one point per group level,
  colour-coded.

* `ggplot2::autoplot.creel_schedule()` produces a monthly tile calendar from
  a `creel_schedule` object. Sampled dates are coloured by day type (weekday
  blue / weekend red); unsampled dates are shown in grey. Multiple months are
  displayed as vertically stacked facet panels.

## Improvements

* Single-PSU strata now produce a structured, actionable error instead of an
  opaque `survey:::onestrat` message. The error names the problematic stratum
  and suggests increasing the sampling rate or combining sparse strata.

* Fixed a bug in the `aerial-glmm` vignette downstream estimation chunk where
  `example_aerial_interviews` was paired with the GLMM design (built from
  `example_aerial_glmm_counts`). The chunk now uses the correct matching
  dataset (`example_aerial_counts` + `example_aerial_interviews`).

## Dependencies

* **ggplot2** added to `Imports` to support the new `autoplot.*` methods.

# tidycreel 1.1.0 (2026-04-02)

## New features

* `generate_count_times()` adds three sampling strategies for allocating
  interview periods within a survey day: random, systematic, and
  fixed-interval. Supports a `seed` argument for reproducibility; returns a
  `creel_schedule` object compatible with `write_schedule()`.

* The `survey-scheduling` vignette now covers the full pre- and post-season
  planning workflow: `generate_count_times()` through `validate_design()`,
  `check_completeness()`, and `season_summary()`.

## Documentation

* GitHub issue templates now use structured forms with
  `blank_issues_enabled: false`, routing how-to questions to GitHub Discussions
  to keep answers searchable for all users.

* `CONTRIBUTING.md` has been rewritten with current workflow guidance,
  contribution types, and community norms for the v1.x release line.

# tidycreel 1.0.0 (2026-03-31)

* Launched the pkgdown documentation site at
  https://chrischizinski.github.io/tidycreel with a custom Bootstrap 5 theme,
  full function reference index (46 exports + 15 datasets), and a
  workflow-driven navbar.

* Added a GitHub Actions CI/CD workflow to deploy the pkgdown site
  automatically on every push to main.
