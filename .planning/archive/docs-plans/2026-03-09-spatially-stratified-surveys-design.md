# Design: Spatially Stratified Creel Surveys (v0.7.0)

**Date:** 2026-03-09
**Status:** Approved

---

## Background

tidycreel currently uses a two-dimensional stratum structure: day type × temporal period.
Sections already exist as a label in both the counts and interviews data (`section_col` in
`creel_design()`), but all NGPC surveys currently use a single section value — sections
have never been used as independent estimation domains.

Two real use cases require true spatial stratification:

1. **Multi-clerk sectioned surveys** — large waterbodies where separate crews cover
   distinct sections; each section has its own counts, its own interview sample, and
   must be estimated independently before being combined for a lake-wide total.

2. **Domain estimation by fishing location** — a single survey design, but
   catch/harvest estimates are needed separately for spatial domains (e.g., north inlet,
   main basin, south outlet) based on where interviewed anglers report fishing and where
   counts were conducted.

Both cases share the same root requirement: sections must be explicitly declared so that
mislabeled data is caught at ingestion time, not silently incorporated into wrong-stratum
estimates.

---

## Design Goals

- Explicit section registration as the contract for all spatial data
- Validation at `add_counts()` and `add_interviews()` (not at estimation time)
- Independent per-section effort and catch-rate estimation
- Correct variance propagation when combining sections into lake totals
- Section metadata (area, shoreline) stored now for aerial survey support in v0.8.0
- Zero breaking changes to single-section surveys

---

## New Function: `add_sections()`

```r
add_sections(
  design,
  sections,           # data frame, one row per section
  section_col,        # <tidy-select> column with section name/ID
  description_col,    # <tidy-select> optional free-text description
  area_col,           # <tidy-select> optional surface area (ha)
  shoreline_col       # <tidy-select> optional shoreline length (km)
)
```

### Position in the pipeline

Slots between `creel_design()` and `add_counts()`. Optional: if not called, existing
single-section behavior is unchanged.

### Validation

- Duplicate section names → `cli_abort()`
- `section_col` values must be character or factor → `cli_abort()` otherwise
- `area_col` and `shoreline_col`, if provided, must be positive numeric → `cli_abort()`
- On success: stores `design$sections` data frame

### Design object additions

```
design$sections       # registered metadata data frame (name, description, area_ha, shoreline_km)
design$section_col    # already present; now has registered values to validate against
```

`format.creel_design()` gains a sections block:

```
Sections: 3 registered
  North Inlet  (45.0 ha,  8.2 km shoreline) — Tributary inlet
  Main Basin   (820.0 ha, 62.1 km shoreline) — Open water
  South Outlet (12.0 ha,   3.4 km shoreline) — Dam outlet
```

---

## Validation at Data Attachment

When `add_sections()` has been called, subsequent data attachment functions validate
section values against the registry:

### `add_counts()`

- Every row's section value must appear in `design$sections[[section_col]]`
- Unregistered value → `cli_abort()` naming the bad value(s) and showing valid options
- Missing section value (NA) → `cli_abort()`

### `add_interviews()`

- Same validation; applied to interview section column
- Unregistered value → `cli_abort()` with same informative message

This mirrors existing immutability and consistency guards (e.g., `design[["catch"]]`
double-bracket guard, `add_catch()` consistency check).

---

## Estimation Behavior

### Per-section effort estimation

When sections are registered, `estimate_effort()` computes independently per
section × day_type × period stratum cell using the standard Pollock formula:

```
Ê_{s,d,p} = D_{s,d,p} × L_{s,d,p} × ȳ_{s,d,p}
```

where all three quantities are computed from counts assigned to section `s`.

### Per-section catch/harvest/CPUE estimation

Ratio-of-means (or mean-of-ratios for roving) applied within each section stratum cell
using only interviews where the angler fished in section `s`:

```
R̂_{s,d,p} = (Σ catch_i) / (Σ effort_i)    for i in section s, day_type d, period p
```

### Combining sections for lake totals

Lake-wide total = sum of section totals. Variance is additive under independent
section sampling (Cochran 1977, Theorem 5.2):

```
Ê_total  = Σ_s Ê_s
V̂(Ê_total) = Σ_s V̂(Ê_s)
```

### `aggregate_sections` argument

All estimators gain `aggregate_sections = FALSE` (default) which returns section-level
results. Set to `TRUE` for lake-wide totals with correct variance aggregation.

```r
# Section-level results
estimate_effort(design)

# Lake-wide total
estimate_effort(design, aggregate_sections = TRUE)
```

---

## Partial Coverage Handling

When a section has no count observations for a given stratum cell (weather, crew
availability, scheduling):

- **Default:** `cli_warn()` — warns which section × stratum cell is unsampled, excludes
  it from lake total with a note in the output
- **Strict mode:** `missing_sections = "error"` — `cli_abort()` if any section goes
  unsampled in any stratum cell
- **Future (v0.8.0):** model-based imputation for aerial zone coverage gaps

The lake total when sections have partial coverage is the sum over *sampled* sections
only, with a coverage fraction attribute on the result tibble.

---

## Pipeline Example

```r
library(tidycreel)
library(tibble)

my_sections <- tibble(
  section      = c("North Inlet", "Main Basin", "South Outlet"),
  description  = c("Tributary inlet", "Open water", "Dam outlet"),
  area_ha      = c(45.0, 820.0, 12.0),
  shoreline_km = c(8.2, 62.1, 3.4)
)

design <- creel_design(
  data        = my_counts,
  strata_cols = c(day_type, period),
  section_col = section,
  ...
) |>
  add_sections(
    my_sections,
    section_col     = section,
    description_col = description,
    area_col        = area_ha,
    shoreline_col   = shoreline_km
  ) |>
  add_counts(counts_df, ...) |>
  add_interviews(interviews_df, ...)

# Section-level effort
estimate_effort(design)

# Lake total
estimate_effort(design, aggregate_sections = TRUE)

# Section-level harvest by species
estimate_total_harvest(design, by = species)
```

---

## What Does Not Change

- Single-section surveys: `add_sections()` is not called; existing behavior unchanged
- All existing estimator APIs: `aggregate_sections` is additive, not breaking
- `strata_cols`: section is NOT added to strata_cols; it is a separate spatial dimension
  managed by the sections registry
- Bus-route surveys: unaffected; bus-route handles spatial heterogeneity via inclusion
  probabilities, not section strata

---

## Scope for v0.7.0

In scope:
- `add_sections()` function with validation
- `format.creel_design()` sections block
- Per-section effort, CPUE, catch, harvest, release estimation
- `aggregate_sections` argument on all estimators
- Partial coverage warning/error handling
- Tests and documentation

Deferred to v0.8.0 (aerial surveys):
- `area_ha` and `shoreline_km` used in estimation (stored now, not yet used)
- Zone geometry for partial aerial coverage calculation
- Detectability correction per section
- Model-based imputation for unsampled sections

---

## Literature

- Pollock, Jones, and Brown (1994) — AFS Special Publication 25 — foundational framework
- Jones and Pollock (2012) — Fisheries Techniques 3rd ed., Chapter 19
- Cochran (1977) — Sampling Techniques, Theorems 5.1, 5.2, 5.5
- Vølstad, Pollock, and Richkus (2006) — NAJFM 26:727–741 — Delaware River 4-zone design
- Soupir et al. (2006) — Missouri River reservoirs spatial stratification
