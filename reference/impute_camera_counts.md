# Impute missing camera counts using GLM or GLMM

Fills outage rows in a camera count data frame using a per-stratum
model. The GLM method (default, Hartill 2016) fits a Poisson GLM with
`strata_col` (typically `day_type`) as the sole predictor. The GLMM
method (Afrifa-Yamoah 2020) fits a negative binomial GLMM and requires
the `glmmTMB` package (in `Suggests`).

Outage rows are identified as any row where
`status_col != "operational"` AND `count_col` is `NA`. All rows are
returned; imputed rows have `.imputed = TRUE`. The original `status_col`
values (e.g., `"battery_failure"`) are preserved in imputed rows for
traceability.

## Usage

``` r
impute_camera_counts(
  data,
  count_col,
  strata_col,
  status_col = "camera_status",
  method = "glm",
  m = 1L,
  site_col = NULL
)
```

## Arguments

- data:

  A data frame of camera count records. Must have at least one row and
  must contain the columns named by `count_col`, `strata_col`, and
  `status_col`.

- count_col:

  Character scalar. Name of the integer count column (e.g.,
  `"ingress_count"`). Outage rows have `NA` in this column.

- strata_col:

  Character scalar. Name of the day-type stratum column (e.g.,
  `"day_type"`). Used as the predictor in the per-stratum GLM/GLMM.

- status_col:

  Character scalar. Name of the camera status column. Default
  `"camera_status"`. Rows where this column is not `"operational"` and
  `count_col` is `NA` are treated as outages.

- method:

  Character scalar. Imputation model: `"glm"` (default, Poisson GLM, no
  extra dependencies) or `"glmm"` (negative binomial GLMM via `glmmTMB`,
  requires `glmmTMB` in `Suggests`).

- m:

  Integer scalar. Number of completed data sets to generate. `1L`
  (default) fills each outage row with the fitted mean, reproducing the
  single-imputation behaviour of earlier versions and returning a plain
  data frame.

  `m > 1` performs **multiple imputation** and returns a
  `camera_imputations` object for
  [`est_effort_camera_mi()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera_mi.md)
  to pool. Afrifa-Yamoah et al. (2020) use `m = 5` as "an appropriate
  balance of the bias-variance trade-off".

  The distinction matters because a single completed data set
  structurally cannot carry the between-imputation variance. Inside
  [`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) a
  prediction is indistinguishable from an observation, so the imputation
  model's uncertainty is dropped, and fitted means are smoother than
  real counts, shrinking the between-day variance a second time (GH
  \#137).

- site_col:

  Character scalar or `NULL`. When `method = "glmm"` and `site_col` is
  not `NULL`, a random intercept `(1 | site_col)` is included in the
  GLMM formula. Default `NULL`.

## Value

A data frame with the same rows and columns as `data`, plus a new
logical column `.imputed` appended as the last column. Outage rows are
filled in `count_col` with model-predicted counts (rounded to integer).
The `count_col` storage mode is set to `"integer"` for schema
compatibility with
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
Row count equals `nrow(data)`.

## Details

**\[experimental\]**

## References

Hartill, B.W., Taylor, S.M., Keller, K., and Weltersbach, M.S. 2020.
Digital camera monitoring of recreational fishing effort: applications
and challenges. Fish and Fisheries 21:204-215.
[doi:10.1111/faf.12413](https://doi.org/10.1111/faf.12413)

Afrifa-Yamoah, E., Mueller, U.A., Taylor, S.M., and Fisher, A. 2020.
Missing data imputation of high-resolution temporal climate data series
using an integrated framework of expectation maximisation and long
short-term memory neural networks.

## See also

[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)

Other "Survey Design":
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md),
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`creel_vocabulary()`](https://chrischizinski.github.io/tidycreel/reference/creel_vocabulary.md),
[`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(tidycreel)
data(example_camera_counts)

# Impute missing counts using the default Poisson GLM
imputed <- impute_camera_counts(
  example_camera_counts,
  count_col  = "ingress_count",
  strata_col = "day_type"
)

# Inspect imputed rows
imputed[imputed$.imputed, ]

# Pass imputed data directly into a camera design
cal <- data.frame(
  date     = unique(example_camera_counts$date),
  day_type = unique(example_camera_counts[, c("date", "day_type")])[["day_type"]]
)
design <- creel_design(cal,
  date = date, strata = day_type,
  survey_type = "camera", camera_mode = "counter"
)
design <- add_counts(design, imputed)
} # }
```
