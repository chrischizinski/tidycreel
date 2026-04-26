#' Camera-based effort estimation via ratio calibration
#'
#' Internal function for estimating angler effort from camera/time-lapse
#' count data.  The camera records daily ingress counts (or preprocessed
#' ingress-egress totals).  Interview data provide a ratio calibration:
#'
#' \deqn{E_{total} = \sum_{h} N_h \times \hat{\mu}_h}
#'
#' where \eqn{\hat{\mu}_h = \bar{C}_h \times \hat{\rho}_h} is the stratum mean
#' camera count multiplied by the ratio of mean interview effort to mean
#' interview-period camera count (\eqn{\hat{\rho}_h}).
#'
#' When no interview data are attached (`design$interviews` is `NULL`), the
#' function falls back to using raw camera counts scaled by `h_open` (the
#' number of fishable hours per day), similar to the aerial estimator.
#'
#' @param design A `creel_design` object with `design_type == "camera"` and
#'   `design$counts` populated by `add_counts()`.
#' @param interviews Optional data frame of interview records used for ratio
#'   calibration.  If `NULL`, falls back to raw count expansion.
#' @param effort_col Character scalar.  Column in `interviews` that contains
#'   per-trip effort (e.g. hours fished). Default `"hours_fished"`.
#' @param intercept_col Character scalar.  Column in `interviews` or
#'   `design$counts` that contains the camera count during the interview
#'   period (for counter mode, this is `ingress_count` from the counts
#'   table; for ingress-egress mode, the preprocessed total). Default `NULL`
#'   (auto-detect: uses the first numeric count column).
#' @param h_open Numeric scalar.  Fishable hours per day.  Required when
#'   `interviews` is `NULL` (raw count expansion). Default `NULL`.
#' @param variance_method Character scalar.  Passed to `get_variance_design()`.
#' @param conf_level Numeric confidence level. Default `0.95`.
#'
#' @return A `creel_estimates` object.
#'
#' @references
#'   Hartill, B.W., Cryer, M., and Morrison, M.A. 2020. Camera-based creel
#'   surveys: estimating fishing effort and catch rates from ingress-egress
#'   camera counts. Fisheries Research 231:105706.
#'   \doi{10.1016/j.fishres.2020.105706}
#'
#' @keywords internal
#' @noRd
estimate_effort_camera <- function(
  # nolint: object_usage_linter
  design,
  interviews = NULL,
  effort_col = "hours_fished",
  intercept_col = NULL,
  h_open = NULL,
  variance_method = "taylor",
  conf_level = 0.95
) {
  counts_data <- design$counts
  if (is.null(counts_data) || nrow(counts_data) == 0L) {
    cli::cli_abort(c(
      "Camera effort estimation requires count data.",
      "i" = "Call {.fn add_counts} before estimating camera effort."
    ))
  }

  # Identify count variable
  excluded_cols <- c(
    design$date_col, design$strata_cols,
    design$psu_col, "camera_status"
  )
  num_cols <- names(counts_data)[sapply(counts_data, is.numeric)]
  count_var <- if (!is.null(intercept_col) && intercept_col %in% names(counts_data)) {
    intercept_col
  } else {
    setdiff(num_cols, excluded_cols)[1L]
  }

  if (is.na(count_var) || is.null(count_var)) {
    cli::cli_abort("No numeric count column found in count data.")
  }

  # ---- Ratio calibration path -----------------------------------------------
  if (!is.null(interviews)) {
    if (!effort_col %in% names(interviews)) {
      cli::cli_abort(
        "Column {.field {effort_col}} not found in {.arg interviews}."
      )
    }
    # Build calibration ratio per stratum: mean(effort) / mean(camera_count)
    strata_col <- design$strata_cols[1L]
    strata_vals <- unique(counts_data[[strata_col]])

    cal_rows <- lapply(strata_vals, function(s) {
      cnt_s <- counts_data[[count_var]][counts_data[[strata_col]] == s]
      int_s <- interviews[[effort_col]][interviews[[strata_col]] == s]

      if (length(int_s) == 0L || all(is.na(int_s))) {
        cli::cli_abort(
          "No interview effort data for stratum {.val {s}}. ",
          "Cannot compute calibration ratio."
        )
      }
      if (mean(cnt_s, na.rm = TRUE) == 0) {
        cli::cli_abort(
          "Mean camera count is 0 in stratum {.val {s}}. ",
          "Cannot compute calibration ratio."
        )
      }

      rho <- mean(int_s, na.rm = TRUE) / mean(cnt_s, na.rm = TRUE)
      data.frame(
        stratum = s,
        rho = rho,
        n_cam = length(cnt_s),
        n_int = length(int_s),
        stringsAsFactors = FALSE
      )
    })
    cal <- do.call(rbind, cal_rows)

    # Weighted total: sum(N_h * rho_h * mean_count_h)
    # Use svytotal on raw count then multiply stratum-level totals by rho
    count_formula <- stats::reformulate(count_var)
    svy_design <- get_variance_design(design$survey, variance_method) # nolint: object_usage_linter
    svy_raw <- suppressWarnings(
      survey::svyby(
        count_formula,
        stats::as.formula(paste0("~", strata_col)),
        svy_design,
        survey::svytotal,
        na.rm = TRUE
      )
    )

    strata_order <- as.character(svy_raw[[strata_col]])
    rho_matched <- cal$rho[match(strata_order, as.character(cal$stratum))]

    estimate <- sum(coef(svy_raw) * rho_matched)
    se_between <- sqrt(sum((survey::SE(svy_raw) * rho_matched)^2))
    method_label <- "camera_ratio"
  } else {
    # ---- Raw count expansion fallback ----------------------------------------
    if (is.null(h_open) || !is.numeric(h_open) || h_open <= 0) {
      cli::cli_abort(
        "{.arg h_open} must be a positive number when no interview data ",
        "are provided for camera effort estimation."
      )
    }

    count_formula <- stats::reformulate(count_var)
    svy_design <- get_variance_design(design$survey, variance_method) # nolint: object_usage_linter
    svy_result <- suppressWarnings(
      survey::svytotal(count_formula, svy_design)
    )

    estimate <- as.numeric(coef(svy_result)) * h_open
    se_between <- as.numeric(survey::SE(svy_result)) * h_open
    method_label <- "camera_raw"
  }

  # Combined SE (no within-day component for camera designs)
  se <- se_between

  # Degrees of freedom and CI
  df <- as.numeric(survey::degf(svy_design))
  alpha <- 1 - conf_level
  t_crit <- qt(1 - alpha / 2, df = df)
  ci_lower <- estimate - t_crit * se
  ci_upper <- estimate + t_crit * se

  n <- nrow(counts_data)

  estimates_df <- tibble::tibble(
    estimate   = estimate,
    se         = se,
    se_between = se_between,
    se_within  = 0,
    ci_lower   = ci_lower,
    ci_upper   = ci_upper,
    n          = n
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = estimates_df,
    method          = method_label,
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = NULL
  )
}
