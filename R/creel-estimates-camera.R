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
#' @param n_anglers Optional party size, used to convert `effort_col` to
#'   angler-hours before calibration. Either a character scalar naming a column
#'   in `interviews`, or a single positive number stating a constant party size.
#'   `NULL` (default) leaves `effort_col` as supplied and the returned unit
#'   unknown.
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
  n_anglers = NULL,
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

  # Counts filled by impute_camera_counts() are flagged .imputed but are
  # indistinguishable from observations once inside svytotal(): the imputation
  # model's prediction uncertainty is dropped, and predictions are smoother
  # than real counts, so the between-day variance is understated twice over
  # (GH #137). Warned on both paths until that variance is propagated.
  if (".imputed" %in% names(counts_data)) {
    n_imputed <- sum(as.logical(counts_data[[".imputed"]]), na.rm = TRUE)
    if (n_imputed > 0L) {
      pct_imputed <- round(100 * n_imputed / nrow(counts_data), 1)
      cli::cli_warn(
        c(
          paste0(
            "{n_imputed} of {nrow(counts_data)} count ",
            "{cli::qty(nrow(counts_data))}day{?s} ({pct_imputed}%) ",
            "{cli::qty(n_imputed)}{?contains/contain} imputed counts."
          ),
          "x" = "Prediction uncertainty for imputed counts is not included in the SE.",
          "i" = paste(
            "Imputed counts also vary less than observed ones, so the",
            "between-day component is understated as well; the reported SE is",
            "a lower bound."
          )
        ),
        class = "creel_warning_camera_imputed_counts"
      )
    }
  }

  # Identify count variable
  excluded_cols <- c(
    design$date_col,
    design$strata_cols,
    design$psu_col,
    "camera_status"
  )
  count_var <- if (!is.null(intercept_col) && intercept_col %in% names(counts_data)) {
    intercept_col
  } else {
    resolve_count_col( # nolint: object_usage_linter
      counts = counts_data,
      excluded = excluded_cols,
      count_col = design$count_col
    )
  }

  # ---- Ratio calibration path -----------------------------------------------
  if (!is.null(interviews)) {
    if (!effort_col %in% names(interviews)) {
      cli::cli_abort(
        "Column {.field {effort_col}} not found in {.arg interviews}."
      )
    }
    # Finding 22: rho is a ratio of sums, so the counts cancel and the estimate
    # inherits whatever unit `effort_col` holds. Supplying n_anglers makes this
    # function perform the party-size multiplication itself, which is what earns
    # the label -- the same rule add_interviews() applies, through the same
    # helper, rather than a second implementation of it.
    if (!is.null(n_anglers)) {
      interviews <- compute_angler_effort(
        interviews,
        effort = !!effort_col,
        n_anglers = !!n_anglers
      )
      effort_col <- ".angler_effort"
      effort_unit_label <- "angler-hours"
    } else {
      # Warned rather than silent because the caller can now act on it. Before
      # n_anglers existed this warning would have named a gap with no means to
      # close it.
      cli::cli_warn(c(
        "Camera ratio calibration cannot tell angler-hours from party-hours.",
        "x" = paste(
          "{.field {effort_col}} is a caller-supplied column and nothing on",
          "this path normalises it by party size."
        ),
        "i" = paste(
          "Pass {.arg n_anglers} -- a column in {.arg interviews}, or a constant",
          "party size -- to make the unit derivable."
        ),
        "i" = "The estimate is returned with an unknown unit until then."
      ))
      effort_unit_label <- NA_character_
    }
    # Build calibration ratio per stratum: mean(effort) / mean(camera_count)
    strata_col <- design$strata_cols[1L]
    strata_vals <- unique(counts_data[[strata_col]])

    date_col <- design$date_col

    cal_rows <- lapply(strata_vals, function(s) {
      # Counts for stratum: one row per day
      cnt_sub <- counts_data[counts_data[[strata_col]] == s, , drop = FALSE]
      # Interviews for stratum: aggregate per-trip effort to daily totals
      int_sub <- interviews[interviews[[strata_col]] == s, , drop = FALSE]

      if (nrow(int_sub) == 0L || all(is.na(int_sub[[effort_col]]))) {
        cli::cli_abort(c(
          "No interview effort data for stratum {.val {s}}.",
          "x" = "Cannot compute calibration ratio."
        ))
      }

      # Aggregate to daily effort totals (hours/day on interview days)
      daily_effort <- tapply(
        int_sub[[effort_col]],
        int_sub[[date_col]],
        sum,
        na.rm = TRUE
      )
      int_dates <- names(daily_effort)

      # Camera counts on interview days only (paired calibration per Hartill 2020)
      cnt_paired <- cnt_sub[[count_var]][cnt_sub[[date_col]] %in% int_dates]
      int_dates_matched <- as.character(
        cnt_sub[[date_col]][cnt_sub[[date_col]] %in% int_dates]
      )
      E_d <- as.numeric(daily_effort[int_dates_matched])
      C_d <- cnt_paired

      # Two different counts: the paired vectors' length drives the variance
      # arithmetic, but whether the ratio has any measurable spread is a
      # question about distinct calendar days. A counts table may hold more
      # than one row per date -- add_counts() only warns (CNT-06) -- and one
      # day repeated twice is still one day's information, so keying the
      # single-day test on row count would let a duplicate row restore the
      # false-precision path this guard exists to close (#136).
      n_pairs <- length(E_d)
      n_days <- length(unique(int_dates_matched))
      if (n_pairs == 0L || sum(C_d, na.rm = TRUE) == 0) {
        cli::cli_abort(c(
          "No matched interview/count days for stratum {.val {s}}.",
          "x" = "Cannot compute calibration ratio."
        ))
      }

      # Ratio of sums: rho = sum(E_d) / sum(C_d) (hours/count)
      rho <- sum(E_d, na.rm = TRUE) / sum(C_d, na.rm = TRUE)

      # Variance via ratio-estimator delta method on paired daily residuals
      # var(rho) = sum((E_d - rho*C_d)^2) / (n*(n-1)*mean_C^2)
      mean_C <- mean(C_d, na.rm = TRUE)
      if (n_days > 1L) {
        resid_d <- E_d - rho * C_d
        var_rho <- sum(resid_d^2, na.rm = TRUE) /
          (n_pairs * (n_pairs - 1L) * mean_C^2)
      } else {
        # One paired day gives the ratio no measurable spread, so its variance
        # is unknown -- not zero. A zero would enter the delta term
        # T^2 * var_rho as "the multiplier is known exactly", reporting the
        # maximally uncertain calibration as the most precise one. NA is the
        # package's mark for uncertainty it cannot measure (se_of_mean() for
        # n < 2), and it propagates into the combined SE below.
        cli::cli_warn(
          c(
            "Stratum {.val {s}} has one paired interview/count day.",
            "x" = "The calibration ratio's variance cannot be measured from a single pair.",
            "i" = "Its contribution is {.code NA}, so the reported SE is {.code NA} rather than falsely exact.",
            "i" = "Add a second matched interview day in this stratum to recover an SE."
          ),
          class = "creel_warning_camera_single_day"
        )
        var_rho <- NA_real_
      }

      data.frame(
        stratum = s,
        rho = rho,
        var_rho = var_rho,
        n_cam = nrow(cnt_sub),
        n_int = nrow(int_sub),
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
    var_rho_matched <- cal$var_rho[match(strata_order, as.character(cal$stratum))]
    total_counts_h <- as.numeric(coef(svy_raw))

    estimate <- sum(total_counts_h * rho_matched)
    # SE via delta method: Var(E_h) = rho_h^2 * Var(total_count_h) + total_count_h^2 * Var(rho_h)
    #
    # The two summands are separable and only the second can be unknown, so
    # they are named and reported as components (GH #141). Var(rho_h) is NA for
    # a stratum with one paired day (GH #136) and neither sum() uses na.rm, so
    # the calibration component and the total both stay NA -- the total must,
    # because a sum missing an unknown term is a lower bound, not an SE. What
    # the split adds is that the count-sampling part remains reportable, so the
    # NA says which half is unknown instead of only blocking.
    #
    # Split at the variance level rather than combining two SEs in quadrature:
    # sqrt(sqrt(a)^2 + sqrt(b)^2) is not the same floating-point number as
    # sqrt(a + b), and no existing camera SE may move.
    var_count_sampling <- sum((survey::SE(svy_raw) * rho_matched)^2)
    var_calibration <- sum(total_counts_h^2 * var_rho_matched)
    se_between <- sqrt(var_count_sampling + var_calibration)
    se_components <- list(
      count_sampling = sqrt(var_count_sampling),
      calibration = sqrt(var_calibration)
    )
    method_label <- "camera_ratio"
    # effort_unit_label was set above, where the party-size decision was made.
    # design$angler_effort_col is deliberately not consulted: `interviews` is an
    # argument rather than an add_interviews() attachment, so it describes a
    # different (often absent) set of interviews.
  } else {
    # ---- Raw count expansion fallback ----------------------------------------
    if (is.null(h_open) || !is.numeric(h_open) || h_open <= 0) {
      cli::cli_abort(
        "{.arg h_open} must be a positive number when no interview data are provided for camera effort estimation."
      )
    }

    # This branch expands a raw count by h_open. If add_counts() already
    # multiplied the count column by T_d, h_open applies time a second time
    # (finding 21). effort_unit is set to angler-hours only where that
    # multiplication happened, so it is the reliable witness.
    #
    # Deliberately scoped to this branch. The ratio-calibration path above
    # divides by mean(count) before multiplying by count, so a constant T_d
    # cancels and does no harm there.
    if (identical(design$effort_unit %||% NA_character_, "angler-hours")) {
      cli::cli_abort(
        c(
          "Counts already carry the period length, so {.arg h_open} would apply time twice.",
          "x" = "{.fn add_counts} was given {.arg period_length_col}, which converted the counts to angler-hours.",
          "i" = "Drop {.arg period_length_col} from {.fn add_counts}, or supply interviews to use the calibration path."
        ),
        class = "creel_error_camera_period_length"
      )
    }

    count_formula <- stats::reformulate(count_var)
    svy_design <- get_variance_design(design$survey, variance_method) # nolint: object_usage_linter
    svy_result <- suppressWarnings(
      survey::svytotal(count_formula, svy_design)
    )

    estimate <- as.numeric(coef(svy_result)) * h_open
    se_between <- as.numeric(survey::SE(svy_result)) * h_open
    # This branch has no calibration ratio, so `calibration` is absent rather
    # than NA: the component does not apply here, which is a different claim
    # from applying and being unmeasurable (GH #141). h_open is a supplied
    # constant and contributes no variance of its own, so the whole SE is the
    # count-sampling term.
    se_components <- list(count_sampling = se_between)
    method_label <- "camera_raw"
    # Raw count x h_open hours. The guard above establishes that no T_d has
    # already been applied, so h_open is the sole period source and this is
    # angler-hours -- the same reasoning as the aerial estimator.
    effort_unit_label <- "angler-hours"
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
    estimate = estimate,
    se = se,
    se_between = se_between,
    se_within = 0,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n = n
  )

  new_creel_estimates( # nolint: object_usage_linter
    # nolint: object_usage_linter
    estimates = estimates_df,
    method = method_label,
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL,
    # Set per branch above: the two paths reach this constructor with different
    # provenance for the same quantity.
    unit = effort_unit_label, # nolint: object_usage_linter
    # Also set per branch: the raw path has no calibration component at all.
    se_components = se_components # nolint: object_usage_linter
  )
}
