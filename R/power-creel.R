# power_creel() ---------------------------------------------------------------

#' Unified sample-size and power interface for creel surveys
#'
#' A single tidy entry point for pre-survey sample-size planning that wraps
#' [creel_n_effort()], [creel_n_cpue()], and [creel_power()] and returns a
#' consistent tibble.
#'
#' Three `mode` values are supported:
#' \describe{
#'   \item{`"effort_n"`}{Required sampling *days* per stratum to achieve
#'     `target_rse` on the effort estimate (calls [creel_n_effort()]).}
#'   \item{`"cpue_n"`}{Required *interviews* to achieve `target_rse` on the
#'     CPUE estimate (calls [creel_n_cpue()]).}
#'   \item{`"power"`}{Statistical power to detect a fractional change in CPUE
#'     at a given sample size (calls [creel_power()]).}
#' }
#'
#' @param mode Character scalar. One of `"effort_n"`, `"cpue_n"`, or
#'   `"power"`. Selects the planning formula.
#' @param target_rse Numeric scalar in (0, 1]. Target relative standard error
#'   (= target CV). Required for `mode %in% c("effort_n", "cpue_n")`.
#' @param strata Character vector of stratum names. Required for
#'   `mode = "effort_n"`. Length must match `N_h`, `ybar_h`, and `s2_h`.
#' @param N_h Numeric vector. Total sampling days available per stratum.
#'   Required for `mode = "effort_n"`.
#' @param ybar_h Numeric vector. Pilot mean effort per day per stratum.
#'   Required for `mode = "effort_n"`.
#' @param s2_h Numeric vector. Pilot variance of effort per day per stratum.
#'   Required for `mode = "effort_n"`.
#' @param cv_catch Numeric scalar. Pilot CV of catch per interview.
#'   Required for `mode %in% c("cpue_n", "power")`.
#' @param cv_effort Numeric scalar. Pilot CV of effort per interview.
#'   Required for `mode = "cpue_n"`.
#' @param rho Numeric scalar in \[-1, 1\]. Pilot correlation between catch and
#'   effort. Default `0` (conservative). Used for `mode %in% c("cpue_n",
#'   "power")`.
#' @param n Integerish scalar. Sample size (interviews) for `mode = "power"`.
#' @param cv_historical Numeric scalar. Historical CV of CPUE for
#'   `mode = "power"`. If `NULL`, `cv_catch` is used as a proxy.
#' @param delta_pct Numeric scalar (> 0). Fractional change to detect.
#'   Required for `mode = "power"`.
#' @param alpha Numeric scalar in (0, 0.5]. Type I error rate. Default `0.05`.
#'   Used for `mode = "power"`.
#' @param alternative Character. `"two.sided"` (default) or `"one.sided"`.
#'   Used for `mode = "power"`.
#'
#' @return A tibble (data frame) with columns varying by mode:
#'
#'   **`mode = "effort_n"`** (one row per stratum plus a `"total"` row):
#'   \describe{
#'     \item{`stratum`}{Stratum name.}
#'     \item{`n_required`}{Sampling days required.}
#'     \item{`target_rse`}{The requested target RSE.}
#'   }
#'
#'   **`mode = "cpue_n"`** (one row):
#'   \describe{
#'     \item{`n_required`}{Interviews required.}
#'     \item{`target_rse`}{The requested target RSE.}
#'     \item{`cv_catch`}{Input CV of catch.}
#'     \item{`cv_effort`}{Input CV of effort.}
#'     \item{`rho`}{Input correlation.}
#'   }
#'
#'   **`mode = "power"`** (one row):
#'   \describe{
#'     \item{`power`}{Estimated statistical power.}
#'     \item{`n`}{Input sample size.}
#'     \item{`delta_pct`}{Input fractional change.}
#'     \item{`cv_historical`}{Historical CV used.}
#'     \item{`alpha`}{Input significance level.}
#'     \item{`alternative`}{Input test direction.}
#'   }
#'
#' @seealso [creel_n_effort()], [creel_n_cpue()], [creel_power()]
#'
#' @examples
#' # Effort: sampling days needed for 20 percent RSE
#' power_creel(
#'   mode       = "effort_n",
#'   target_rse = 0.20,
#'   strata     = c("weekday", "weekend"),
#'   N_h        = c(65, 28),
#'   ybar_h     = c(50, 60),
#'   s2_h       = c(400, 500)
#' )
#'
#' # CPUE: interviews needed for 20 percent RSE
#' power_creel(
#'   mode       = "cpue_n",
#'   target_rse = 0.20,
#'   cv_catch   = 0.8,
#'   cv_effort  = 0.5
#' )
#'
#' # Power: detect a 20 percent change with n = 80 interviews
#' power_creel(
#'   mode          = "power",
#'   n             = 80L,
#'   cv_historical = 0.5,
#'   delta_pct     = 0.20
#' )
#'
#' @export
power_creel <- function( # nolint: object_name_linter
    mode          = c("effort_n", "cpue_n", "power"),
    target_rse    = NULL,
    strata        = NULL,
    N_h           = NULL, # nolint: object_name_linter
    ybar_h        = NULL, # nolint: object_name_linter
    s2_h          = NULL, # nolint: object_name_linter
    cv_catch      = NULL,
    cv_effort     = NULL,
    rho           = 0,
    n             = NULL,
    cv_historical = NULL, # nolint: object_name_linter
    delta_pct     = NULL,
    alpha         = 0.05,
    alternative   = c("two.sided", "one.sided")) {
  mode        <- match.arg(mode)
  alternative <- match.arg(alternative)

  switch(mode,
    effort_n = .power_creel_effort_n(
      target_rse = target_rse,
      strata     = strata,
      N_h        = N_h, # nolint: object_name_linter
      ybar_h     = ybar_h, # nolint: object_name_linter
      s2_h       = s2_h # nolint: object_name_linter
    ),
    cpue_n = .power_creel_cpue_n(
      target_rse = target_rse,
      cv_catch   = cv_catch,
      cv_effort  = cv_effort,
      rho        = rho
    ),
    power = .power_creel_power(
      n             = n,
      cv_historical = cv_historical, # nolint: object_name_linter
      cv_catch      = cv_catch,
      delta_pct     = delta_pct,
      alpha         = alpha,
      alternative   = alternative
    )
  )
}

# ---- Internal mode handlers -------------------------------------------------

.power_creel_effort_n <- function(target_rse, strata, N_h, ybar_h, s2_h) { # nolint
  if (is.null(target_rse)) {
    cli::cli_abort(
      "{.arg target_rse} is required for {.code mode = \"effort_n\"}."
    )
  }
  if (is.null(strata) || is.null(N_h) || is.null(ybar_h) || is.null(s2_h)) {
    cli::cli_abort(
      "{.arg strata}, {.arg N_h}, {.arg ybar_h}, and {.arg s2_h} are ",
      "all required for {.code mode = \"effort_n\"}."
    )
  }
  if (length(strata) != length(N_h)) {
    cli::cli_abort(
      "{.arg strata} and {.arg N_h} must have the same length."
    )
  }

  names(N_h) <- strata # nolint: object_name_linter

  raw <- creel_n_effort(
    cv_target = target_rse,
    N_h       = N_h, # nolint: object_name_linter
    ybar_h    = ybar_h, # nolint: object_name_linter
    s2_h      = s2_h # nolint: object_name_linter
  )

  all_strata <- c(strata, "total")
  data.frame(
    stratum    = all_strata,
    n_required = as.integer(raw[all_strata]),
    target_rse = target_rse,
    stringsAsFactors = FALSE
  )
}

.power_creel_cpue_n <- function(target_rse, cv_catch, cv_effort, rho) {
  if (is.null(target_rse)) {
    cli::cli_abort(
      "{.arg target_rse} is required for {.code mode = \"cpue_n\"}."
    )
  }
  if (is.null(cv_catch) || is.null(cv_effort)) {
    cli::cli_abort(
      "{.arg cv_catch} and {.arg cv_effort} are required for ",
      "{.code mode = \"cpue_n\"}."
    )
  }

  n_req <- creel_n_cpue(
    cv_catch   = cv_catch,
    cv_effort  = cv_effort,
    rho        = rho,
    cv_target  = target_rse
  )

  data.frame(
    n_required = n_req,
    target_rse = target_rse,
    cv_catch   = cv_catch,
    cv_effort  = cv_effort,
    rho        = rho,
    stringsAsFactors = FALSE
  )
}

.power_creel_power <- function(n, cv_historical, cv_catch, delta_pct, # nolint
                               alpha, alternative) {
  if (is.null(n)) {
    cli::cli_abort("{.arg n} is required for {.code mode = \"power\"}.")
  }
  if (is.null(delta_pct)) {
    cli::cli_abort(
      "{.arg delta_pct} is required for {.code mode = \"power\"}."
    )
  }
  cv_hist <- cv_historical %||% cv_catch # nolint: object_name_linter
  if (is.null(cv_hist)) {
    cli::cli_abort(
      "Provide {.arg cv_historical} (or {.arg cv_catch} as a proxy) ",
      "for {.code mode = \"power\"}."
    )
  }

  pwr <- creel_power(
    n             = n,
    cv_historical = cv_hist, # nolint: object_name_linter
    delta_pct     = delta_pct,
    alpha         = alpha,
    alternative   = alternative
  )

  data.frame(
    power         = pwr,
    n             = as.integer(n),
    delta_pct     = delta_pct,
    cv_historical = cv_hist, # nolint: object_name_linter
    alpha         = alpha,
    alternative   = alternative,
    stringsAsFactors = FALSE
  )
}
