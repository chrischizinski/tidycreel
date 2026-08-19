# Estimate Catch Per Unit Effort (CPUE)

Estimates catch per unit effort by species, mode, or other grouping
variables. Supports both number-based (fish per hour) and weight-based
(kg per hour) CPUE.

## Usage

``` r
estimate_cpue(
  design,
  by = NULL,
  species = NULL,
  type = c("number", "weight"),
  level = 0.95
)
```

## Arguments

- design:

  A creel design object created by [`design_access`](design_access.md),
  [`design_roving`](design_roving.md), or
  [`design_repweights`](design-constructors.md).

- by:

  Character vector of variables to group estimates by. Default is to
  estimate overall CPUE.

- species:

  Character vector of species to include. If NULL, includes all species
  in the data.

- type:

  Character, either "number" (fish per hour) or "weight" (kg per hour).
  Default "number".

- level:

  Confidence level for confidence intervals. Default 0.95.

## Value

A tibble with columns:

- group_vars:

  Grouping variables as a list column

- n:

  Number of interviews in group

- cpue_estimate:

  Estimated CPUE

- cpue_se:

  Standard error of CPUE estimate

- cpue_lower:

  Lower confidence limit

- cpue_upper:

  Upper confidence limit

- species:

  Species included in estimate

- type:

  Type of CPUE (number or weight)

- design_type:

  Type of survey design used

## Examples

``` r
if (FALSE) { # \dontrun{
# Estimate CPUE by species
cpue_by_species <- estimate_cpue(design, by = "target_species")

# Estimate weight-based CPUE for bass
bass_cpue_weight <- estimate_cpue(design, species = "bass", type = "weight")
} # }
```
