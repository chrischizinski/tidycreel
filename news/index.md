# Changelog

## tidycreel 1.3.0

### New features

- [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  now accepts `estimator = "mortr"` for truncated mean-of-ratios
  (MORtr), which applies `truncate_at` as a mandatory threshold and
  labels the method `"mean-of-ratios-truncated-cpue"`.
- [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  gains a `targeted` argument (default `TRUE`). Setting
  `targeted = FALSE` excludes zero-catch trips before MOR/MORtr
  estimation for incidental species workflows.
- [`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md)
  provides a unified tidy entry point for pre-survey sample-size
  planning, wrapping
  [`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
  [`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
  and
  [`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)
  into a single consistent interface with `mode = "effort_n"`,
  `"cpue_n"`, or `"power"`.
- [`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md)
  compares multiple survey designs side by side from a named list of
  `creel_estimates` objects. An
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  method renders a forest plot of point estimates with confidence
  intervals.
- [`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md)
  constructs a hybrid access + roving survey design from combined
  access-point and roving-route count data.
- [`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md)
  computes Taylor linearization vs. replicate (bootstrap or jackknife)
  standard errors side-by-side for any `creel_estimates` object.
- [`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md)
  applies nonresponse weighting to a `creel_design` and records
  per-stratum diagnostics.
- [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  adds ratio-calibrated camera/time-lapse effort indexing.
- [`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)
  adds weighted catch-at-length / size-structure estimation from
  attached length data.
- [`autoplot.creel_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_length_distribution.md)
  adds a plotting surface for weighted size-structure estimates.
- [`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md)
  and
  [`creel_palette()`](https://chrischizinski.github.io/tidycreel/reference/creel_palette.md)
  add package-standard plot styling.

### Data validation and cleaning

- [`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md)
  adds field-level schema validation for creel inputs.
- [`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md)
  adds canonical species-code standardisation helpers.
- [`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md)
  adds formatted validation summaries that can be exported alongside
  other report-ready outputs.
- `creel_counts_toy` and `creel_interviews_toy` are now bundled example
  datasets for examples, tests, and documentation.

### Documentation and reporting

- Added a glossary vignette for package terminology and workflow
  language.
- Added a survey design toolbox vignette covering planning and
  pre-season tools.
- Added a flexdashboard report template scaffold under
  `inst/rmarkdown/templates/creel-dashboard/`.
- Expanded pkgdown/reference discoverability for the newer estimation,
  visualisation, and reporting surfaces.
- The full pkgdown site now rebuilds cleanly after normalizing older
  vignette header/title inconsistencies.

### Improvements

- [`plot_design()`](https://chrischizinski.github.io/tidycreel/reference/plot_design.md)
  now supports multi-strata designs.
- Main estimator
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  methods now support opt-in `theme = "creel"` styling without changing
  default behavior.
- Single-PSU strata produce a structured, actionable error instead of an
  opaque `survey:::onestrat` message.
- Fixed a bug in the `aerial-glmm` vignette downstream estimation chunk
  where `example_aerial_interviews` was paired with the wrong design
  object.

### Dependencies

- **ggplot2** added to `Imports` to support the `autoplot.*` methods.
- **flexdashboard** added to `Suggests` for the optional report
  template.

### Tests

- Expanded test coverage for the newer estimation, validation, plotting,
  and reporting surfaces shipped through the current 1.3.0 development
  line.

## tidycreel 1.2.0 (2026-04-08)

### New features

- [`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md)
  converts any estimate object to a `creel_summary` with human-readable
  column names (`Estimate`, `SE`, `CI Lower`, `CI Upper`, `N`). Includes
  [`print.creel_summary()`](https://chrischizinski.github.io/tidycreel/reference/print.creel_summary.md)
  and
  [`as.data.frame.creel_summary()`](https://chrischizinski.github.io/tidycreel/reference/as.data.frame.creel_summary.md)
  methods. Works for effort, CPUE, harvest rate, total catch, and
  grouped variants.

- [`flag_outliers()`](https://chrischizinski.github.io/tidycreel/reference/flag_outliers.md)
  identifies extreme values in a numeric column using Tukey’s IQR fence
  (`k = 1.5` default). Returns the input data frame with `is_outlier`,
  `outlier_reason`, `fence_low`, and `fence_high` columns appended, and
  emits a `cli` summary of flagged rows. Handles `n < 4`, empty input,
  and zero-row data frames gracefully.

- `ggplot2::autoplot.creel_estimates()` produces a point-and-errorbar
  plot from any `creel_estimates` object. Ungrouped estimates show a
  single point with confidence interval; grouped estimates show one
  point per group level, colour-coded.

- `ggplot2::autoplot.creel_schedule()` produces a monthly tile calendar
  from a `creel_schedule` object. Sampled dates are coloured by day type
  (weekday blue / weekend red); unsampled dates are shown in grey.
  Multiple months are displayed as vertically stacked facet panels.

### Improvements

- Single-PSU strata now produce a structured, actionable error instead
  of an opaque `survey:::onestrat` message. The error names the
  problematic stratum and suggests increasing the sampling rate or
  combining sparse strata.

- Fixed a bug in the `aerial-glmm` vignette downstream estimation chunk
  where `example_aerial_interviews` was paired with the GLMM design
  (built from `example_aerial_glmm_counts`). The chunk now uses the
  correct matching dataset (`example_aerial_counts` +
  `example_aerial_interviews`).

### Dependencies

- **ggplot2** added to `Imports` to support the new `autoplot.*`
  methods.

## tidycreel 1.1.0 (2026-04-02)

### New features

- [`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md)
  adds three sampling strategies for allocating interview periods within
  a survey day: random, systematic, and fixed-interval. Supports a
  `seed` argument for reproducibility; returns a `creel_schedule` object
  compatible with
  [`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md).

- The `survey-scheduling` vignette now covers the full pre- and
  post-season planning workflow:
  [`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md)
  through
  [`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md),
  [`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
  and
  [`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md).

### Documentation

- GitHub issue templates now use structured forms with
  `blank_issues_enabled: false`, routing how-to questions to GitHub
  Discussions to keep answers searchable for all users.

- `CONTRIBUTING.md` has been rewritten with current workflow guidance,
  contribution types, and community norms for the v1.x release line.

## tidycreel 1.0.0 (2026-03-31)

- Launched the pkgdown documentation site at
  <https://chrischizinski.github.io/tidycreel> with a custom Bootstrap 5
  theme, full function reference index (46 exports + 15 datasets), and a
  workflow-driven navbar.

- Added a GitHub Actions CI/CD workflow to deploy the pkgdown site
  automatically on every push to main.
