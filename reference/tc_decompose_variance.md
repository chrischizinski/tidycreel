# Decompose Variance into Components

Decomposes total variance into component sources for creel survey
estimates. Built-in to tidycreel estimators through the
`decompose_variance` parameter.

## Usage

``` r
tc_decompose_variance(
  design,
  response,
  cluster_vars = c("stratum"),
  method = "anova",
  conf_level = 0.95
)
```

## Arguments

- design:

  Survey design object

- response:

  Response variable (formula or character)

- cluster_vars:

  Character vector of clustering variables in order of nesting (e.g.,
  c("stratum", "day", "shift"))

- method:

  Decomposition method:

  "anova"

  :   ANOVA-based decomposition (default)

  "mixed_model"

  :   Mixed model variance components

  "survey_weighted"

  :   Survey-weighted decomposition

- conf_level:

  Confidence level for component intervals (default 0.95)

## Value

List with class "tc_variance_decomp" containing:

- components:

  Data frame of variance components

- proportions:

  Proportion of total variance by component

- intraclass_correlations:

  ICC values

- design_effects:

  Design effects by component

- optimal_allocation:

  Recommended sample allocation

- variance_ratios:

  Ratios for sample size planning

- method:

  Decomposition method used

## Details

### Variance Component Model

For nested creel survey structure: \$\$Y\_{ijkl} = \mu + \alpha_i +
\beta\_{j(i)} + \gamma\_{k(ij)} + \epsilon\_{l(ijk)}\$\$

Where:

- \\\alpha_i\\ = stratum effect (among-stratum variance)

- \\\beta\_{j(i)}\\ = day effect within stratum (among-day variance)

- \\\gamma\_{k(ij)}\\ = shift effect within day (among-shift variance)

- \\\epsilon\_{l(ijk)}\\ = residual (within-shift variance)

### Key Applications

- **Optimal Allocation**: Determine optimal days vs counts per day

- **Design Effects**: Quantify clustering impact

- **Sample Size Planning**: Use variance ratios for power analysis

- **Efficiency Analysis**: Identify largest variance sources

## Examples

``` r
if (FALSE) { # \dontrun{
# Decompose variance for effort estimate
decomp <- tc_decompose_variance(
  design = creel_design,
  response = "effort_hours",
  cluster_vars = c("stratum", "day")
)

# View components
print(decomp)
decomp$components
decomp$proportions

# Optimal allocation recommendations
decomp$optimal_allocation
} # }
```
