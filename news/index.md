# Changelog

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
