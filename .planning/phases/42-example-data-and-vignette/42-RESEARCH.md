# Phase 42: Example Data and Vignette — Research

**Researched:** 2026-03-14
**Domain:** R package example datasets (`data/`), roxygen2 `@format` documentation, knitr vignettes (`.Rmd`)
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DOCS-01 | A 3-section example dataset included showing material variation across sections (different effort levels and catch rates) | See Standard Stack: `usethis::use_data()` pattern; dataset must mirror the test fixture data shape from `make_3section_total_catch_design()` but be a permanent package dataset with roxygen2 `@format` docs in `R/data.R` |
| DOCS-02 | A vignette "Spatially stratified estimation with sections" demonstrates the full workflow and explains the correlated-domains vs. independent-strata variance decision | See Architecture Patterns: vignette file placement, YAML header pattern, and required sections below |
</phase_requirements>

---

## Summary

Phase 42 delivers two artifacts: a permanent example dataset (`example_sections_creel` — or parallel naming such as `example_sections_counts` + `example_sections_interviews` + `example_sections_catch`) and a vignette (`.Rmd`) that runs end-to-end with `devtools::build_vignettes()`.

The dataset must show material variation across three sections so the aggregation path, `prop_of_lake_total`, and the missing-section warning path can all be demonstrated in the vignette. The test-fixture helper `make_3section_total_catch_design()` in `tests/testthat/test-estimate-total-catch.R` already encodes the canonical data shape (12-date calendar, North/Central/South effort levels, 9 interviews per section with varying catch rates); the production dataset should mirror that shape rather than invent a new one.

The vignette is the most substantive writing task. It must walk through all five estimator calls in creel vocabulary (effort → catch rate → total catch/harvest/release), explain in one readable section why `method = "correlated"` is the correct default for NGPC shared-calendar designs, and contrast it with `method = "independent"` without exposing `svycontrast()` internals to readers.

**Primary recommendation:** Create three parallel example datasets (`example_sections_calendar`, `example_sections_counts`, `example_sections_interviews`) following the same naming and `data-raw/` pattern used by the existing five datasets, document them in `R/data.R`, and write the vignette in `vignettes/section-estimation.Rmd`.

---

## Standard Stack

### Core (confirmed against project source — HIGH confidence)

| Tool | Where Used | Purpose |
|------|-----------|---------|
| `usethis::use_data(obj, overwrite = TRUE)` | `data-raw/*.R` | Serialize dataset to `data/*.rda` |
| `roxygen2` `@format`, `@source`, `@examples`, `@seealso` | `R/data.R` | Generate `?dataset` help pages |
| `knitr` / `rmarkdown::html_vignette` | `vignettes/*.Rmd` | Build vignettes; `VignetteBuilder: knitr` already in DESCRIPTION |
| `devtools::build_vignettes()` | Build check | Confirms vignette runs clean |
| `R CMD check` | CI | Must pass 0 errors, 0 warnings after Phase 42 |

### Existing Dataset Pattern (read from source — HIGH confidence)

Every existing example dataset follows this two-file pattern:

1. `data-raw/create_<name>.R` (or `data-raw/<name>.R`) — builds the `data.frame`, runs `stopifnot()` quality checks, calls `usethis::use_data(obj, overwrite = TRUE)`
2. Entry in `R/data.R` — roxygen2 block with `#' @format`, `#' @source`, `#' @examples`, `#' @seealso`, then a bare `"<name>"` string

**Installation (no new packages needed):** `usethis` and `knitr` are already in the development workflow. `rmarkdown` is already in `Suggests`.

---

## Architecture Patterns

### Recommended Dataset Structure

Three new `.rda` files following the existing naming convention:

```
data/
├── example_sections_calendar.rda    # 12-date calendar, weekday/weekend strata
├── example_sections_counts.rda      # 36-row counts: 12 dates x 3 sections, material variation
└── example_sections_interviews.rda  # 27-row interviews: 9 per section, varying catch rates
```

Optionally a fourth:
```
data/
└── example_sections_catch.rda       # long-format species catch (needed for full catch/harvest/release demo)
```

Note: if the vignette calls `estimate_total_catch()` (not `estimate_total_harvest()` or `estimate_total_release()` with species-level data), the catch dataset may be omitted and `catch_total` / `catch_kept` columns in interviews are sufficient.

### Data-raw Scripts

```
data-raw/
├── example_sections_calendar.R      # builds calendar df, use_data()
├── example_sections_counts.R        # builds counts df with North/Central/South variation, use_data()
└── example_sections_interviews.R    # builds interviews df, stopifnot() checks, use_data()
```

### Pattern: Existing data-raw script layout

```r
# Generate example_sections_counts dataset
# 12-date calendar (June 2024), 3 sections (North, Central, South)
# Effort varies materially: South ~8-13 h, North ~15-28 h, Central ~30-48 h

example_sections_counts <- data.frame(
  date     = ...,
  day_type = ...,
  section  = ...,
  effort_hours = c(
    # South: low effort  — weekday ~5-12, weekend ~6-13
    # North: mid effort  — weekday ~15-25, weekend ~20-28
    # Central: high effort — weekday ~30-45, weekend ~35-48
    ...
  ),
  stringsAsFactors = FALSE
)

stopifnot(nrow(example_sections_counts) == 36L)
usethis::use_data(example_sections_counts, overwrite = TRUE)
```

Source: pattern read from `data-raw/example_counts.R` and `data-raw/create_example_interviews.R`.

### Pattern: R/data.R entry

```r
#' Example section counts for a 3-section creel survey
#'
#' Instantaneous count observations for a three-section survey (North,
#' Central, South) showing material variation in fishing effort across
#' sections. Suitable for use with [add_counts()] after [add_sections()].
#'
#' @format A data frame with 36 rows and 4 columns:
#' \describe{
#'   \item{date}{Survey date (Date class), June 3–21, 2024}
#'   \item{day_type}{Day type stratum: "weekday" or "weekend"}
#'   \item{section}{Section identifier: "North", "Central", or "South"}
#'   \item{effort_hours}{Numeric count variable: total angler-hours observed}
#' }
#'
#' @source Simulated data for package examples
#'
#' @seealso [example_sections_calendar], [add_sections()], [add_counts()]
"example_sections_counts"
```

Source: pattern read from `R/data.R`.

### Vignette File Location and Header

```
vignettes/section-estimation.Rmd
```

Required YAML header (confirmed from `bus-route-surveys.Rmd` and `tidycreel.Rmd`):

```yaml
---
title: "Spatially Stratified Estimation with Sections"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Spatially Stratified Estimation with Sections}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---
```

### Required Vignette Sections (from DOCS-02 success criteria)

1. **Introduction** — what a sectioned creel survey is and when to use `add_sections()`
2. **Survey Design** — `creel_design()` + `add_sections()` call
3. **Count Data** — `add_counts()` with section column present; show `estimate_effort()` per-section output (not lake-total row — let the default `aggregate_sections = TRUE` show both)
4. **Interview Data** — `add_interviews()` with section column; show `estimate_catch_rate()` per-section output — explicitly note no `.lake_total` row (CPUE is not additive)
5. **Total Catch** — `estimate_total_catch()` with `aggregate_sections = TRUE`; show `.lake_total` row and `prop_of_lake_total` column
6. **Variance Aggregation Decision** — the key explanatory section; see Code Examples below for required narrative
7. **Missing Section Warning** — show `missing_sections = "warn"` path producing NA row with `data_available = FALSE`

### Anti-Patterns to Avoid

- **Don't invent new data shapes**: The test fixtures in `test-estimate-effort.R` (lines 42–86) and `test-estimate-total-catch.R` (lines 554–735) already define the canonical 3-section data shape. Use those exact numbers.
- **Don't use `data.frame()` with `stringsAsFactors = TRUE`**: All existing data-raw scripts use `stringsAsFactors = FALSE`.
- **Don't add datasets as inline objects inside the vignette**: Call `data(example_sections_counts)` etc. — same pattern as `interview-estimation.Rmd`.
- **Don't expose survey package internals in the vignette**: Biologists see `method = "correlated"` / `method = "independent"`, not `svyby(covmat=TRUE)` or `svycontrast()`.
- **Don't use `estimate_cpue()`**: That function was renamed to `estimate_catch_rate()` in v0.7.0 (RATE-01 decision, locked). The vignette must use the new name.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Dataset serialization | Manual `saveRDS()` or `save()` | `usethis::use_data(obj, overwrite = TRUE)` |
| Vignette rendering | Custom knit scripts | `VignetteEngine{knitr::rmarkdown}` in YAML header; `devtools::build_vignettes()` for local check |
| Data documentation | Separate `.Rd` files | `roxygen2` block in `R/data.R` with `"dataset_name"` string at end — roxygenize() generates the `.Rd` |

---

## Common Pitfalls

### Pitfall 1: Calendar dates not in `example_sections_calendar`

**What goes wrong:** `add_counts()` validates that every count date appears in the design's calendar. If counts data uses dates not in the calendar, the call aborts.
**Why it happens:** The calendar is the survey frame; extra dates are unrecognised PSUs.
**How to avoid:** Build `example_sections_counts` by repeating `cal$date` three times (once per section) — exactly the pattern in `make_3section_design_with_counts()` (line 68: `date = rep(cal$date, times = 3)`).

### Pitfall 2: Interview dates outside calendar range

**What goes wrong:** `add_interviews()` validates dates. Interviews on dates absent from the calendar produce an abort.
**How to avoid:** Use the same 12 dates in `example_sections_interviews` as in `example_sections_calendar`.

### Pitfall 3: suppressWarnings() obscuring expected survey warnings in vignette

**What goes wrong:** `svydesign()` emits a "no weights" warning when creating a fresh design from a subset of data. In tests this is suppressed, but in the vignette you want clean output. The vignette `knitr` chunk option `warning = FALSE` can suppress this at the chunk level.
**How to avoid:** Set `warning = FALSE` on the specific chunk(s) that call `add_counts()` with section data, or wrap in `suppressWarnings()` inline.

### Pitfall 4: Forgetting `section` column in counts and interviews

**What goes wrong:** `add_sections()` registers the section column name in `design$section_col`. If the counts or interviews data frame does not contain a column with that exact name, the guard in `add_counts()` / `add_interviews()` aborts.
**How to avoid:** The `example_sections_counts` and `example_sections_interviews` datasets must include a `section` column.

### Pitfall 5: Missing-section warning path needs a separate `design` in the vignette

**What goes wrong:** Demonstrating the missing-section path requires a design where one section has no count data. If you modify the main design object, the vignette flow breaks.
**How to avoid:** Create a local `design_missing <- ...` within a dedicated code chunk for the missing-section demo, built from the same calendar/sections but with South counts removed.

### Pitfall 6: `estimate_catch_rate()` result has no `.lake_total` row — must explain this

**What goes wrong:** A biologist expecting a lake total for CPUE will be confused by its absence.
**Why it happens:** CPUE is a ratio estimator; ratios are not additive; lake-wide CPUE requires a separate unsectioned call.
**How to avoid:** The vignette MUST contain an explicit plain-language note explaining this. See the locked decision in `STATE.md` ("CPUE is not additive").

---

## Code Examples

### Full workflow skeleton (verified from existing estimator APIs)

```r
library(tidycreel)

# Load section-specific example data
data(example_sections_calendar)
data(example_sections_counts)
data(example_sections_interviews)

# Step 1: Build design with sections
sections_df <- data.frame(
  section = c("North", "Central", "South"),
  stringsAsFactors = FALSE
)
design <- creel_design(example_sections_calendar, date = date, strata = day_type)
design <- add_sections(design, sections_df, section_col = section)
design <- add_counts(design, example_sections_counts)
design <- add_interviews(design, example_sections_interviews,
  catch        = catch_total,
  effort       = hours_fished,
  harvest      = catch_kept,
  trip_status  = trip_status,
  trip_duration = trip_duration
)

# Step 2: Per-section effort (+ lake total via method="correlated")
effort_est <- estimate_effort(design)
print(effort_est)

# Step 3: Per-section catch rate (no lake total — CPUE is not additive)
cpue_est <- estimate_catch_rate(design)
print(cpue_est)

# Step 4: Per-section total catch with lake-total row
catch_est <- estimate_total_catch(design, aggregate_sections = TRUE)
print(catch_est)
```

Source: confirmed from `R/creel-estimates.R` exported function signatures and existing vignette patterns in `vignettes/interview-estimation.Rmd`.

### Variance Aggregation Explanation (required narrative)

The vignette must include a section in plain language. Suggested draft (planner should include verbatim or equivalent):

> **Why `method = "correlated"` is the default**
>
> In a standard NGPC shared-calendar creel design, the field crew works the entire lake on each survey day. Every section is counted and interviewed on the same calendar days. This means the sections share the same day-level primary sampling units (PSUs): if a day is sampled, all three sections are observed; if a day is not sampled, none are.
>
> Sharing PSUs creates cross-section covariance in the sampling errors. In practice this covariance is negative: on high-effort days all sections tend to run high together, and on low-effort days they run low together. The shared-calendar variance formula accounts for this covariance via `svyby(covmat = TRUE)` and produces a narrower lake-total standard error than simply adding the section standard errors in quadrature.
>
> `method = "independent"` is appropriate only when sections are surveyed by separate, uncoordinated crews — for example, when South Lake is run by Crew A on a different day from North Lake (Crew B). In that case the sections truly have independent sampling errors and Cochran (1977, §5.2) additivity applies: `SE_total = sqrt(sum(SE_h^2))`.
>
> **Rule of thumb:** If your crew drives the entire lake on each survey day, use the default `method = "correlated"`. If different sections have separate, non-overlapping calendars, use `method = "independent"`.

### Missing-section warning demo

```r
# Demo: what happens when a section has no count data
data(example_sections_calendar)
sections_df <- data.frame(section = c("North", "Central", "South"),
                           stringsAsFactors = FALSE)
design_missing <- creel_design(example_sections_calendar, date = date, strata = day_type)
design_missing <- add_sections(design_missing, sections_df, section_col = section)
# Only attach North and Central counts
north_central_counts <- example_sections_counts[
  example_sections_counts$section != "South", ]
design_missing <- suppressWarnings(add_counts(design_missing, north_central_counts))

# Warn path: South produces NA row, data_available = FALSE
effort_missing <- estimate_effort(design_missing, missing_sections = "warn")
print(effort_missing)
```

---

## State of the Art

| Old Approach | Current Approach | Impact on Phase 42 |
|--------------|------------------|--------------------|
| `estimate_cpue()` | `estimate_catch_rate()` (RATE-01, v0.7.0 breaking change) | Vignette MUST use `estimate_catch_rate()` — never the old name |
| `estimate_harvest()` | `estimate_harvest_rate()` (RATE-01) | Vignette MUST use `estimate_harvest_rate()` |
| No section support | `add_sections()` + section dispatch in all estimators | Phase 42 is the first user-facing documentation of this capability |

---

## Open Questions

1. **Single combined dataset or three parallel datasets?**
   - What we know: All existing datasets are separate (`example_calendar`, `example_counts`, `example_interviews`) and are loaded independently with `data()` calls.
   - What's unclear: The requirement says "3-section example dataset" (singular). This could mean one data frame with all columns, or three parallel data frames.
   - Recommendation: Follow the existing convention — three separate data frames (`example_sections_calendar`, `example_sections_counts`, `example_sections_interviews`) — so the vignette's `data()` calls mirror the non-sectioned workflow in `interview-estimation.Rmd`.

2. **Include `example_sections_catch` for species-level data?**
   - What we know: `estimate_total_catch()` requires only `catch_total` from interviews; species breakdown requires `add_catch()`. The vignette success criteria list "per-section and lake-total catch" but not "per-species catch".
   - What's unclear: Whether "catch" in the success criteria means total catch or species-level catch.
   - Recommendation: Omit `example_sections_catch` for Phase 42. Use `catch_total`/`catch_kept` interview columns for `estimate_total_catch()` and `estimate_total_harvest()`. This keeps the vignette focused and avoids a fourth dataset. Revisit in v0.8.0 if species-level vignette is needed.

3. **Dataset naming: `example_sections_*` vs. `example_lake_sections_*`?**
   - Recommendation: `example_sections_calendar`, `example_sections_counts`, `example_sections_interviews` — concise and parallel to `example_calendar`, `example_counts`, `example_interviews`.

---

## Validation Architecture

`workflow.nyquist_validation` is not set in `.planning/config.json` (key absent) — treated as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat 3 |
| Config file | `Config/testthat/edition: 3` in DESCRIPTION; no separate config file |
| Quick run command | `devtools::test(filter = "docs")` or `Rscript -e "devtools::test(filter='sections-example')"` |
| Full suite command | `devtools::test()` or `R CMD check --no-manual` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCS-01 | `data(example_sections_counts)` loads a data frame with `section` column | unit | `devtools::test(filter = "example-sections")` | No — Wave 0 |
| DOCS-01 | Dataset has 3 distinct section values with materially different effort levels | unit | same | No — Wave 0 |
| DOCS-01 | `data(example_sections_interviews)` has `section` column and 3 sections | unit | same | No — Wave 0 |
| DOCS-02 | Vignette builds without error: `devtools::build_vignettes()` | smoke | `devtools::build_vignettes()` | No — Wave 0 |
| DOCS-02 | `estimate_effort()` on example dataset returns 4-row tibble (3 sections + `.lake_total`) | integration | `devtools::test(filter = "example-sections")` | No — Wave 0 |
| DOCS-02 | `estimate_catch_rate()` returns no `.lake_total` row | integration | same | No — Wave 0 |
| DOCS-02 | `estimate_total_catch()` with `aggregate_sections = TRUE` returns 4 rows | integration | same | No — Wave 0 |
| DOCS-02 | Missing-section demo produces NA row and warning | integration | same | No — Wave 0 |

### Sampling Rate

- **Per task commit:** `devtools::test(filter = "example-sections")`
- **Per wave merge:** `devtools::test()`
- **Phase gate:** Full suite green (`devtools::test()`) + `devtools::build_vignettes()` before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/testthat/test-example-sections.R` — covers DOCS-01 dataset shape + DOCS-02 estimator integration
- [ ] `data-raw/example_sections_calendar.R` — creates calendar dataset
- [ ] `data-raw/example_sections_counts.R` — creates counts dataset with material section variation
- [ ] `data-raw/example_sections_interviews.R` — creates interviews dataset with varying catch rates across sections
- [ ] `data/example_sections_calendar.rda` — serialised dataset (generated by data-raw script)
- [ ] `data/example_sections_counts.rda` — serialised dataset
- [ ] `data/example_sections_interviews.rda` — serialised dataset
- [ ] `R/data.R` entries for all three new datasets (roxygen2 `@format` blocks)
- [ ] `vignettes/section-estimation.Rmd` — the new vignette

---

## Sources

### Primary (HIGH confidence)

- Project source: `data-raw/example_counts.R`, `data-raw/create_example_interviews.R` — confirmed dataset construction pattern
- Project source: `R/data.R` — confirmed roxygen2 `@format` documentation pattern
- Project source: `vignettes/bus-route-surveys.Rmd`, `vignettes/tidycreel.Rmd` — confirmed vignette YAML header pattern
- Project source: `tests/testthat/test-estimate-effort.R` lines 42–86 — canonical 3-section fixture data (North/Central/South effort levels)
- Project source: `tests/testthat/test-estimate-total-catch.R` lines 554–735 — canonical 3-section fixture with interviews
- Project source: `.planning/STATE.md` section "v0.7.0 Architectural Decisions (locked)" — variance aggregation, CPUE non-additivity, product estimator aggregation decisions

### Secondary (MEDIUM confidence)

- DESCRIPTION `Suggests`: `knitr`, `rmarkdown` already present — no new dependencies needed

---

## Metadata

**Confidence breakdown:**
- Dataset pattern: HIGH — directly read from five existing data-raw scripts and R/data.R
- Vignette pattern: HIGH — directly read from seven existing vignettes
- Fixture data shape: HIGH — directly read from test helpers in test-estimate-effort.R and test-estimate-total-catch.R
- Variance narrative content: HIGH — locked decision text in STATE.md
- Test file gaps: HIGH — confirmed no test-example-sections.R exists

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (stable project, no external dependencies changing)
