# Calculate Optimal Sample Allocation

Uses variance component decomposition results to calculate optimal
allocation of sampling effort across different levels of the survey
design.

## Usage

``` r
optimal_allocation(
  variance_decomp,
  total_budget = NULL,
  cost_per_unit = NULL,
  precision_target = 0.1
)
```

## Arguments

- variance_decomp:

  A variance_decomp object from
  [`decompose_variance`](decompose_variance.md)

- total_budget:

  Total sampling budget (in units or cost)

- cost_per_unit:

  Named vector of costs per sampling unit at each level

- precision_target:

  Target precision (coefficient of variation) for estimates

## Value

List containing optimal allocation recommendations

## Examples

``` r
if (FALSE) { # \dontrun{
# Calculate optimal allocation
var_decomp <- decompose_variance(design, ~anglers_count)

allocation <- optimal_allocation(
  var_decomp,
  total_budget = 1000,
  cost_per_unit = c("day" = 50, "shift" = 20),
  precision_target = 0.10
)
} # }
```
