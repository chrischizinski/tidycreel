#' Confidence interval conventions in tidycreel
#'
#' Estimators in this package do not all build confidence intervals the same
#' way, because the quantities they estimate do not all live on the same scale
#' or carry the same information about their own uncertainty. This topic states
#' the two rules the package follows, so that a new estimator does not have to
#' pick by coin flip.
#'
#' @section Bounded quantities:
#'
#' Effort, catch, harvest, release, biomass, abundance and catch rates are all
#' bounded below by zero, and exploitation rate is bounded on both sides. A
#' symmetric Wald interval respects none of that: once the coefficient of
#' variation exceeds roughly 0.51, the lower bound of a 95% interval falls below
#' zero and the estimator reports a value outside the parameter space.
#'
#' The package handles this in one of two ways, in this order of preference:
#'
#' 1. **Transform**, where a principled transform for the quantity exists.
#'    `estimate_exploitation_rate()` builds its interval on the logit scale;
#'    `estimate_angler_n()` uses Sadinle's (2009) 0.5 transformed logit interval
#'    for Chapman and Petersen \eqn{\hat{N}}; the product-total paths accept
#'    `ci_type = "log"`. A transformed interval is right-skewed and cannot cross
#'    the boundary in the first place.
#' 2. **Clamp** at the feasible limit, where no transform is established for the
#'    estimator. This is `pmax(0, ...)` applied to the lower bound, used by the
#'    product totals under `ci_type = "symmetric"` and by every bus-route path.
#'
#' Clamping is the weaker of the two and is deliberately not treated as
#' equivalent. It keeps the symmetric width that produced the excursion and
#' truncates the result at the boundary, so it stops the package reporting an
#' impossible number but does not repair the skew that made the bound negative.
#' A clamped lower bound of exactly zero should be read as a signal that the
#' interval is wide relative to the estimate, not as a precise statement that
#' the quantity could be zero.
#'
#' Upper bounds are never clamped: none of these quantities has a finite upper
#' limit that the package knows.
#'
#' Two quantities are bounded below by something other than zero and are
#' therefore left alone: `est_mean_length()` and `est_mean_age()` are bounded by
#' the smallest occupied bin, so a clamp at zero would be the wrong repair.
#'
#' @section Quantile choice:
#'
#' The rule (GH #705): an interval is Student's t on the design degrees of
#' freedom of the data that drives its variance -- sampled days, the primary
#' sampling units, minus strata, which is `survey::degf()` (Lumley 2010, sec.
#' 5.2). A quantity built from independently estimated parts takes
#' Satterthwaite's effective df over them (Cochran 1977, eq. 5.16), which lies
#' between the smallest part's df and their sum. Pollock et al. (1994, sec.
#' 3.3) use the normal quantile as a large-sample approximation; on the few
#' dozen days a creel survey samples, Cochran (1977, sec. 5.4) reads the
#' multiplier from Student's t instead.
#'
#' Following the rule now:
#'
#' - effort -- instantaneous, aerial, camera and bus-route -- on the count
#'   design's df.
#' - catch, harvest and release rates (ratio-of-means, mean-of-ratios,
#'   regression, species, sections, bus-route) on the interview design's df,
#'   which is clustered on the survey day. A rate pooled across strata adds the
#'   variance of its effort weights, so it takes Satterthwaite's df over the
#'   interview and effort terms.
#' - bus-route catch, harvest and release totals, which are direct
#'   Horvitz-Thompson totals on the bus-route design.
#'
#' A grouped row is a domain and counts only its own sampled days and strata:
#' a row for weekdays takes the weekdays' df, as
#' `survey::degf(subset(design, ...))` reports, not the whole design's. A
#' group seen on few days gets a wide multiplier, which is the point. This
#' holds for grouped effort, rates and bus-route rows, under Taylor, bootstrap
#' and jackknife alike: the df is the design's, whatever estimates the
#' variance. A rate pooled across strata sums one effort term per stratum, so
#' its Satterthwaite df runs over every stratum's term.
#'
#' Not yet (GH #705): the effort x rate product totals still use total
#' interviews minus strata (per group, the group's interviews minus its strata;
#' a sectioned lake row, the sum of its sections'), angler trips the interview
#' design's df, and mark-recapture and exploitation their own occasion- and
#' stratum-count rules.
#'
#' Six estimators use `stats::qnorm()` instead — `est_biomass()`,
#' `est_mean_length()`, `est_compliance()`, `est_mean_age()`, and since #310
#' `est_length_distribution()` and `est_age_distribution()` themselves. This is
#' deliberate, not an oversight.
#'
#' The first four form a linear combination of the rows of a length or age
#' distribution, and their standard error is propagated from the per-bin
#' standard errors those rows already carry. The two distributions joined them
#' when their totals became two-phase: a bin total is no longer a quantity
#' `svytotal()` returns directly but a delta-method function of the measured
#' bins and the reported total, so its standard error is likewise propagated
#' rather than design-based. (The interval width is unchanged by that switch —
#' `survey`'s `confint()` method for a `svystat` defaults to `df = Inf`, which
#' is the normal quantile.)
#'
#' In every case there is no local sample size to key a t-quantile to:
#'
#' - The number of rows is the number of **bins**, which is a binning choice made
#'   by the caller. Keying degrees of freedom to it would make the interval
#'   narrow as the bins got finer, with no additional fish measured.
#' - The row totals are **expanded estimates**, not counts of measured fish, so
#'   their sum is an estimated abundance rather than a sample size.
#'
#' The honest degrees of freedom belong to the design that produced the upstream
#' standard errors, and the large-sample argument is made there. These four
#' estimators inherit that uncertainty rather than sampling afresh, so the normal
#' quantile is the consistent choice at this level.
#'
#' `estimate_effort_aerial_glmm()` is asymptotic by construction and has no
#' finite df to appeal to. The normal quantile inside Sadinle's logit interval
#' is part of the method, not a quantile choice.
#'
#' @section Recorded degrees of freedom:
#'
#' Every estimate records the degrees of freedom its rows' intervals used in
#' `x$ci_df`, one value per row of `x$estimates`: a finite value for a t
#' interval, `Inf` for a normal one, and `NA` where the interval is not built
#' from the standard error at all (Schnabel's Poisson bounds for small
#' recapture totals) or the row has no interval. The aerial GLMM's bootstrap
#' path records `Inf`: its percentile interval has no df, but its standard
#' error is asymptotic. It is what a sum or difference of independent estimates
#' needs for its own degrees of freedom.
#'
#' @references
#' Cochran, W. G. (1977). *Sampling Techniques* (3rd ed.). Wiley.
#'
#' Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*. Wiley.
#'
#' Pollock, K. H., Jones, C. M., & Brown, T. L. (1994). *Angler Survey Methods
#' and Their Applications in Fisheries Management*. American Fisheries Society
#' Special Publication 25.
#'
#' Sadinle, M. (2009). Transformed logit confidence intervals for small
#' populations in single capture-recapture estimation.
#' *Communications in Statistics - Simulation and Computation*, 38(9),
#' 1909-1924.
#'
#' @seealso [estimate_effort()], [estimate_total_catch()],
#'   [estimate_harvest_rate()], [estimate_exploitation_rate()],
#'   [estimate_angler_n()], [est_biomass()], [est_mean_length()]
#'
#' @name creel_confidence_intervals
NULL
