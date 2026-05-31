# Simulate catch counts from a distributional family

Generates catch observations from one of three distributional families:
Negative Binomial (`"negbin"`), zero-inflated lognormal / Delta
(`"delta"`), or Poisson. Intended for distributional sensitivity
analysis, power checks, and Petrere-style estimator comparisons.

## Usage

``` r
simulate_creel_catch(
  n,
  effort = 1,
  family = c("negbin", "delta", "poisson"),
  mu = 5,
  size = 0.5,
  p_zero = 0.4,
  sigma = 1,
  var_structure = c("constant", "proportional", "squared"),
  seed = NULL
)
```

## Arguments

- n:

  Integer. Number of catch observations to generate.

- effort:

  Numeric vector of length `n` or scalar. Effort values (e.g.
  angler-hours) for each observation. Used to scale catch under
  `var_structure = "proportional"` or `"squared"`.

- family:

  Character. Distribution family: `"negbin"` (default), `"delta"`, or
  `"poisson"`.

- mu:

  Numeric. Mean catch rate (catch per unit effort). Default 5.

- size:

  Numeric. Negative Binomial dispersion parameter (NB size). Ignored
  when `family = "poisson"`. Default 0.5.

- p_zero:

  Numeric in \[0, 1). Zero-inflation probability for `family = "delta"`.
  Default 0.40.

- sigma:

  Numeric. Log-scale standard deviation for `family = "delta"` (positive
  values only). Default 1.0.

- var_structure:

  Character. Error variance structure. `"constant"` (default): variance
  independent of effort; `"proportional"`: \\Var \propto f\\;
  `"squared"`: \\Var \propto f^2\\.

- seed:

  Integer or `NULL`. Random seed. Default `NULL`.

## Value

Integer vector of length `n` containing simulated catch counts.

## Details

**Delta distribution** (Petrere et al. 2010, Table 1): A mixture of a
point mass at zero (probability `p_zero`) and a lognormal distribution
for positive values (parameters `mu` and `sigma` on the log scale).
Closely matches empirical creel catch distributions.

**Variance structures** (Petrere et al. 2010):

- `constant`: \\\varepsilon_i \sim N(0, \sigma^2)\\

- `proportional`: \\\varepsilon_i \sim N(0, \sigma^2 f_i)\\

- `squared`: \\\varepsilon_i \sim N(0, \sigma^2 f_i^2)\\

## References

Petrere, M. et al. (2010). Catch-per-unit-effort: which estimator is
best? Fish. Res. 106: 325–333.

## See also

[`simulate_creel_data`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md)

Other "Simulation":
[`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md)

## Examples

``` r
set.seed(1)
# NB catch (default)
catch_nb <- simulate_creel_catch(n = 200, effort = 3.0, mu = 5, size = 0.5)
mean(catch_nb); var(catch_nb)
#> [1] 5.425
#> [1] 54.60741

# Delta distribution (zero-inflated lognormal)
catch_d <- simulate_creel_catch(
  n = 500, effort = 3.0, family = "delta",
  p_zero = 0.45, mu = 1.6, sigma = 0.8
)
mean(catch_d == 0)  # ~0.45
#> [1] 0.504

# Proportional variance structure
effort <- rgamma(100, shape = 2.5, rate = 0.57)
catch_prop <- simulate_creel_catch(
  n = 100, effort = effort, mu = 4,
  var_structure = "proportional"
)
```
