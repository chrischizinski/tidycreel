# design-validator.R — Pre-season design validation and post-season completeness checking
# Phase 50: VALID-01 (validate_design) and QUAL-01 (check_completeness)

# Internal threshold constants (documented, not yet enforced until Plan 02)
WARN_CV_BUFFER <- 1.2 # nolint: object_name_linter — warn if cv_actual <= cv_target * WARN_CV_BUFFER but n < n_required

# ---- internal constructors --------------------------------------------------

new_creel_design_report <- function(results, passed, survey_type) {
  structure(
    list(results = results, passed = passed, survey_type = survey_type),
    class = "creel_design_report"
  )
}

# ---- validate_design --------------------------------------------------------

#' Validate a proposed creel survey design against sample size targets
#'
#' Pre-season design check: runs creel_n_effort() and creel_n_cpue() per
#' stratum and returns a pass/warn/fail status report.
#'
#' @param N_h Named numeric vector. Total available sampling days per stratum.
#' @param ybar_h Numeric vector (same length as N_h). Pilot mean effort per day per stratum.
#' @param s2_h Numeric vector (same length as N_h). Pilot variance of effort per stratum.
#' @param n_proposed Named integer vector (same length as N_h). Proposed sampling days per stratum.
#' @param cv_target Numeric scalar. Target CV for the effort estimate.
#' @param type Character. One of "effort" or "cpue". Default "effort".
#' @param cv_catch Numeric scalar. Required when type = "cpue".
#' @param cv_effort Numeric scalar. Required when type = "cpue".
#' @param rho Numeric scalar. Correlation between catch and effort. Default 0.
#'
#' @return A creel_design_report object (S3 list) with:
#'   \describe{
#'     \item{$results}{tibble with columns stratum, status, n_proposed,
#'       n_required, cv_actual, cv_target, message}
#'     \item{$passed}{logical — TRUE if all strata status == "pass"}
#'     \item{$survey_type}{character}
#'   }
#'
#' @export
validate_design <- function(
  # nolint: object_name_linter
  N_h, ybar_h, s2_h, n_proposed, cv_target, # nolint: object_name_linter
  type = c("effort", "cpue"),
  cv_catch = NULL, cv_effort = NULL, rho = 0
) {
  type <- match.arg(type)

  # Input validation
  checkmate::assert_numeric(N_h, lower = 1, min.len = 1, names = "named") # nolint: object_name_linter
  checkmate::assert_numeric(ybar_h, lower = 0, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_numeric(s2_h, lower = 0, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_integerish(n_proposed, lower = 1, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_number(cv_target, lower = 1e-6, upper = 1.0)

  # CPUE-specific argument validation
  if (type == "cpue") {
    checkmate::assert_number(cv_catch, lower = 1e-6)
    checkmate::assert_number(cv_effort, lower = 1e-6)
    checkmate::assert_number(rho, lower = -1.0, upper = 1.0)
  }

  strata_names <- names(N_h)

  # Per-stratum calculations — delegate entirely to Phase 49 functions
  if (type == "effort") {
    n_req_all <- creel_n_effort( # nolint: object_usage_linter
      cv_target = cv_target, # nolint: object_name_linter
      N_h = N_h, ybar_h = ybar_h, s2_h = s2_h
    )
    n_required_vec <- n_req_all[strata_names]
    cv_actual_vec <- vapply(seq_along(N_h), function(i) {
      cv_from_n("effort", # nolint: object_usage_linter
        n = n_proposed[[i]],
        N_h = N_h[i], ybar_h = ybar_h[i], s2_h = s2_h[i]
      )
    }, numeric(1))
  } else {
    # CPUE: single overall n (no per-stratum breakdown in creel_n_cpue)
    n_required_scalar <- creel_n_cpue( # nolint: object_usage_linter
      cv_catch = cv_catch, cv_effort = cv_effort,
      rho = rho, cv_target = cv_target
    )
    n_required_vec <- rep(n_required_scalar, length(N_h))
    cv_actual_vec <- vapply(n_proposed, function(n) {
      cv_from_n("cpue", n = n, cv_catch = cv_catch, cv_effort = cv_effort, rho = rho) # nolint: object_usage_linter
    }, numeric(1))
  }

  # Status logic: pass / warn / fail
  status_vec <- dplyr::case_when(
    n_proposed >= n_required_vec ~ "pass",
    cv_actual_vec <= cv_target * WARN_CV_BUFFER ~ "warn",
    TRUE ~ "fail"
  )

  # Build results tibble
  results <- tibble::tibble(
    stratum = strata_names,
    status = status_vec,
    n_proposed = as.integer(n_proposed),
    n_required = as.integer(n_required_vec),
    cv_actual = round(cv_actual_vec, 4),
    cv_target = cv_target,
    message = dplyr::case_when(
      status_vec == "pass" ~ paste0("Proposed n meets or exceeds required n (", n_required_vec, ")"),
      status_vec == "warn" ~ paste0(
        "Proposed n below required (", n_required_vec, ") but CV within ", WARN_CV_BUFFER, "x target"
      ),
      TRUE ~ paste0("Proposed n well below required (", n_required_vec, ")")
    )
  )

  new_creel_design_report(
    results      = results,
    passed       = all(status_vec == "pass"),
    survey_type  = type
  )
}

# ---- S3 methods for creel_design_report -------------------------------------

#' Format creel_design_report for printing
#'
#' @param x A creel_design_report object
#' @param ... Additional arguments (currently ignored)
#' @return Character vector with formatted output
#' @export
format.creel_design_report <- function(x, ...) {
  cli::cli_format_method({
    cli::cli_h1("Design Validation Report")
    cli::cli_text("Type: {x$survey_type}")
    if (x$passed) {
      cli::cli_alert_success("All strata PASSED")
    } else {
      cli::cli_alert_danger("One or more strata FAILED or WARNED")
    }
    cli::cli_text("")
    for (i in seq_len(nrow(x$results))) {
      r <- x$results[i, ]
      cv_a <- round(r$cv_actual, 3) # nolint: object_usage_linter
      cv_t <- r$cv_target # nolint: object_usage_linter
      n_p <- r$n_proposed # nolint: object_usage_linter
      n_r <- r$n_required # nolint: object_usage_linter
      s <- r$stratum # nolint: object_usage_linter
      if (r$status == "pass") {
        cli::cli_alert_success("{s}: n={n_p} >= {n_r} required (CV {cv_a} vs target {cv_t})")
      } else if (r$status == "warn") {
        cli::cli_alert_warning("{s}: n={n_p} < {n_r} required but CV {cv_a} near target {cv_t}")
      } else {
        cli::cli_alert_danger("{s}: n={n_p} << {n_r} required (CV {cv_a} vs target {cv_t})")
      }
    }
  })
}

#' Print creel_design_report
#'
#' @param x A creel_design_report object
#' @param ... Additional arguments passed to format
#' @return The input object, invisibly
#' @export
print.creel_design_report <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

# ---- check_completeness -----------------------------------------------------

#' Check post-season data completeness for a creel design
#'
#' Dispatches by survey_type to avoid false-positive warnings on aerial and
#' camera designs that do not collect interview data.
#'
#' @param design A creel_design object with counts (and optionally interviews) attached.
#' @param n_min Integer scalar >= 1. Interview threshold below which a stratum is flagged
#'   as low-n. Default 10L.
#'
#' @return A creel_completeness_report object (S3 list) with:
#'   \describe{
#'     \item{$missing_days}{tibble of calendar rows with no count data}
#'     \item{$low_n_strata}{tibble of strata below n_min, or NULL for aerial/camera}
#'     \item{$refusals}{creel_summary_refusals object or NULL}
#'     \item{$n_min}{integer threshold used}
#'     \item{$survey_type}{character}
#'     \item{$passed}{logical — TRUE if no missing days and no low-n strata}
#'   }
#'
#' @export
check_completeness <- function(design, n_min = 10L) {
  NULL
}
