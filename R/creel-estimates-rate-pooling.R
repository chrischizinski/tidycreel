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
  strata <- design$strata_cols %||% character(0)
  if (length(strata) == 0L || all(strata %in% by_vars)) {
    return(NULL)
  }
  if (nrow(unique(design$calendar[strata])) < 2L) {
    return(NULL)
  }
  by_call <- paste(unique(c(strata, by_vars)), collapse = ", ")
  if (length(unique(c(strata, by_vars))) > 1L) by_call <- paste0("c(", by_call, ")")
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

  effort <- tryCatch(
    estimate_effort(design, by = dplyr::all_of(strata)), # nolint: object_usage_linter
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
  E <- stats::setNames(effort$estimates$estimate, e_key)
  se_E <- stats::setNames(effort$estimates$se, e_key)

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
  unseen <- setdiff(names(E), names(D))
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
#' @return `estimates` with `se`, `ci_lower`, `ci_upper` updated.
#' @keywords internal
#' @noRd
rate_pooling_add_effort_var <- function(estimates, pool, by_vars) {
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
  estimates$ci_lower <- est - (est - estimates$ci_lower) * scale
  estimates$ci_upper <- est + (estimates$ci_upper - est) * scale
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
