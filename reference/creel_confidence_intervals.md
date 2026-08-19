# Confidence interval conventions in tidycreel

Estimators in this package do not all build confidence intervals the
same way, because the quantities they estimate do not all live on the
same scale or carry the same information about their own uncertainty.
This topic states the two rules the package follows, so that a new
estimator does not have to pick by coin flip.

## Bounded quantities

Effort, catch, harvest, release, biomass, abundance and catch rates are
all bounded below by zero, and exploitation rate is bounded on both
sides. A symmetric Wald interval respects none of that: once the
coefficient of variation exceeds roughly 0.51, the lower bound of a 95%
interval falls below zero and the estimator reports a value outside the
parameter space.

The package handles this in one of two ways, in this order of
preference:

1.  **Transform**, where a principled transform for the quantity exists.
    [`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md)
    builds its interval on the logit scale;
    [`estimate_angler_n()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md)
    uses Sadinle's (2009) 0.5 transformed logit interval for Chapman and
    Petersen \\\hat{N}\\; the product-total paths accept
    `ci_type = "log"`. A transformed interval is right-skewed and cannot
    cross the boundary in the first place.

2.  **Clamp** at the feasible limit, where no transform is established
    for the estimator. This is `pmax(0, ...)` applied to the lower
    bound, used by the product totals under `ci_type = "symmetric"` and
    by every bus-route path.

Clamping is the weaker of the two and is deliberately not treated as
equivalent. It keeps the symmetric width that produced the excursion and
truncates the result at the boundary, so it stops the package reporting
an impossible number but does not repair the skew that made the bound
negative. A clamped lower bound of exactly zero should be read as a
signal that the interval is wide relative to the estimate, not as a
precise statement that the quantity could be zero.

Upper bounds are never clamped: none of these quantities has a finite
upper limit that the package knows.

Two quantities are bounded below by something other than zero and are
therefore left alone:
[`est_mean_length()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_length.md)
and
[`est_mean_age()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_age.md)
are bounded by the smallest occupied bin, so a clamp at zero would be
the wrong repair.

## Quantile choice

Where an estimator has a finite sample size of its own to appeal to, it
uses [`stats::qt()`](https://rdrr.io/r/stats/TDist.html) on an explicit
degrees-of-freedom rule. The product-total paths use total interviews
minus the number of strata; the section paths use the number of sections
minus one; mark-recapture uses the number of occasions.

Four estimators use
[`stats::qnorm()`](https://rdrr.io/r/stats/Normal.html) instead —
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
[`est_mean_length()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_length.md),
[`est_compliance()`](https://chrischizinski.github.io/tidycreel/reference/est_compliance.md)
and
[`est_mean_age()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_age.md).
This is deliberate, not an oversight. All four form a linear combination
of the rows of a length or age distribution, and their standard error is
propagated from the per-bin standard errors those rows already carry.
There is no local sample size to key a t-quantile to:

- The number of rows is the number of **bins**, which is a binning
  choice made by the caller. Keying degrees of freedom to it would make
  the interval narrow as the bins got finer, with no additional fish
  measured.

- The row totals are **expanded estimates**, not counts of measured
  fish, so their sum is an estimated abundance rather than a sample
  size.

The honest degrees of freedom belong to the design that produced the
upstream standard errors, and the large-sample argument is made there.
These four estimators inherit that uncertainty rather than sampling
afresh, so the normal quantile is the consistent choice at this level.

[`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md)
is asymptotic by construction and has no finite df to appeal to. The
normal quantile inside Sadinle's logit interval is part of the method,
not a quantile choice.

## References

Sadinle, M. (2009). Transformed logit confidence intervals for small
populations in single capture-recapture estimation. *Communications in
Statistics - Simulation and Computation*, 38(9), 1909-1924.

## See also

[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md),
[`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md),
[`estimate_angler_n()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md),
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
[`est_mean_length()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_length.md)
