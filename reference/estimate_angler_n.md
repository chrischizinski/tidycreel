# Estimate angler population size via closed-population mark-recapture

Computes a closed-population mark-recapture estimate of total angler
population size (N_hat) using one of three estimators:

- **Chapman** (default, `method = "chapman"`): A bias-corrected version
  of the Petersen estimator recommended when recaptures are small.
  \\\hat{N} = \frac{(M+1)(n+1)}{(m+1)} - 1\\

- **Petersen** (`method = "petersen"`): The unadjusted Lincoln-Petersen
  estimator. Requires at least 7 recaptures (\\m \geq 7\\) to avoid
  large positive bias; use Chapman for smaller recapture counts.
  \\\hat{N} = \frac{M \cdot n}{m}\\

- **Schnabel** (`method = "schnabel"`): A multi-occasion weighted
  estimator for \\K \geq 2\\ sampling occasions, carrying
  Chapman's (1952) small-sample correction by default. \\\hat{N} =
  \frac{\sum M_k n_k}{\sum m_k + 1}\\ CI uses the Poisson branch when
  \\\sum m_k \< 50\\ and the normal approximation on \\1/\hat{N}\\
  otherwise, on \\K - 1\\ degrees of freedom (Hansen & Van Kirk 2018,
  eq. A.5).

- **Schumacher-Eschmeyer** (`method = "schumacher"`): The regression
  alternative to Schnabel for \\K \geq 3\\ occasions, fitting
  \\m_k/n_k\\ against \\M_k\\ through the origin with slope \\1/N\\.
  \\\hat{N} = \frac{\sum n_k M_k^2}{\sum m_k M_k}\\ Interval from
  Seber (1982) eq. (4.17) on \\K - 2\\ degrees of freedom. Also carries
  Dettloff's (2023) eq. (8) small-sample correction by default.

## Usage

``` r
estimate_angler_n(
  M,
  n,
  m,
  method = "chapman",
  conf_level = 0.95,
  ci_method = c("logit", "delta", "bootstrap"),
  B = 2000L,
  bias_adjust = TRUE
)
```

## Arguments

- M:

  integer or numeric. Number of marked animals released (first sample).
  For `method = "schnabel"`, a vector of cumulative marked-at-large
  counts before each sampling occasion (`M[1] = 0`).

- n:

  integer or numeric. Number captured in second sample. For Schnabel, a
  vector of per-occasion catch counts (same length as `M`).

- m:

  integer or numeric. Number of recaptures. Scalar for Chapman and
  Petersen; vector (same length as `M`) for Schnabel.

- method:

  character(1). One of `"chapman"` (default), `"petersen"`,
  `"schnabel"`, or `"schumacher"`.

- conf_level:

  numeric. Confidence level for the CI. Default `0.95`.

- ci_method:

  character(1). CI construction for the Chapman and Petersen branches:
  `"logit"` (default) is Sadinle's (2009) 0.5 transformed logit
  interval; `"delta"` is the symmetric Wald interval \\\hat{N} \pm
  t\_{\alpha/2,\\m-1} SE(\hat{N})\\ that was the default before 3.0.0;
  `"bootstrap"` keeps the `"logit"` bounds and additionally appends
  `ci_lo_boot` and `ci_hi_boot` columns from a parametric bootstrap via
  [`stats::rbinom()`](https://rdrr.io/r/stats/Binomial.html), attaching
  `attr(result, "boot_samples")`. The Schnabel branch ignores this
  argument for its analytic bounds — it always inverts Poisson quantiles
  or uses the \\t\\ approximation on \\1/\hat{N}\\, per Hansen & Van
  Kirk (2018) — but still honours `"bootstrap"` for the extra columns.

- B:

  integer(1). Number of bootstrap replicates when
  `ci_method = "bootstrap"`. Default `2000L`.

- bias_adjust:

  logical(1). Multi-occasion methods only; ignored by the Chapman and
  Petersen branches, which carry their own bias handling. `TRUE`
  (default, new in 3.0.0) applies the small-sample correction —
  Chapman's (1952), dividing by \\\sum m_k + 1\\, for Schnabel, and
  Dettloff's (2023) eq. (8) for Schumacher-Eschmeyer. `FALSE` restores
  the unadjusted forms, which are what `fishmethods::schnabel()`
  computes for both and, for Schnabel, the only form available before
  3.0.0.

## Value

A `creel_estimates` S3 object with `method = "mark-recapture-chapman"`
(or petersen/schnabel) and an `estimates` tibble with columns:
`parameter`, `estimate`, `se`, `ci_lower`, `ci_upper`, `n` (total
recaptures).

## Details

**Why the Chapman and Petersen default is not a Wald interval.**
\\\hat{N}\\ is a ratio with a small integer denominator, so its sampling
distribution is strongly right-skewed and a symmetric interval leaves
the parameter space. Evans et al. (1996) measured Wald coverage failing
on one side 27.9\\ and Dettloff (2023) report the same. With `M = 200`,
`n = 50` and `m = 3` the Wald lower bound is `-2124.8`; at `m = 5` it is
`48.7`, below the 245 individuals actually observed. Chapman is
recommended precisely when recaptures are few, so this is the regime the
default estimator is chosen for.

The default `"logit"` interval is Sadinle's (2009) 0.5 transformed
logit, built on the \\2 \times 2\\ capture table (\\n\_{11} = m\\,
\\n\_{12} = M - m\\, \\n\_{21} = n - m\\) with 0.5 added to each cell.
Sadinle compared nine intervals and found it "the best of the intervals
reported here", with near-nominal coverage even for small populations
and capture probabilities near 0 or 1, where profile-likelihood and
Monte Carlo intervals both degrade. Its lower limit is guaranteed never
to fall below \\n\_{11} + n\_{12} + n\_{21}\\, the number of individuals
actually seen — the property the Wald interval lacks. It is closed-form
and always computable, since the 0.5 continuity correction removes every
zero-count division.

**One consequence worth knowing.** When \\m = n\\ — every individual in
the second sample was already marked — the estimator saturates at
\\\hat{N} = M\\, which is also the observed count. The logit lower limit
then sits fractionally *above* \\\hat{N}\\, because the data imply \\N
\> M\\ rather than \\N = M\\. This is the interval being informative at
a boundary, not an error; pass `ci_method = "delta"` if a bound that
brackets the point estimate matters more than coverage.

`ci_method = "delta"` reproduces the pre-3.0.0 bounds exactly.

**Choosing between Schnabel and Schumacher-Eschmeyer, and a warning
about how not to.** They use identical field data and differ in how they
pool it: Schnabel is a ratio of sums, Schumacher-Eschmeyer a weighted
regression through the origin. Seber (1982) expects the regression form
"to be robust with regard to departures from the underlying assumptions"
and recommends using it "in conjunction with the other methods" — as a
cross-check, not a replacement. That is a weaker claim than it is
sometimes reported as; Seber neither demonstrates the robustness nor
calls it the most robust method. Dettloff (2023) found the two adjusted
forms "effectively equivalent at larger sample sizes", with
Schumacher-Eschmeyer less variable and Schnabel reaching unbiasedness
slightly sooner.

**Do not pick whichever gives the narrower interval.** Hansen & Van Kirk
(2018) computed both and "selected the mark-recapture estimator that
produced the smallest 95\\ the narrower of two intervals after seeing
them conditions on the luckier draw, so the reported interval is
narrower than its nominal level. tidycreel therefore does not implement
the selection rule. Decide between the estimators on design grounds
before looking at the answer, or report both.

**The Schnabel upper bound at very few recaptures.** The Poisson
interval inverts the distribution of \\\sum m_k\\, so it needs the lower
quantile \\q\_{\alpha/2}\\ in its denominator. That quantile is *zero*
whenever \\\sum m_k \leq 3\\ at the 95\\ `Inf`. Following Hansen & Van
Kirk (2018) eq. (A.4), tidycreel substitutes Ilienko's (2013) continuous
Poisson in exactly that case — it has distribution function \\\Gamma(x,
\lambda)/\Gamma(x)\\, is positive there, and so returns a finite bound.
The substitution fires only where the discrete quantile is zero; from
\\\sum m_k \geq 4\\ the continuous quantile sits just above the discrete
one, so this is a targeted patch rather than a change of method.

**Read that bound for what it is.** It comes from a continuous
interpolation of a discrete distribution at one to three total
recaptures, not from the data, and it is wide. It stands in for "the
data do not bound this above" rather than measuring anything, which is
why the function still warns when it fires. Ilienko's construction is
the genuine interpolant — his eq. (1) shows the same expression returns
the discrete Poisson CDF at integer \\x\\ — but interpolating at \\\sum
m_k = 1\\ is still interpolating.

**Where the Petersen \\m \geq 7\\ guard comes from.** The threshold is a
practical stand-in, not a derivation, and it is worth knowing why no
exact one is available. Robson & Regier (1964) give two conditions:
Chapman is exactly unbiased when \\M + n \geq N\\, and its negative bias
stays under 2\\ \\\sqrt{Mn} \geq 2\sqrt{N}\\ — the geometric mean of
marks and captures at least twice the square root of the population
size. Both depend on \\N\\, the unknown being estimated. Dettloff (2023)
calls this "paradoxical" and treats such rules as "a way of avoiding
inaccurate estimates from absurdly small sample sizes based on an
educated guess of the order of magnitude" of \\N\\. A fixed \\m\\
threshold is that guess made concrete; it rules out the regime where
Petersen's positive bias is severe without pretending to a precision the
conditions cannot deliver. Chapman is the better default at any
recapture count and is what the error message points to.

**Why Schnabel is bias-adjusted by default.** Each \\m_k\\ is
approximately Poisson with parameter \\M_k n_k / N\\, which motivated
Chapman's (1952) \\+1\\ correction to the recapture total. Dettloff
(2023) simulated both forms and found the unadjusted estimator turns
biased *high* at moderate sample sizes before settling, whereas the
adjusted form has bias that "approaches zero as the sample size
increases without ever becoming positive", with lower variance and no
cost at large samples; he recommends the adjusted estimators "in place
of the originals in all scenarios". The package already defaults to the
analogous \\+1\\ correction at two occasions (`method = "chapman"`), and
Schnabel reduces exactly to Lincoln-Petersen at \\K = 2\\, so leaving
Schnabel unadjusted made bias handling depend on how many occasions were
sampled. The relative shift is \\-1/(\sum m_k + 1)\\: −33\\ 500. Pass
`bias_adjust = FALSE` for the previous form.

## References

Hansen, J. M., & Van Kirk, R. W. (2018). A mark-recapture-based approach
for estimating angler harvest. *North American Journal of Fisheries
Management*, 38(2), 400–410.
[doi:10.1002/nafm.10038](https://doi.org/10.1002/nafm.10038)

Sadinle, M. (2009). Transformed logit confidence intervals for small
populations in single capture-recapture estimation. *Communications in
Statistics - Simulation and Computation*, 38(9), 1909–1924.
[doi:10.1080/03610910903168595](https://doi.org/10.1080/03610910903168595)

Evans, M. A., Kim, H.-M., & O'Brien, T. E. (1996). An application of
profile-likelihood based confidence interval to capture-recapture
estimators. *Journal of Agricultural, Biological, and Environmental
Statistics*, 1(1), 131–140.
[doi:10.2307/1400565](https://doi.org/10.2307/1400565)

Dettloff, K. (2023). Assessment of bias and precision among simple
closed population mark-recapture estimators. *Fisheries Research*, 265,
106756.
[doi:10.1016/j.fishres.2023.106756](https://doi.org/10.1016/j.fishres.2023.106756)

Chapman, D. G. (1952). Inverse, multiple and sequential sample censuses.
*Biometrics*, 8(4), 286–306.
[doi:10.2307/3001864](https://doi.org/10.2307/3001864)

Robson, D. S., & Regier, H. A. (1964). Sample size in Petersen
mark-recapture experiments. *Transactions of the American Fisheries
Society*, 93(3), 215–226.
[doi:10.1577/1548-8659(1964)93\[215:SSIPME\]2.0.CO;2](https://doi.org/10.1577/1548-8659%281964%2993%5B215%3ASSIPME%5D2.0.CO%3B2)

Ilienko, A. (2013). Continuous counterparts of Poisson and binomial
distributions and their properties. *Annales Universitatis Scientiarum
Budapestinensis de Rolando Eotvos Nominatae, Sectio Computatorica*, 39,
137–147.

Schnabel, Z. E. (1938). The estimation of the total fish population of a
lake. *The American Mathematical Monthly*, 45(6), 348–352.
[doi:10.2307/2304025](https://doi.org/10.2307/2304025)

Chapman, D. G. (1951). Some properties of the hypergeometric
distribution with applications to zoological sample censuses.
*University of California Publications in Statistics*, 1(7), 131–160.

Schumacher, F. X., & Eschmeyer, R. W. (1943). The estimation of fish
populations in lakes or ponds. *Journal of the Tennessee Academy of
Science*, 18, 228–249.

Seber, G. A. F. (1982). *The Estimation of Animal Abundance and Related
Parameters*, 2nd ed. Macmillan, New York.

De Lury, D. B. (1958). The estimation of population size by a marking
and recapture procedure. *Journal of the Fisheries Research Board of
Canada*, 15(1), 19–25.
[doi:10.1139/f58-002](https://doi.org/10.1139/f58-002)

## See also

Other Estimation:
[`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md),
[`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)

## Examples

``` r
# Chapman (default) — bias-corrected Petersen
result <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
print(result)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: mark-recapture-chapman
#> Variance: chapman
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 6
#>   parameter estimate    se ci_lower ci_upper     n
#>   <chr>        <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 N_hat         931.  232.     605.    1715.    10

# Petersen — requires m >= 7
result_p <- estimate_angler_n(M = 200L, n = 50L, m = 10L, method = "petersen")
print(result_p)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: mark-recapture-petersen
#> Variance: petersen
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 6
#>   parameter estimate    se ci_lower ci_upper     n
#>   <chr>        <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 N_hat         1000  283.     605.    1715.    10

# Schnabel — multi-occasion with parallel vectors
result_s <- estimate_angler_n(
  M = c(0L, 47L, 91L, 131L),
  n = c(50L, 50L, 50L, 50L),
  m = c(0L,  4L,  6L,  8L),
  method = "schnabel"
)
print(result_s)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: mark-recapture-schnabel
#> Variance: delta
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 6
#>   parameter estimate    se ci_lower ci_upper     n
#>   <chr>        <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 N_hat         708.  158.     498.     1345    18

# Schumacher-Eschmeyer — the regression alternative, needs >= 3 occasions
result_se <- estimate_angler_n(
  M = c(0L, 47L, 91L, 131L),
  n = c(50L, 50L, 50L, 50L),
  m = c(0L,  4L,  6L,  8L),
  method = "schumacher"
)
print(result_se)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: mark-recapture-schumacher
#> Variance: delta
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 6
#>   parameter estimate    se ci_lower ci_upper     n
#>   <chr>        <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 N_hat         699.  44.7     548.     964.    18
```
