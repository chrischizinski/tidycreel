# Decompose Variance Components in Creel Survey Estimates

Decomposes the total variance of creel survey estimates into component
sources (within-day, among-day, within-shift, etc.) using survey design
objects to guide optimal sampling design and allocation decisions.

## Usage

``` r
decompose_variance(
  design,
  response,
  by = NULL,
  method = "survey",
  n_bootstrap = 1000,
  conf_level = 0.95,
  cluster_vars = c("stratum"),
  finite_pop = TRUE
)
```

## Arguments

- design:

  Survey design object from [`as_day_svydesign`](as_day_svydesign.md) or
  [`svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)

- response:

  Formula or character string specifying the response variable for
  decomposition (e.g., "anglers_count" or ~anglers_count)

- by:

  Character vector of grouping variables for stratified decomposition

- method:

  Method for variance decomposition. Options:

  "survey"

  :   Survey-weighted decomposition using survey package (default)

  "bootstrap"

  :   Bootstrap-based variance decomposition

  "jackknife"

  :   Jackknife variance decomposition

  "linearization"

  :   Taylor linearization (for complex estimates)

- n_bootstrap:

  Number of bootstrap replicates (if method = "bootstrap")

- conf_level:

  Confidence level for variance component intervals (default 0.95)

- cluster_vars:

  Character vector specifying clustering variables in order of nesting
  (e.g., c("stratum", "day", "shift"))

- finite_pop:

  Logical, whether to apply finite population correction

## Value

List with class "variance_decomp" containing:

- components:

  Data frame of variance components with estimates and confidence
  intervals

- proportions:

  Proportion of total variance explained by each component

- intraclass_correlations:

  Intraclass correlation coefficients

- design_effects:

  Design effects for different sampling strategies

- optimal_allocation:

  Recommended allocation across levels

- variance_ratios:

  Ratios used for sample size determination

- nested_structure:

  Description of the hierarchical structure

- method_info:

  Information about the decomposition method used

- sample_sizes:

  Sample sizes at each level

## Details

### Variance Component Model

For a typical creel survey with nested structure:

    Y_ijkl = μ + α_i + β_j(i) + γ_k(ij) + ε_l(ijk)

Where:

- Y_ijkl = observed value (e.g., angler count)

- μ = overall mean

- α_i = stratum effect (among-stratum variance)

- β_j(i) = day effect within stratum (among-day variance)

- γ_k(ij) = shift effect within day (among-shift variance)

- ε_l(ijk) = residual error (within-shift variance)

### Key Variance Components

1.  **Among-Day Variance (σ²_b)**: Variation between different days

2.  **Within-Day Variance (σ²_w)**: Variation within days (between
    shifts/counts)

3.  **Among-Shift Variance**: Variation between shifts within days

4.  **Residual Variance**: Unexplained variation

### Applications

- **Optimal Allocation**: Determine optimal number of days vs counts per
  day

- **Design Effects**: Quantify impact of clustering on precision

- **Sample Size Planning**: Use variance ratios for power calculations

- **Survey Efficiency**: Identify largest sources of variation

### Intraclass Correlation

ICC = σ²_between / (σ²_between + σ²_within)

High ICC indicates strong clustering (similar values within clusters)

## References

Rasmussen, P.W., Heisey, D.M., Nordheim, E.V., and Frost, T.M. (1998).
Time-series intervention analysis: unreplicated large-scale experiments.
In *Scheiner, S.M. and Gurevitch, J. (eds.) Design and Analysis of
Ecological Experiments*. Oxford University Press.

## See also

[`est_effort`](est_effort.md),
[`optimal_allocation`](optimal_allocation.md),
[`plot.variance_decomp`](plot.variance_decomp.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic variance decomposition
effort_est <- est_effort(design, by = "stratum")
var_decomp <- decompose_variance(
  effort_est = effort_est,
  data = counts_data,
  level = c("day", "stratum"),
  components = c("within_day", "among_day")
)

# Comprehensive decomposition with shifts
var_decomp <- decompose_variance(
  effort_est = effort_est,
  data = counts_data,
  level = c("shift", "day", "stratum"),
  components = c("within_shift", "among_shift", "among_day"),
  shift_col = "shift_block"
)

# Print results
print(var_decomp)

# Plot variance components
plot(var_decomp)
} # }
```
