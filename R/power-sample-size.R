#' Calculate sampling days required to achieve a target CV on effort
#'
#' Uses the stratified sample size formula from McCormick & Quist (2017) to
#' determine how many sampling days are needed to achieve a target coefficient of
#' variation on the effort estimate, given pilot variance estimates per day-type
#' stratum.
#'
#' @param cv_target Numeric scalar. Target coefficient of variation for the
#'   effort estimate (e.g., 0.20 for 20 percent). Must be in (0, 1].
#' @param N_h Named numeric vector. Total available days per stratum (e.g.,
#'   `c(weekday = 65, weekend = 28)`). Values must be >= 1.
#' @param ybar_h Numeric vector of same length as `N_h`. Pilot mean effort per
#'   day per stratum (e.g., angler-hours per day). Values must be >= 0.
#' @param s2_h Numeric vector of same length as `N_h`. Pilot variance of
#'   effort per day per stratum. Values must be >= 0.
#'
#' @details
#' Implements Cochran (1977) equation 5.25 under proportional allocation, as
#' applied to creel surveys by McCormick & Quist (2017). The finite-population
#' correction (FPC) factor is intentionally omitted (standard practice for
#' pre-season planning where the goal is to determine how many days to sample,
#' not to assess precision of a completed survey).
#'
#' The per-stratum sample sizes `n_h` are computed from the total `n_total`
#' under proportional allocation: `n_h = ceiling(n_total * N_h / sum(N_h))`.
#' Because each stratum is ceiling-ed independently, `sum(n_h)` may exceed
#' `n_total`.
#'
#' @return A named integer vector. Elements named after strata in `N_h` give the
#'   sampling days required per stratum; element `"total"` gives the overall
#'   sample size before proportional allocation.
#'
#' @references
#' McCormick, J.L. and Quist, M.C. 2017. Sample size estimation for on-site
#' creel surveys. North American Journal of Fisheries Management 37:970-983.
#' \doi{10.1080/02755947.2017.1342723}
#'
#' Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.
#'
#' @family "Planning & Sample Size"
#' @export
#'
#' @examples
#' # Two-stratum weekday/weekend example
#' creel_n_effort(
#'   cv_target = 0.20,
#'   N_h = c(weekday = 65, weekend = 28),
#'   ybar_h = c(50, 60),
#'   s2_h = c(400, 500)
#' )
creel_n_effort <- function(cv_target, N_h, ybar_h, s2_h) { # nolint: object_name_linter
  checkmate::assert_number(cv_target, lower = 1e-6, upper = 1.0)
  checkmate::assert_numeric(N_h, lower = 1, min.len = 1, names = "named") # nolint: object_name_linter
  checkmate::assert_numeric(ybar_h, lower = 0, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_numeric(s2_h, lower = 0, len = length(N_h)) # nolint: object_name_linter

  E_total <- sum(N_h * ybar_h) # nolint: object_name_linter
  V_0 <- (cv_target * E_total)^2 # nolint: object_name_linter
  s_h <- sqrt(s2_h) # nolint: object_name_linter

  # Cochran (1977) eq. 5.25 -- FPC omitted (intentional; see @details)
  numerator <- sum(N_h * s_h)^2 # nolint: object_name_linter
  denominator <- V_0 + sum(N_h * s2_h) # nolint: object_name_linter
  n_total <- ceiling(numerator / denominator)

  # Proportional allocation per stratum
  w_h <- N_h / sum(N_h) # nolint: object_name_linter
  n_h <- ceiling(n_total * w_h) # nolint: object_name_linter
  names(n_h) <- names(N_h) # nolint: object_name_linter

  storage.mode(n_h) <- "integer" # nolint: object_name_linter
  storage.mode(n_total) <- "integer"

  c(n_h, total = n_total) # nolint: object_name_linter
}


#' Calculate interviews required to achieve a target CV on CPUE
#'
#' Determines the number of interviews needed to achieve a target coefficient of
#' variation on a CPUE (catch-per-unit-effort) ratio estimate, using the
#' ratio-estimator variance approximation from Cochran (1977).
#'
#' @param cv_catch Numeric scalar. Pilot coefficient of variation of catch per
#'   interview (the numerator of the CPUE ratio). Must be > 0.
#' @param cv_effort Numeric scalar. Pilot coefficient of variation of effort per
#'   interview (the denominator of the CPUE ratio). Must be > 0.
#' @param rho Numeric scalar. Pilot correlation between catch and effort per
#'   interview. Must be in \[-1, 1\]. Default is 0 (conservative; over-estimates
#'   required n when catch and effort are positively correlated).
#' @param cv_target Numeric scalar. Target coefficient of variation for the CPUE
#'   estimate. Must be in (0, 1].
#'
#' @details
#' Implements the ratio-estimator variance approximation from Cochran (1977,
#' Chapter 6) parameterised in terms of coefficients of variation rather than
#' raw variances, which is more natural for pre-season planning:
#'
#' \deqn{n = \left\lceil \frac{CV_{catch}^2 + CV_{effort}^2
#'   - 2 \rho \cdot CV_{catch} \cdot CV_{effort}}{CV_{target}^2} \right\rceil}
#'
#' Setting `rho = 0` (the default) is conservative: it over-estimates the
#' required sample size when catch and effort are positively correlated. Users
#' with pilot data should supply the observed correlation to obtain a less
#' conservative estimate.
#'
#' The result is floored at 1L to ensure at least one interview is recommended.
#'
#' @return An integer scalar (>= 1): number of interviews required.
#'
#' @references
#' Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York. Chapter 6
#' (ratio estimator variance approximation).
#'
#' @family "Planning & Sample Size"
#' @export
#'
#' @examples
#' # rho = 0 (conservative, no pilot correlation data)
#' creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = 0.20)
#'
#' # With known positive correlation (smaller n)
#' creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0.5, cv_target = 0.20)
creel_n_cpue <- function(cv_catch, cv_effort, rho = 0, cv_target) {
  checkmate::assert_number(cv_catch, lower = 1e-6)
  checkmate::assert_number(cv_effort, lower = 1e-6)
  checkmate::assert_number(rho, lower = -1.0, upper = 1.0)
  checkmate::assert_number(cv_target, lower = 1e-6, upper = 1.0)

  # Cochran (1977) ratio estimator variance approximation, solved for n
  numerator <- cv_catch^2 + cv_effort^2 - 2 * rho * cv_catch * cv_effort
  n <- ceiling(numerator / cv_target^2)
  n <- max(n, 1L)

  storage.mode(n) <- "integer"
  n
}


#' Calculate camera-days required to achieve a target CV
#'
#' Uses the stratified sample size formula from Cochran (1977) to determine how
#' many camera-days are needed to achieve a target coefficient of variation on
#' the camera-effort estimate, given pilot mean and variance estimates per
#' day-type stratum.
#'
#' @param cv_target Numeric scalar. Target coefficient of variation for the
#'   camera-effort estimate (e.g., 0.20 for 20 percent). Must be in (0, 1].
#' @param N_h Named numeric vector. Total available days per stratum (e.g.,
#'   `c(weekday = 65, weekend = 28)`). Values must be >= 1.
#' @param ybar_h Numeric vector of same length as `N_h`. Pilot mean camera
#'   count per day per stratum. Values must be >= 0.
#' @param s2_h Numeric vector of same length as `N_h`. Pilot variance of
#'   camera counts per day per stratum. Values must be >= 0.
#'
#' @details
#' Implements Cochran (1977) equation 5.25 under proportional allocation. The
#' finite-population correction (FPC) factor is intentionally omitted (standard
#' practice for pre-season planning where the goal is to determine how many days
#' to deploy cameras, not to assess precision of a completed survey).
#'
#' The per-stratum sample sizes `n_h` are computed from the total `n_total`
#' under proportional allocation: `n_h = ceiling(n_total * N_h / sum(N_h))`.
#' Because each stratum is ceiling-ed independently, `sum(n_h)` may exceed
#' `n_total`.
#'
#' **Minimum camera-day check:** After computing `n_h`, the function applies
#' empirical minimums from Feltz-Middaugh (2025). Stratum names are matched
#' case-insensitively and partially:
#' - Names containing `"weekday"` require a minimum of 12 camera-days.
#' - Names containing `"weekend"` require a minimum of 7 camera-days.
#' - Names matching neither pattern trigger a generic advisory (no numeric
#'   floor — consult Feltz-Middaugh 2025 for the appropriate minimum).
#'
#' When any stratum is below threshold (or is unclassified), a single combined
#' `cli_warn()` is emitted listing all affected strata with their computed `n`
#' and minimum side-by-side. No warning fires if all classified strata meet or
#' exceed their minimums and there are no unclassified strata.
#'
#' @return A named integer vector. Elements named after strata in `N_h` give the
#'   camera-days required per stratum; element `"total"` gives the overall
#'   sample size before proportional allocation.
#'
#' @references
#' Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.
#'
#' Feltz, C.J. and Middaugh, C.R. 2025. Minimum camera-day requirements for
#' reliable creel-camera effort estimation. North American Journal of Fisheries
#' Management. (in press)
#'
#' @seealso [creel_n_effort()] for the equivalent function for angler-contact
#'   sampling days.
#'
#' @family "Planning & Sample Size"
#' @export
#'
#' @examples
#' # Two-stratum weekday/weekend example
#' creel_n_camera(
#'   cv_target = 0.20,
#'   N_h = c(weekday = 65, weekend = 28),
#'   ybar_h = c(15, 20),
#'   s2_h = c(625, 900)
#' )
creel_n_camera <- function(cv_target, N_h, ybar_h, s2_h) { # nolint: object_name_linter
  checkmate::assert_number(cv_target, lower = 1e-6, upper = 1.0)
  checkmate::assert_numeric(N_h, lower = 1, min.len = 1, names = "named") # nolint: object_name_linter
  checkmate::assert_numeric(ybar_h, lower = 0, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_numeric(s2_h, lower = 0, len = length(N_h)) # nolint: object_name_linter

  E_total <- sum(N_h * ybar_h) # nolint: object_name_linter
  V_0 <- (cv_target * E_total)^2 # nolint: object_name_linter
  s_h <- sqrt(s2_h) # nolint: object_name_linter

  # Cochran (1977) eq. 5.25 -- FPC omitted (intentional; see @details)
  numerator <- sum(N_h * s_h)^2 # nolint: object_name_linter
  denominator <- V_0 + sum(N_h * s2_h) # nolint: object_name_linter
  n_total <- ceiling(numerator / denominator)

  # Proportional allocation per stratum
  w_h <- N_h / sum(N_h) # nolint: object_name_linter
  n_h <- ceiling(n_total * w_h) # nolint: object_name_linter
  names(n_h) <- names(N_h) # nolint: object_name_linter

  # Feltz-Middaugh (2025) minimum check -- D-06/D-07
  min_h <- vapply(names(N_h), function(nm) { # nolint: object_name_linter
    nm_lower <- tolower(nm)
    if (grepl("weekday", nm_lower)) 12L
    else if (grepl("weekend", nm_lower)) 7L
    else NA_integer_
  }, integer(1))

  below <- which(!is.na(min_h) & n_h < min_h) # nolint: object_name_linter
  generic_below <- which(is.na(min_h)) # unclassified strata always warned

  if (length(below) > 0 || length(generic_below) > 0) {
    bullet_items <- character(length(below) + length(generic_below))
    idx <- 1L
    for (i in below) {
      bullet_items[idx] <- sprintf("%s: n = %d (minimum %d per Feltz-Middaugh 2025)",
                                   names(n_h)[i], n_h[i], min_h[i])
      idx <- idx + 1L
    }
    for (i in generic_below) {
      bullet_items[idx] <- sprintf(
        "%s: n = %d (unclassified stratum -- consult Feltz-Middaugh 2025 for recommended minimum)",
        names(n_h)[i], n_h[i])
      idx <- idx + 1L
    }
    names(bullet_items) <- rep("*", length(bullet_items))
    cli::cli_warn(c(
      "{length(below) + length(generic_below)} stratum{?/a} below recommended minimum:",
      bullet_items,
      "i" = "See Feltz-Middaugh (2025) for empirical camera-day minimums."
    ))
  }

  storage.mode(n_h) <- "integer" # nolint: object_name_linter
  storage.mode(n_total) <- "integer"

  c(n_h, total = n_total) # nolint: object_name_linter
}


#' Estimate statistical power to detect a change in CPUE between seasons
#'
#' Calculates the probability of detecting a fractional change in CPUE given a
#' target sample size per season, a historical CV, and a significance level.
#' Uses a two-sample normal approximation with equal group sizes.
#'
#' @param n Integerish scalar (>= 1). Number of interviews per season.
#' @param cv_historical Numeric scalar (> 0). Coefficient of variation of CPUE
#'   from historical or pilot data.
#' @param delta_pct Numeric scalar (> 0). Fractional change to detect, expressed
#'   as a proportion — e.g., 0.20 for a 20 percent change. Note: this is a
#'   fraction, not a percentage point.
#' @param alpha Numeric scalar in (0, 0.5]. Type I error rate. Default is 0.05.
#' @param alternative Character. Either `"two.sided"` (default) or `"one.sided"`.
#'
#' @details
#' Implements the two-sample normal approximation for power under equal group
#' sizes, parameterised in terms of the CV:
#'
#' \deqn{ncp = |\delta| \cdot \sqrt{n/2} \, / \, CV_{historical}}
#'
#' For `alternative = "two.sided"`:
#' \deqn{power = \Phi(ncp - z_{\alpha/2}) + \Phi(-ncp - z_{\alpha/2})}
#'
#' For `alternative = "one.sided"`:
#' \deqn{power = \Phi(ncp - z_{\alpha})}
#'
#' where `delta` is the fractional effect size (`delta_pct`), `n` is the number
#' of interviews per season, and `CV_historical` is the pilot CV of CPUE.
#'
#' A warning is issued when `delta_pct > 5` because values greater than 5 are
#' almost certainly input in percentage-point form rather than fractional form
#' (e.g., 20 instead of 0.20).
#'
#' @return A numeric scalar in (0, 1): estimated statistical power.
#'
#' @references
#' Cohen, J. 1988. Statistical Power Analysis for the Behavioral Sciences, 2nd
#' ed. Lawrence Erlbaum Associates, Hillsdale, NJ.
#'
#' @family "Planning & Sample Size"
#' @export
#'
#' @examples
#' # Two-sided power at n = 100, CV = 0.5, 20 percent change
#' creel_power(n = 100, cv_historical = 0.5, delta_pct = 0.20)
#'
#' # One-sided test (higher power for same inputs)
#' creel_power(n = 100, cv_historical = 0.5, delta_pct = 0.20, alternative = "one.sided")
creel_power <- function(n, cv_historical, delta_pct, alpha = 0.05, # nolint: object_name_linter
                        alternative = c("two.sided", "one.sided")) {
  checkmate::assert_integerish(n, lower = 1, len = 1)
  checkmate::assert_number(cv_historical, lower = 1e-6) # nolint: object_name_linter
  checkmate::assert_number(delta_pct, lower = 1e-6)
  checkmate::assert_number(alpha, lower = 1e-6, upper = 0.5)
  alternative <- match.arg(alternative)

  if (delta_pct > 5) {
    cli::cli_warn("delta_pct > 5 is unusually large; did you mean {delta_pct / 100}?")
  }

  ncp <- abs(delta_pct) * sqrt(n / 2) / cv_historical # nolint: object_name_linter

  if (alternative == "two.sided") {
    z_crit <- stats::qnorm(1 - alpha / 2)
    power <- stats::pnorm(ncp - z_crit) + stats::pnorm(-ncp - z_crit)
  } else {
    z_crit <- stats::qnorm(1 - alpha)
    power <- stats::pnorm(ncp - z_crit)
  }

  power
}


#' Compute the expected CV achievable with a known sample size
#'
#' Calculates the coefficient of variation attainable given a fixed sample size,
#' acting as the algebraic inverse of [creel_n_effort()] (when `type = "effort"`)
#' or [creel_n_cpue()] (when `type = "cpue"`).
#'
#' @param type Character. Either `"effort"` or `"cpue"`. Selects the formula
#'   branch and required additional arguments.
#' @param n Integerish scalar (>= 1). Available sample size (sampling days for
#'   `"effort"`, interviews for `"cpue"`).
#' @param ... Additional arguments passed to the relevant branch:
#'
#'   **For `type = "effort"`:**
#'   - `N_h` — Named numeric vector; total available days per stratum (>= 1).
#'   - `ybar_h` — Numeric vector; pilot mean effort per day per stratum (>= 0).
#'   - `s2_h` — Numeric vector; pilot variance of effort per day per stratum (>= 0).
#'
#'   **For `type = "cpue"`:**
#'   - `cv_catch` — Numeric scalar; pilot CV of catch per interview (> 0).
#'   - `cv_effort` — Numeric scalar; pilot CV of effort per interview (> 0).
#'   - `rho` — Numeric scalar; pilot correlation between catch and effort, in
#'     \[-1, 1\]. Default is 0.
#'
#' @details
#' **Effort branch** (`type = "effort"`):
#' \deqn{CV = \frac{\sqrt{\sum_h N_h s_h^2 / n}}{\sum_h N_h \bar{y}_h}}
#'
#' This is the inverse of the Cochran (1977) stratified sample-size formula
#' implemented in [creel_n_effort()].
#'
#' **CPUE branch** (`type = "cpue"`):
#' \deqn{CV = \sqrt{(CV_{catch}^2 + CV_{effort}^2
#'   - 2\rho \cdot CV_{catch} \cdot CV_{effort}) / n}}
#'
#' This is the inverse of the ratio-estimator formula implemented in
#' [creel_n_cpue()].
#'
#' Because [creel_n_effort()] and [creel_n_cpue()] apply `ceiling()`, the
#' round-trip property is `cv_from_n(type, n = creel_n_*(cv, ...), ...) <= cv`
#' (the recovered CV is at or below the target).
#'
#' @return A numeric scalar (> 0): the expected CV achievable at sample size `n`.
#'
#' @seealso [creel_n_effort()], [creel_n_cpue()]
#'
#' @references
#' Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.
#'
#' @family "Planning & Sample Size"
#' @export
#'
#' @examples
#' # Effort round-trip
#' n_days <- creel_n_effort(0.20,
#'   N_h = c(weekday = 65, weekend = 28),
#'   ybar_h = c(50, 60), s2_h = c(400, 500)
#' )
#' cv_from_n("effort",
#'   n = n_days[["total"]],
#'   N_h = c(weekday = 65, weekend = 28),
#'   ybar_h = c(50, 60), s2_h = c(400, 500)
#' )
#'
#' # CPUE round-trip
#' n_int <- creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = 0.20)
#' cv_from_n("cpue", n = n_int, cv_catch = 0.8, cv_effort = 0.5, rho = 0)
cv_from_n <- function(type = c("effort", "cpue"), n, ...) {
  type <- match.arg(type)
  checkmate::assert_integerish(n, lower = 1, len = 1)

  dots <- list(...)

  if (type == "effort") {
    N_h <- dots[["N_h"]] # nolint: object_name_linter
    ybar_h <- dots[["ybar_h"]] # nolint: object_name_linter
    s2_h <- dots[["s2_h"]] # nolint: object_name_linter

    checkmate::assert_numeric(N_h, lower = 1, min.len = 1, names = "named") # nolint: object_name_linter
    checkmate::assert_numeric(ybar_h, lower = 0, len = length(N_h)) # nolint: object_name_linter
    checkmate::assert_numeric(s2_h, lower = 0, len = length(N_h)) # nolint: object_name_linter

    E_total <- sum(N_h * ybar_h) # nolint: object_name_linter
    cv <- sqrt(sum(N_h * s2_h) / n) / E_total # nolint: object_name_linter
  } else {
    cv_catch <- dots[["cv_catch"]]
    cv_effort <- dots[["cv_effort"]]
    rho <- if (is.null(dots[["rho"]])) 0 else dots[["rho"]]

    checkmate::assert_number(cv_catch, lower = 1e-6)
    checkmate::assert_number(cv_effort, lower = 1e-6)
    checkmate::assert_number(rho, lower = -1.0, upper = 1.0)

    cv <- sqrt((cv_catch^2 + cv_effort^2 - 2 * rho * cv_catch * cv_effort) / n)
  }

  cv
}
