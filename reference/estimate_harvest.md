# Estimate Total Harvest

Estimates total harvest (catch kept) by species, mode, or other grouping
variables. Supports both number-based (count) and weight-based (kg)
harvest.

## Usage

``` r
estimate_harvest(
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
  estimate overall harvest.

- species:

  Character vector of species to include. If NULL, includes all species
  in the data.

- type:

  Character, either "number" (count) or "weight" (kg). Default "number".

- level:

  Confidence level for confidence intervals. Default 0.95.

## Value

A tibble with columns:

- group_vars:

  Grouping variables as a list column

- n:

  Number of interviews in group

- harvest_estimate:

  Estimated total harvest

- harvest_se:

  Standard error of harvest estimate

- harvest_lower:

  Lower confidence limit

- harvest_upper:

  Upper confidence limit

- species:

  Species included in estimate

- type:

  Type of harvest (number or weight)

- design_type:

  Type of survey design used

## Examples

``` r
if (FALSE) { # \dontrun{
# Estimate harvest by species
harvest_by_species <- estimate_harvest(design, by = "target_species")

# Estimate weight-based harvest for walleye
walleye_harvest_weight <- estimate_harvest(design, species = "walleye", type = "weight")
} # }
```
