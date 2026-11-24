# Rates pooled across strata, weighted by each stratum's effort (GH #691).
#
# The interview survey gives every interview weight 1, so a rate pooled across
# strata -- ungrouped, or grouped by a column that is not a stratum -- weighted
# each stratum by its share of the INTERVIEWED effort. Interviewing follows the
# clerk's schedule (weekends oversampled, a fixed number per day), not the
# fishing, so the pooled rate leaned toward whichever stratum was interviewed
# more heavily than it was fished: +22% and -11% on a simulated season, with
# N_h / n_h day weights no better (-12%). The population rate is total catch
# over total effort, built stratum by stratum (Pollock et al. 1994, sec.
# 15.3.3.6):
#
#   R = sum_h E_h R_h / sum_h E_h.
#
# Each interview in stratum h is weighted by w_h = E_h / D_h, where D_h is the
# stratum's sum of the estimator's denominator (effort for a ratio of means,
# party size or 1 for a mean of ratios). The weight is constant within a
# stratum, so each stratum's own rate is untouched, and the survey's ratio then
# equals sum_h E_h A_h / sum_h E_h B_h with A_h = sum(y) / D_h and
# B_h = sum(x) / D_h over the group's interviews in h: exactly the
# effort-weighted rate above, and for a non-stratum group the rate weighted by
# that group's effort in each stratum.
#
# The weights carry the effort estimate, so the rate's variance is the
# survey's (conditional on E) plus the effort's, by the delta method:
#
#   dR/dE_h = (A_h - R B_h) / sum_k E_k B_k,
#
# summed with the effort rows' covariance (effort_rows_weighted_var(), so a
# shared aerial correction enters once). Counts and interviews are independent
# samples, so there is no cross term.

#' Effort weights for a rate pooled across strata
#'
#' Internal (GH #691). Returns `NULL` when nothing is pooled: no strata, one
#' stratum in the calendar, or every stratum column in `by_vars`. Otherwise
#' estimates effort by stratum, reweights the interview survey's rows by
#' `E_h / D_h`, and returns what the variance step needs.
#'
#' @param design A `creel_design`.
#' @param svy The interview `survey.design2` the rate will be estimated on,
#'   before any replicate conversion.
#' @param y,x Names of the numerator and denominator columns in
#'   `svy$variables`. `x = NULL` means a denominator of 1 (an unweighted mean).
#' @param by_vars Grouping columns of the rate, or `NULL`.
#' @param call Frame errors are reported from.
#' @return `NULL`, or a list with the reweighted `svy` and the pieces the
#'   variance step uses.
#' @keywords internal
#' @noRd
rate_strata_pooling <- function(design, svy, y, x, by_vars, call = rlang::caller_env()) {
  strata <- pooled_strata(design, by_vars)
  if (is.null(strata)) {
    return(NULL)
  }
  by_call <- pooling_by_call(strata, by_vars)
  pe <- pooling_effort(design, strata, by_call, call)
  effort <- pe$effort
  E <- pe$E
  se_E <- pe$se_E

  vars <- svy$variables
  live <- is.finite(svy$prob)
  h <- group_key(vars, strata) # nolint: object_usage_linter
  xv <- if (is.null(x)) rep(1, nrow(vars)) else vars[[x]]
  D <- tapply(xv[live], h[live], sum)

  missing_E <- setdiff(names(D), names(E))
  if (length(missing_E) > 0L || anyNA(E[names(D)])) {
    cli::cli_abort(
      c(
        "A rate pooled across strata is weighted by each stratum's effort, \\
         and some interviewed strata have none.",
        "x" = "No effort estimate for: {.val {union(missing_E, names(D)[is.na(E[names(D)])])}}.",
        "i" = "Estimate the rate {.code by = {by_call}} instead."
      ),
      class = c("creel_error_rate_needs_effort", "creel_error_invalid_input"),
      call = call
    )
  }
  # A stratum fished but never interviewed has no rate. Leaving it out would
  # quietly turn the rate into one over the interviewed strata only, so it is
  # refused by name. A stratum whose effort is a known zero holds no fishing
  # and adds nothing either way.
  refuse_unrated_strata(E, names(D), by_call, call)
  w_h <- E[names(D)] / D
  w <- unname(w_h[h])
  # A zero-weight (padded) day keeps its infinite probability; dividing leaves
  # it there.
  svy$prob <- svy$prob / ifelse(live, w, 1)

  list(
    svy = svy,
    data = vars[live, , drop = FALSE],
    h = h[live],
    y = y,
    x = x,
    D = D,
    E = E,
    se_E = se_E,
    effort = effort,
    strata = strata
  )
}

#' The strata a rate would pool across, or `NULL` when it pools none
#'
#' Internal (GH #691): no strata, one stratum in the calendar, or every
#' stratum column in `by_vars`.
#' @keywords internal
#' @noRd
pooled_strata <- function(design, by_vars) {
  strata <- design$strata_cols %||% character(0)
  if (length(strata) == 0L || all(strata %in% by_vars)) {
    return(NULL)
  }
  if (nrow(unique(design$calendar[strata])) < 2L) {
    return(NULL)
  }
  strata
}

#' The `by =` a refusal suggests: the strata plus the caller's columns
#' @keywords internal
#' @noRd
pooling_by_call <- function(strata, by_vars) {
  cols <- unique(c(strata, by_vars))
  by_call <- paste(cols, collapse = ", ")
  if (length(cols) > 1L) by_call <- paste0("c(", by_call, ")")
  by_call
}

#' Each stratum's effort, for weighting a rate pooled across strata
#'
#' Internal (GH #691). Refuses a design without counts, and wraps an effort
#' error (a camera design, an unsampled stratum) as the reason. A section's
#' rate is weighted by that section's own effort: sectioned effort is not
#' estimated `by`, so the section's counts are taken on their own, which is
#' the same N_h / n_h expansion of the section's counts.
#' @keywords internal
#' @noRd
pooling_effort <- function(design, strata, by_call, call) {
  if (is.null(design$counts)) {
    cli::cli_abort(
      c(
        "A rate pooled across strata needs each stratum's effort, and this design has no counts.",
        "x" = "Pooling interviews alone weights each stratum by how heavily it was interviewed, \\
               not by how much it was fished (Pollock et al. 1994).",
        "i" = "Add counts with {.fn add_counts}, or estimate the rate {.code by = {by_call}}. \\
               See {.code ?estimate_catch_rate} for why."
      ),
      class = c("creel_error_rate_needs_effort", "creel_error_invalid_input"),
      call = call
    )
  }
  effort_design <- design
  section_col <- design$section_col
  if (!is.null(design[["sections"]]) && !is.null(section_col)) {
    sec <- unique(as.character(design$interviews[[section_col]]))
    if (length(sec) == 1L) {
      effort_design$counts <- design$counts[as.character(design$counts[[section_col]]) == sec, , drop = FALSE]
      effort_design$sections <- NULL
    }
  }
  effort <- tryCatch(
    estimate_effort(effort_design, by = dplyr::all_of(strata)), # nolint: object_usage_linter
    error = function(e) {
      cli::cli_abort(
        c(
          "A rate pooled across strata is weighted by each stratum's effort, \\
           which could not be estimated.",
          "i" = "Fix the effort error below, or estimate the rate {.code by = {by_call}}."
        ),
        parent = e,
        class = c("creel_error_rate_needs_effort", "creel_error_invalid_input"),
        call = call
      )
    }
  )
  e_key <- group_key(effort$estimates, strata) # nolint: object_usage_linter
  list(
    effort = effort,
    E = stats::setNames(effort$estimates$estimate, e_key),
    se_E = stats::setNames(effort$estimates$se, e_key)
  )
}

#' Refuse a pooled rate when a fished stratum has no rate
#' @keywords internal
#' @noRd
refuse_unrated_strata <- function(E, rated, by_call, call) {
  unseen <- setdiff(names(E), rated)
  unseen <- unseen[is.na(E[unseen]) | E[unseen] > 0]
  if (length(unseen) > 0L) {
    cli::cli_abort(
      c(
        "A rate pooled across strata needs a rate in every stratum that was fished.",
        "x" = "Effort but no usable interviews in: {.val {unseen}}.",
        "i" = "Estimate the rate {.code by = {by_call}} instead. \\
               See {.code ?estimate_catch_rate} for why."
      ),
      class = c("creel_error_rate_needs_effort", "creel_error_invalid_input"),
      call = call
    )
  }
  invisible(NULL)
}

#' Add the effort term to a rate pooled across strata
#'
#' Internal (GH #691). `estimates` holds the rows the survey returned, with
#' `estimate`, `se`, `ci_lower`, `ci_upper` and the `by_vars` columns. Each
#' row's variance gains `g' Sigma_E g` with `g_h = (A_h - R B_h) / sum_k E_k B_k`;
#' the interval is widened by the same factor as the SE, keeping whichever
#' reference distribution the survey call used.
#'
#' @param estimates Data frame of rate rows.
#' @param pool The list from `rate_strata_pooling()`.
#' @param by_vars Grouping columns, or `NULL`.
#' @param conf_level Confidence level, for an interval built from the SE alone.
#' @return `estimates` with `se`, `ci_lower`, `ci_upper` updated.
#' @keywords internal
#' @noRd
rate_pooling_add_effort_var <- function(estimates, pool, by_vars, conf_level = 0.95) {
  if (is.null(pool)) {
    return(estimates)
  }
  d <- pool$data
  yv <- d[[pool$y]]
  xv <- if (is.null(pool$x)) rep(1, nrow(d)) else d[[pool$x]]
  strata_keys <- names(pool$D)
  E <- unname(pool$E[strata_keys])
  se_E_all <- pool$se_E
  # effort_rows_weighted_var() reads the effort object's rows in their own
  # order, so g is laid out in that order with zeros where nothing was
  # interviewed.
  e_keys <- group_key(pool$effort$estimates, pool$strata) # nolint: object_usage_linter

  row_key <- if (length(by_vars) == 0L) rep("", nrow(estimates)) else group_key(estimates, by_vars) # nolint: object_usage_linter
  data_key <- if (length(by_vars) == 0L) rep("", nrow(d)) else group_key(d, by_vars) # nolint: object_usage_linter

  var_E <- vapply(seq_len(nrow(estimates)), function(i) {
    R <- estimates$estimate[i]
    if (!is.finite(R)) {
      return(NA_real_)
    }
    k <- data_key == row_key[i]
    # Summed per stratum key: a group with no interviews in a stratum has an
    # empty sum there, which is 0; a value that is NA stays NA.
    A <- vapply(strata_keys, function(h) sum(yv[k & pool$h == h]), numeric(1)) / pool$D
    B <- vapply(strata_keys, function(h) sum(xv[k & pool$h == h]), numeric(1)) / pool$D
    denom <- sum(E * B)
    g <- (A - R * B) / denom
    # Strata with effort but no interviews were refused above; any left here
    # have a known zero effort and no part in the ratio, so dR/dE_h = 0.
    g_full <- stats::setNames(rep(0, length(e_keys)), e_keys)
    g_full[strata_keys] <- g
    effort_rows_weighted_var(pool$effort, unname(se_E_all[e_keys]), unname(g_full)) # nolint: object_usage_linter
  }, numeric(1))

  se_old <- estimates$se
  se_new <- sqrt(se_old^2 + var_E)
  scale <- ifelse(is.finite(se_old) & se_old > 0, se_new / se_old, NA_real_)
  est <- estimates$estimate
  lower <- est - (est - estimates$ci_lower) * scale
  upper <- est + (estimates$ci_upper - est) * scale
  # A survey SE of exactly 0 (constant ratios) leaves no interval to widen;
  # the effort term alone then gives a normal interval on the new SE.
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  flat <- is.finite(se_old) & se_old == 0 & is.finite(se_new)
  lower[flat] <- est[flat] - z * se_new[flat]
  upper[flat] <- est[flat] + z * se_new[flat]
  estimates$ci_lower <- lower
  estimates$ci_upper <- upper
  estimates$se <- se_new
  estimates
}

# Diagnostics that compare rates on the same interviews -- complete against
# incomplete trips, one variance method against another, one estimator against
# another -- ask a question effort does not enter, and they run on designs
# that may have no counts. They estimate with the pooling switched off, so the
# comparison is like with like and needs no effort (GH #691).
rate_pooling_state <- new.env(parent = emptyenv())
rate_pooling_state$off <- FALSE

#' Evaluate `expr` with effort-weighted pooling of rates switched off
#'
#' Internal (GH #691). For the diagnostic comparisons only; see above.
#' @keywords internal
#' @noRd
without_rate_pooling <- function(expr) {
  old <- rate_pooling_state$off
  rate_pooling_state$off <- TRUE
  on.exit(rate_pooling_state$off <- old, add = TRUE)
  expr
}

#' Whether rates pooled across strata are effort-weighted in this call
#' @keywords internal
#' @noRd
rate_pooling_on <- function() {
  !isTRUE(rate_pooling_state$off)
}

#' Regression CPUE pooled across strata: each stratum's slope, effort-weighted
#'
#' Internal (GH #691). A regression slope is not a ratio of two totals once it
#' has an intercept, so the interview weights used for the other rates do not
#' give a combination of the strata's rates. Each stratum's slope b_h is
#' estimated on its own (a domain of the day-clustered survey), and
#'
#'   R = sum_h E_h b_h / sum_h E_h,
#'
#' the same combination the other rates use and the one a total multiplies.
#' The strata are independent samples, so
#'
#'   Var(R) = sum_h (E_h / E)^2 Var(b_h) + g' Sigma_E g,  g_h = (b_h - R) / E,
#'
#' with the effort rows' covariance through effort_rows_weighted_var().
#' @keywords internal
#' @noRd
regression_pooled_total <- function(design, strata, conf_level, force_origin, variance_method,
                                    call = rlang::caller_env()) {
  by_call <- pooling_by_call(strata, NULL)
  # The ungrouped rate's own floor (3 interviews, zero-effort trips not
  # counted) still applies; the per-stratum fits below only warn below it.
  eff <- design$interviews[[design$angler_effort_col]]
  n_valid <- sum(is.na(eff) | eff != 0)
  if (n_valid < 3L) {
    cli::cli_abort(c(
      "Regression CPUE requires at least 3 interviews.",
      "x" = "Only {n_valid} valid interview{?s} available after filtering."
    ), call = call)
  }
  pe <- pooling_effort(design, strata, by_call, call)
  per <- estimate_cpue_reg_grouped( # nolint: object_usage_linter
    design, strata, conf_level, force_origin, variance_method,
    call = call
  )$estimates
  # A stratum whose slope cannot be identified has no rate, like one with no
  # interviews; one with an unknown effort cannot be weighted.
  per <- per[!is.na(per$estimate), , drop = FALSE]
  key <- group_key(per, strata) # nolint: object_usage_linter
  refuse_unrated_strata(pe$E, key, by_call, call)
  if (anyNA(pe$E[key])) {
    cli::cli_abort(
      c(
        "A rate pooled across strata is weighted by each stratum's effort, \\
         and some strata's effort is unknown.",
        "x" = "Unknown effort in: {.val {key[is.na(pe$E[key])]}}.",
        "i" = "Estimate the rate {.code by = {by_call}} instead."
      ),
      class = c("creel_error_rate_needs_effort", "creel_error_invalid_input"),
      call = call
    )
  }
  E <- unname(pe$E[key])
  b <- per$estimate
  E_tot <- sum(E)
  R <- sum(E * b) / E_tot
  e_keys <- group_key(pe$effort$estimates, strata) # nolint: object_usage_linter
  # Strata with effort but no slope were refused above; any left here have a
  # known zero effort, take no part in R, and have dR/dE_h = 0.
  g_full <- stats::setNames(rep(0, length(e_keys)), e_keys)
  g_full[key] <- (b - R) / E_tot
  var_R <- sum((E / E_tot)^2 * per$se^2) +
    effort_rows_weighted_var(pe$effort, unname(pe$se_E[e_keys]), unname(g_full)) # nolint: object_usage_linter
  se <- sqrt(var_R)
  # Normal-scale interval, as the per-stratum regression intervals are.
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  tibble::tibble(
    estimate = R, se = se,
    ci_lower = R - z * se, ci_upper = R + z * se,
    n = sum(per$n)
  )
}

#' Refuse a regression grouped by a column that is not a stratum, across strata
#' @keywords internal
#' @noRd
refuse_pooled_grouped_regression <- function(strata, by_vars, call) {
  cli::cli_abort(
    c(
      "A regression catch rate grouped by {.field {by_vars}} cannot be pooled across strata.",
      "x" = "Across strata each stratum's slope is weighted by its effort, and a group \\
             that is not a stratum has no effort of its own to weight its slopes by.",
      "i" = "Estimate it {.code by = {pooling_by_call(strata, by_vars)}}, or use \\
             {.code estimator = \"ratio-of-means\"}. See {.code ?estimate_catch_rate} for why."
    ),
    class = c("creel_error_regression_pooled_group", "creel_error_invalid_input"),
    call = call
  )
}

#' Bus-route or ice rate pooled across strata: days weighted N_h / n_h
#'
#' Internal (GH #691). A bus-route rate is a ratio of Horvitz-Thompson
#' contributions summed over the sampled days, so pooled across strata it
#' weighted each stratum by its sampled days rather than its calendar days.
#' Each stratum's days are weighted by N_h / n_h, the stratum's calendar days
#' over its sampled days: the ratio is then of the expanded totals,
#' sum_h E_h R_h / sum_h E_h, with E_h the stratum's bus-route effort. The
#' weight is a known constant and the numerator and effort come from the same
#' interviews, so the survey's own ratio variance is the whole of it.
#'
#' n_h must count every day worked, including days nobody fished, so the
#' design's register of sampled days is required (`creel_design(sampled = )`),
#' and a worked day with no interview enters as a zero.
#'
#' @param interviews Rate rows, padded, with `.psu`.
#' @param design A bus-route or ice `creel_design`.
#' @param by_vars Grouping columns of the rate, or `NULL`.
#' @param zero_cols Contribution columns a worked day with no interview holds
#'   as 0.
#' @return `NULL` when nothing is pooled; otherwise a list with the rows
#'   (worked days added) and the weighted `survey.design2`.
#' @keywords internal
#' @noRd
br_pooled_rate_survey <- function(interviews, design, by_vars, zero_cols, call = rlang::caller_env()) {
  strata <- if (rate_pooling_on()) pooled_strata(design, by_vars) else NULL
  if (is.null(strata)) {
    return(NULL)
  }
  by_call <- pooling_by_call(strata, by_vars)
  sampled_col <- design$sampled_col
  if (is.null(sampled_col)) {
    cli::cli_abort(
      c(
        "A bus-route rate pooled across strata needs the register of sampled days.",
        "x" = "Each stratum is weighted by its calendar days over its sampled days, and \\
               without the register the days nobody fished cannot be counted.",
        "i" = "Pass {.code creel_design(sampled = )}, a logical calendar column marking \\
               every day worked, or estimate the rate {.code by = {by_call}}. \\
               See {.code ?estimate_catch_rate} for why."
      ),
      class = c("creel_error_rate_needs_effort", "creel_error_sampled_register", "creel_error_invalid_input"),
      call = call
    )
  }
  date_col <- design$date_col
  cal <- design$calendar
  worked <- cal[cal[[sampled_col]], unique(c(date_col, strata)), drop = FALSE]
  worked <- worked[!duplicated(as.character(worked[[date_col]])), , drop = FALSE]
  pop <- stratum_population_days(cal, strata, date_col) # nolint: object_usage_linter
  smp <- dplyr::count(worked, dplyr::across(dplyr::all_of(strata)), name = ".n_sampled")
  pop <- dplyr::left_join(pop, smp, by = strata)
  if (anyNA(pop$.n_sampled)) {
    cells <- group_key(pop[is.na(pop$.n_sampled), , drop = FALSE], strata) # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "A rate pooled across strata needs a rate in every stratum that was fished.",
        "x" = "No sampled day in: {.val {gsub('\u001f', ' / ', cells, fixed = TRUE)}}.",
        "i" = "Estimate the rate {.code by = {by_call}} instead. \\
               See {.code ?estimate_catch_rate} for why."
      ),
      class = c("creel_error_rate_needs_effort", "creel_error_invalid_input"),
      call = call
    )
  }

  # A worked day with no interview is a sampled day of zero fishing.
  iv_date <- interview_psu_col(design, interviews) %||% date_col # nolint: object_usage_linter
  empty <- worked[!as.character(worked[[date_col]]) %in% as.character(interviews[[iv_date]]), , drop = FALSE]
  if (nrow(empty) > 0L) {
    names(empty)[names(empty) == date_col] <- iv_date
    # Copies of a kept row, so svyby() makes no group of them; their
    # contributions are zero and so add nothing to any group.
    filler <- interviews[rep(1L, nrow(empty)), , drop = FALSE]
    rownames(filler) <- NULL
    for (k in names(empty)) filler[[k]] <- empty[[k]]
    for (k in zero_cols) filler[[k]] <- 0
    filler$.synthetic <- TRUE
    filler$.psu <- as.character(filler[[iv_date]])
    interviews <- rbind(interviews, filler)
  }
  # A stratum interviewed but with no trip of the kind used (a trip filter
  # left only padded days) has no rate; leaving it in as zeros would report
  # the other strata's rate as the season's.
  real <- if (".synthetic" %in% names(interviews)) !interviews$.synthetic else rep(TRUE, nrow(interviews))
  interviewed <- unique(group_key(design$interviews, strata)) # nolint: object_usage_linter
  rated <- unique(group_key(interviews[real, , drop = FALSE], strata)) # nolint: object_usage_linter
  unrated <- setdiff(interviewed, rated)
  if (length(unrated) > 0L) {
    cli::cli_abort(
      c(
        "A rate pooled across strata needs a rate in every stratum that was fished.",
        "x" = "No trips of the kind used in: {.val {gsub('\u001f', ' / ', unrated, fixed = TRUE)}}.",
        "i" = "Estimate the rate {.code by = {by_call}} instead. \\
               See {.code ?estimate_catch_rate} for why."
      ),
      class = c("creel_error_rate_needs_effort", "creel_error_invalid_input"),
      call = call
    )
  }
  refuse_reserved_join_columns(interviews, c(".N_avail", ".n_sampled"), "interviews") # nolint: object_usage_linter
  interviews <- dplyr::left_join(interviews, pop, by = strata)
  interviews$.br_pool_w <- interviews$.N_avail / interviews$.n_sampled
  key <- strata_design_key(interviews, stats::reformulate(strata)) # nolint: object_usage_linter
  svy <- survey::svydesign(
    ids = ~.psu, strata = key$strata, weights = ~.br_pool_w,
    data = key$data, nest = TRUE
  )
  # Day-clustered, so a stratum with one sampled day is refused by name
  # (get_variance_design()), not left to survey's unclassed error.
  attr(svy, "interview_day_psu") <- TRUE
  list(interviews = interviews, survey = svy)
}
