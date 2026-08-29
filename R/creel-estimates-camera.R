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
#'   Hartill, B.W., Taylor, S.M., Keller, K., and Weltersbach, M.S. 2020.
#'   Digital camera monitoring of recreational fishing effort: applications
#'   and challenges. Fish and Fisheries 21:204-215.
#'   \doi{10.1111/faf.12413}
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
  calibration = NULL,
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

  # An outage day's count is unknown, not zero. Dropping it from the numerator
  # while its population day stays in the frame makes it contribute exactly
  # zero hours to the total -- a plausible number, no condition raised, and
  # bit-identical to the estimate obtained by deleting the row (#215).
  #
  # Reported here rather than inside either branch because the two used to
  # disagree about the same input: the ratio path passed `na.rm = TRUE` to
  # `svytotal` and returned a number, the raw path did not and returned `NA`.
  # Both now return `NA`, and both now say why.
  #
  # Not imputed here, and not reweighted: which day is missing is informative,
  # so the treatment is the caller's to choose.
  na_counts <- is.na(counts_data[[count_var]])
  if (any(na_counts)) {
    # Referenced only inside cli glue strings, which the linter cannot see.
    na_dates <- as.character(counts_data[[design$date_col]][na_counts]) # nolint: object_usage_linter
    na_status <- if ("camera_status" %in% names(counts_data)) {
      unique(as.character(counts_data[["camera_status"]][na_counts]))
    } else {
      character()
    }
    cli::cli_warn(
      c(
        paste0(
          "{sum(na_counts)} of {nrow(counts_data)} count ",
          "{cli::qty(nrow(counts_data))}day{?s} ",
          "{cli::qty(sum(na_counts))}{?has/have} a missing ",
          "{.field {count_var}}."
        ),
        "x" = "{cli::qty(na_dates)}Affected date{?s}: {.val {na_dates}}.",
        if (length(na_status) > 0L) {
          c("i" = "{cli::qty(na_status)}Camera status{?es}: {.val {na_status}}.")
        },
        "i" = paste(
          "An outage day's count is unknown, not zero, so the estimate is",
          "{.code NA} rather than a total that silently omits the day."
        ),
        "i" = paste(
          "Fill it with {.fn impute_camera_counts}, or remove the day from the",
          "design if it was not sampled."
        )
      ),
      class = "creel_warning_camera_na_counts"
    )
  }

  # Defined before the branch split because both paths combine variances with
  # it. See the `NaN` note at the calibration component below (#215).
  na_if_nan <- function(x) {
    if (length(x) == 1L && is.nan(x)) NA_real_ else x
  }

  # ---- Ratio calibration path -----------------------------------------------
  if (!is.null(interviews)) {
    if (!effort_col %in% names(interviews)) {
      cli::cli_abort(
        "Column {.field {effort_col}} not found in {.arg interviews}."
      )
    }

    date_col <- design$date_col

    # The pairing below indexes `daily_effort` by date once per matching count
    # row, so a counts table holding two rows for one date reads that day's
    # effort twice and counts it twice on both sides of
    # rho = sum(E_d) / sum(C_d); the svytotal of raw counts then counts it a
    # second time. Both feed the estimate, so a duplicated row -- which carries
    # no new information -- moves the point estimate, not only the SE (GH #142).
    # add_counts() only warns about repeated PSU rows (CNT-06), and only when
    # `count_time_col` is absent, so such a table reaches this path intact.
    #
    # Refused rather than averaged here: two counts on one day are either
    # sub-period snapshots or a data error, and nothing on this path can tell
    # which. `count_time_col` is how a caller states the former, and it already
    # collapses the day to the mean that averaging here would have to assume.
    day_key_cols <- intersect(
      unique(c(date_col, design$strata_cols)),
      names(counts_data)
    )
    day_key <- do.call(
      paste,
      c(lapply(counts_data[day_key_cols], as.character), sep = "\u001f")
    )
    dup_days <- unique(
      as.character(counts_data[[date_col]])[duplicated(day_key)]
    )
    if (length(dup_days) > 0L) {
      cli::cli_abort(
        c(
          "Camera ratio calibration requires one count row per day.",
          "x" = paste(
            "{cli::qty(length(dup_days))}Date{?s} {.val {dup_days}}",
            "{?carries/carry} more than one count row."
          ),
          "i" = paste(
            "The calibration pairs each interview day to one count, so a",
            "repeated day enters the ratio twice and shifts the estimate."
          ),
          "i" = paste(
            "If these are sub-period counts of the same day, pass",
            "{.arg count_time_col} to {.fn add_counts}, which averages them",
            "to one row per day."
          ),
          "i" = "Otherwise remove the repeated rows from the counts table."
        ),
        class = "creel_error_camera_duplicate_count_days"
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
    #
    # Keyed on every column of `design$strata_cols`, not only the first. A
    # design declaring `strata = c(day_type, site)` has strata day_type x site,
    # and a ratio estimated over a coarser partition than the declared one
    # applies one stratum's hours-per-count to another stratum's counts. The
    # damage is set by how unevenly interview effort is allocated across the
    # columns that were dropped, so it is unbounded in principle and silent in
    # practice; where every day is an interview day the ratio of sums
    # telescopes and the point estimate survives, which is why it took an
    # unbalanced fixture to see (#216).
    #
    # Same `\u001f` key as `day_key` above rather than the survey design's
    # `.strata` interaction, whose "." separator can collide two distinct
    # strata into one label.
    strata_cols <- design$strata_cols
    strata_key <- function(df) {
      do.call(paste, c(lapply(df[strata_cols], as.character), sep = "\u001f"))
    }
    strata_label <- function(key) {
      paste(strsplit(key, "\u001f", fixed = TRUE)[[1L]], collapse = " / ")
    }

    missing_strata <- setdiff(strata_cols, names(interviews))
    if (length(missing_strata) > 0L) {
      cli::cli_abort(c(
        paste(
          "{.arg interviews} is missing the stratum",
          "{cli::qty(missing_strata)}column{?s} {.field {missing_strata}}."
        ),
        "x" = paste(
          "The calibration ratio is estimated within each stratum the design",
          "declares, so every stratum column must be present to assign an",
          "interview to one."
        ),
        "i" = "{.arg design} declares {.field {strata_cols}}."
      ))
    }

    counts_keys <- strata_key(counts_data)
    interview_keys <- strata_key(interviews)
    strata_vals <- unique(counts_keys)

    cal_rows <- lapply(strata_vals, function(s) {
      # Referenced only inside cli glue strings, which the linter cannot see.
      s_label <- strata_label(s) # nolint: object_usage_linter
      # Counts for stratum: one row per day
      cnt_sub <- counts_data[counts_keys == s, , drop = FALSE]
      # Interviews for stratum: aggregate per-trip effort to daily totals
      int_sub <- interviews[interview_keys == s, , drop = FALSE]

      if (nrow(int_sub) == 0L || all(is.na(int_sub[[effort_col]]))) {
        cli::cli_abort(c(
          "No interview effort data for stratum {.val {s_label}}.",
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
      #
      # The guard at the top of this path now refuses a repeated date outright
      # (#142), so the two are equal whenever control reaches here. Kept
      # distinct because they answer different questions, and the counts table
      # is only known to be one row per day for as long as that guard stands.
      n_pairs <- length(E_d)
      n_days <- length(unique(int_dates_matched))
      if (n_pairs == 0L || sum(C_d, na.rm = TRUE) == 0) {
        cli::cli_abort(c(
          "No matched interview/count days for stratum {.val {s_label}}.",
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
            "Stratum {.val {s_label}} has one paired interview/count day.",
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
    # No `na.rm = TRUE`: it made a missing count a zero-effort day (#215).
    #
    # No `suppressWarnings()` either. It used to swallow every warning svyby
    # raised, which is half of why an outage produced a confident wrong number.
    # It was also unnecessary: survey's benign "No weights or probabilities
    # supplied" note comes from `svydesign()` when the design is built, not
    # from `svyby()` here -- removing the wrapper surfaces no new noise in the
    # suite, and a narrower handler for that one string would be dead code.
    svy_raw <- survey::svyby(
      count_formula,
      stats::reformulate(strata_cols),
      svy_design,
      survey::svytotal
    )

    # svyby returns one row per observed combination, with the grouping
    # columns carried through under their own names, so the same key pairs the
    # count totals to the calibration ratios computed above.
    strata_order <- strata_key(svy_raw)
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
    # `survey::SE()` reports `NaN` for a stratum whose total is `NA`, which is
    # reachable only since the missing-count fix (#215) stopped dropping those
    # rows. Both marks mean "not measurable", but the calibration component
    # uses `NA` for the same condition (#136), and one function must not report
    # one unknown two ways. Normalised to `NA_real_`; `NaN` is never a
    # meaningful SE here, so nothing measurable is lost.
    var_between <- var_count_sampling + var_calibration
    se_between <- na_if_nan(sqrt(var_between))
    se_components <- list(
      count_sampling = na_if_nan(sqrt(var_count_sampling)),
      calibration = na_if_nan(sqrt(var_calibration))
    )

    # Within-day component (Rasmussen 1998). `add_counts(count_time_col = )`
    # measures it and stores ss_d/k_d on the design; this function used to
    # report a literal 0 for it while it sat there unread, so a 60-unit change
    # in within-day spread produced a bit-identical SE (#217).
    #
    # Scaled by rho_h^2 per stratum: the stored component is a variance of the
    # stratum COUNT total, and the estimate multiplies that total by the
    # stratum's hours-per-count ratio. Same shape as the count-sampling term
    # above, and the same device the aerial estimator uses with h_over_v^2.
    #
    # `target = "sampled_days"` because a camera design carries unit weights --
    # the svyby above is a plain sum over sampled days, not a population
    # expansion -- so the within-day term must be on that same scale. The
    # helper returns a bare 0 rather than a keyed vector when the design has no
    # within-day data, which is why that case is taken first.
    var_within <- if (is.null(design$within_day_var)) {
      0
    } else {
      wd_by_stratum <- compute_within_day_var_contribution( # nolint: object_usage_linter
        design,
        by_vars = strata_cols,
        target = "sampled_days"
      )
      sum(rho_matched^2 * as.numeric(wd_by_stratum[strata_order]))
    }
    method_label <- "camera_ratio"
    # effort_unit_label was set above, where the party-size decision was made.
    # design$angler_effort_col is deliberately not consulted: `interviews` is an
    # argument rather than an add_interviews() attachment, so it describes a
    # different (often absent) set of interviews.
  } else {
    # ---- Raw count expansion fallback ----------------------------------------
    #
    # This branch scales a raw camera count by h_open with no calibration at
    # all, which silently asserts that each counted object contributes exactly
    # one angler-hour per hour open. Its own docstring calls it "similar to the
    # aerial estimator", and under the same author ruling that an aerial count
    # is a raw observer count, it carries the same defect (GH #158).
    #
    # So the branch is now gated: reaching it without interviews requires the
    # caller to say so. Not supplying calibration is not the same claim as
    # declaring that none applies, and only one of them should be silent.
    if (!identical(calibration, "none")) {
      cli::cli_abort(
        c(
          "Camera effort estimation requires a calibration.",
          "x" = "No {.arg interviews} were supplied, so there is nothing to calibrate the counts against.",
          "i" = paste(
            "Supply {.arg interviews} to use the ratio-calibration path, which",
            "estimates hours of effort per camera count and propagates that",
            "ratio's uncertainty."
          ),
          "i" = paste(
            "To expand the raw counts uncalibrated, pass",
            "{.code calibration = \"none\"}. The estimate then assumes one",
            "angler-hour per count per hour open, and the reported SE is",
            "{.code NA} because that assumption's uncertainty is unmeasured."
          )
        ),
        class = "creel_error_camera_calibration_required"
      )
    }

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
    # The declared opt-out sets rho = 1 for the point estimate, so h_open alone
    # scales the counts. Its variance is NA, not 0 and not absent: the caller
    # asserted that no calibration applies, but that assertion is itself
    # unverified, and a 0 would report the maximally uncertain calibration as
    # the most precise one -- the same reasoning as the single-paired-day guard
    # above (GH #136, #158).
    #
    # `calibration` is therefore present-and-NA here, where previously it was
    # absent. Absent means "does not apply"; NA means "applies and is unknown",
    # and under the ruling that a raw count is not pre-corrected, this branch is
    # the second case.
    se_components <- list(
      count_sampling = se_between,
      calibration = NA_real_
    )
    # No na.rm: a sum missing an unknown term is a lower bound, not an SE.
    se_between <- NA_real_
    var_between <- NA_real_
    # The point estimate is the count total times h_open, so the within-day
    # variance of that total scales by h_open^2 (#217).
    var_within <- compute_within_day_var_contribution( # nolint: object_usage_linter
      design,
      by_vars = NULL,
      target = "sampled_days"
    ) *
      h_open^2
    method_label <- "camera_raw"
    # Raw count x h_open hours. The guard above establishes that no T_d has
    # already been applied, so h_open is the sole period source and this is
    # angler-hours -- the same reasoning as the aerial estimator.
    effort_unit_label <- "angler-hours"
  }

  # Combined at the variance level, not by adding two SEs in quadrature:
  # sqrt(sqrt(a)^2 + sqrt(b)^2) is not the same floating-point number as
  # sqrt(a + b). Adding a within-day variance of exactly 0 -- a design with one
  # count per day, where the component is nil by construction rather than
  # unknown -- is exact, so no existing camera SE moves.
  se_within <- sqrt(var_within)
  se <- na_if_nan(sqrt(var_between + var_within))

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
    se_within = se_within,
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
