#' CPUE Estimator (survey-first)
#'
#' Design-based estimation of catch per unit effort (CPUE) using the
#' `survey` package. Supports ratio-of-means (recommended for incomplete trips)
#' and mean-of-ratios (for complete trips). Returns a tidy tibble with a
#' consistent schema across estimators.
#'
#' @param design A `svydesign`/`svrepdesign` built on interview data, or a
#'   `creel_design` containing `interviews`. If a `creel_design` is supplied,
#'   a minimal equal-weight design is constructed (warns).
#' @param by Character vector of grouping variables present in the interview
#'   data (e.g., `c("target_species","location")`). Missing columns are
#'   ignored with a warning.
#' @param response One of `"catch_total"`, `"catch_kept"`, or `"weight_total"`.
#'   Determines the CPUE numerator.
#' @param effort_col Interview effort column for the denominator (default
#'   `"hours_fished"`).
#' @param mode Estimation mode: `"ratio_of_means"` (default; preferred for
#'   incomplete trips) or `"mean_of_ratios"` (for complete trips).
#' @param conf_level Confidence level for Wald CIs (default 0.95).
#'
#' @return Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `n`, `method`, and a `diagnostics` list-column.
#'
#' @details
#' - Ratio-of-means: `svyratio(~response, ~effort_col)` optionally via
#'   `svyby(…, by=~group, FUN=svyratio)`. This is robust when trips are
#'   incomplete.
#' - Mean-of-ratios: computes trip-level `response/effort_col` then uses
#'   `svymean`/`svyby`. Prefer for complete trips with minimal zero-inflation.
#'
#' @seealso [survey::svyratio()], [survey::svymean()], [survey::svyby()].
#' @export
est_cpue <- function(design,
                     by = NULL,
                     response = c("catch_total", "catch_kept", "weight_total"),
                     effort_col = "hours_fished",
                     mode = c("ratio_of_means", "mean_of_ratios"),
                     conf_level = 0.95) {
  response <- match.arg(response)
  mode <- match.arg(mode)

  # Derive a survey design over interviews
  svy <- tc_interview_svy(design)
  vars <- svy$variables

  # Validate required columns
  req <- c(response, effort_col)
  tc_abort_missing_cols(vars, req, context = "est_cpue")

  # Grouping
  by <- tc_group_warn(by %||% character(), names(vars))

  # Build estimation by grouping
  if (mode == "ratio_of_means") {
    # Grouped svyratio
    if (length(by) > 0) {
      by_formula <- stats::as.formula(paste("~", paste(by, collapse = "+")))
      est <- survey::svyby(
        as.formula(paste0("~", response)),
        by = by_formula,
        design = svy,
        FUN = survey::svyratio,
        denominator = as.formula(paste0("~", effort_col)),
        na.rm = TRUE,
        keep.names = FALSE
      )
      out <- tibble::as_tibble(est)
      # Robust: take estimates and SE directly from model methods
      out$estimate <- as.numeric(stats::coef(est))
      se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)
      if (!inherits(se_try, "try-error") && length(se_try) == nrow(out)) {
        out$se <- se_try
      } else {
        V <- attr(est, "var")
        out$se <- if (!is.null(V) && length(V) > 0) sqrt(diag(V)) else rep(NA_real_, nrow(out))
      }
      z <- stats::qnorm(1 - (1 - conf_level)/2)
      out$ci_low <- out$estimate - z * out$se
      out$ci_high <- out$estimate + z * out$se
      # n by group (unweighted count)
      n_by <- vars |>
        dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
        dplyr::summarise(n = dplyr::n(), .groups = "drop")
      out <- dplyr::left_join(out, n_by, by = by)
      out$method <- paste0("cpue_ratio_of_means:", response)
      out$diagnostics <- replicate(nrow(out), list(NULL))
      return(dplyr::select(out, dplyr::all_of(by), estimate, se, ci_low, ci_high, n, method, diagnostics))
    } else {
      r <- survey::svyratio(
        as.formula(paste0("~", response)),
        as.formula(paste0("~", effort_col)),
        svy,
        na.rm = TRUE
      )
      estimate <- as.numeric(stats::coef(r))
      se <- sqrt(as.numeric(stats::vcov(r)))
      ci <- tc_confint(estimate, se, level = conf_level)
      n <- nrow(vars)
      return(tibble::tibble(
        estimate = estimate, se = se, ci_low = ci[1], ci_high = ci[2], n = n,
        method = paste0("cpue_ratio_of_means:", response), diagnostics = list(NULL)
      ))
    }
  } else {
    # mean_of_ratios: define per-trip CPUE
    svy2 <- survey::update(svy, .cpue = vars[[response]] / vars[[effort_col]])
    if (length(by) > 0) {
      by_formula <- stats::as.formula(paste("~", paste(by, collapse = "+")))
      est <- survey::svyby(~.cpue, by = by_formula, design = svy2, FUN = survey::svymean, na.rm = TRUE, keep.names = FALSE)
      out <- tibble::as_tibble(est)
      names(out)[names(out) == ".cpue"] <- "estimate"
      se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)
      if (!inherits(se_try, "try-error") && length(se_try) == nrow(out)) {
        out$se <- se_try
      } else {
        V <- attr(est, "var")
        out$se <- if (!is.null(V) && length(V) > 0) sqrt(diag(V)) else rep(NA_real_, nrow(out))
      }
      z <- stats::qnorm(1 - (1 - conf_level)/2)
      out$ci_low <- out$estimate - z * out$se
      out$ci_high <- out$estimate + z * out$se
      n_by <- vars |>
        dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
        dplyr::summarise(n = dplyr::n(), .groups = "drop")
      out <- dplyr::left_join(out, n_by, by = by)
      out$method <- paste0("cpue_mean_of_ratios:", response)
      out$diagnostics <- replicate(nrow(out), list(NULL))
      return(dplyr::select(out, dplyr::all_of(by), estimate, se, ci_low, ci_high, n, method, diagnostics))
    } else {
      m <- survey::svymean(~.cpue, svy2, na.rm = TRUE)
      estimate <- as.numeric(m[1])
      se <- sqrt(as.numeric(stats::vcov(m)))
      ci <- tc_confint(estimate, se, level = conf_level)
      n <- nrow(vars)
      return(tibble::tibble(
        estimate = estimate, se = se, ci_low = ci[1], ci_high = ci[2], n = n,
        method = paste0("cpue_mean_of_ratios:", response), diagnostics = list(NULL)
      ))
    }
  }
}

# Minimal helper: interview-level svy design from `creel_design` or passthrough
#' @keywords internal
tc_interview_svy <- function(design) {
  if (inherits(design, c("survey.design", "survey.design2", "svyrep.design"))) {
    return(design)
  }
  if (inherits(design, "creel_design")) {
    interviews <- design$interviews
    if (is.null(interviews)) cli::cli_abort("creel_design must include $interviews for CPUE/catch estimators.")
    # Use strata vars when available; assume equal weights (warn)
    if (!is.null(design$strata_vars)) {
      strata_present <- intersect(design$strata_vars, names(interviews))
      if (length(strata_present) == 0) strata_present <- NULL
    } else {
      strata_present <- NULL
    }
    cli::cli_warn(c(
      "!" = "Constructing an equal-weight interview design (ids=~1).",
      "i" = "Provide a proper svydesign/svrepdesign for defensible inference."
    ))
    return(survey::svydesign(
      ids = ~1,
      strata = if (!is.null(strata_present)) stats::as.formula(paste("~", paste(strata_present, collapse = "+"))) else NULL,
      data = interviews
    ))
  }
  cli::cli_abort("design must be a svydesign/svrepdesign or creel_design.")
}
