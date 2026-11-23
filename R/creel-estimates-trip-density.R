# Internal: effort-family method allowlist ----

# `estimate_effort()` returns "total" on ground, bus-route, ice and camera
# designs, "total-sections" when add_sections() was used, and "aerial_total"
# for pooled aerial effort; estimate_effort_aerial_glmm() returns
# "aerial_glmm_total". All are angler-hours of effort (GH #582). Everything
# else in the package -- CPUE, HPUE, RPUE, the product totals, the bus-route
# HT totals -- is a different quantity. Consumers check against this set so a
# rate or a fish-valued total cannot be divided by hours or acres and
# relabelled as effort.
effort_family_methods <- function() {
  c("total", "total-sections", "aerial_total", "aerial_glmm_total")
}

# Variance of sum(w * E) over the effort rows a trips total sums (GH #582).
#
# Rows of ground effort are independent strata, so this is sum(w^2 * se^2), the
# familiar sum in quadrature. Aerial rows are not independent: v and a are
# single estimates scaling every row, so each row's SE carries a component
# `E_h * se / value` that is perfectly correlated across rows (GH #135, #150).
# Each such component c contributes (sum(w * c))^2 rather than sum(w^2 * c^2);
# the remainder of each row's variance stays independent. The GLMM path
# reports the whole covariance, model correlation included, as `strata_vcov`,
# and that is used as is. Computed from vectors so independent rows never
# allocate a k x k matrix.
effort_rows_weighted_var <- function(effort, se_E, w) {
  k <- length(se_E)
  vc <- effort$strata_vcov
  if (!is.null(vc)) {
    if (!identical(dim(vc), c(k, k))) {
      cli::cli_abort(
        "Internal error: {.code strata_vcov} is not {k} x {k}.",
        .internal = TRUE
      )
    }
    return(drop(crossprod(w, vc %*% w)))
  }
  comps <- effort$se_components
  shared <- comps[intersect(c("visibility", "angler_ratio"), names(comps))]
  shared <- Filter(function(x) length(x) == k, shared)
  own_var <- se_E^2 - Reduce(`+`, lapply(shared, function(x) x^2), 0)
  sum(w^2 * own_var) + sum(vapply(shared, function(x) sum(w * x)^2, numeric(1)))
}

# Shared guard for the composable estimators that consume an effort object.
#
# This checks the *quantity* (is it effort at all?), never the actor. Effort
# reaches here as angler-hours, party-hours, or unknown, and all three are
# legitimate: the consumers carry the actor through to their own unit rather
# than requiring one. The message used to claim it enforced angler-hours, which
# it never did -- see finding 12c.
require_effort_estimates <- function(effort, arg = "effort", call = rlang::caller_env()) {
  if (!inherits(effort, "creel_estimates")) {
    cli::cli_abort(
      "{.arg {arg}} must be a {.cls creel_estimates} object from {.fn estimate_effort}.",
      call = call
    )
  }

  method <- effort$method %||% NA_character_
  if (!method %in% effort_family_methods()) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must hold effort, but carries {.val {method}}.",
        "x" = paste(
          "Only effort from {.fn estimate_effort} or {.fn estimate_effort_aerial_glmm} qualifies",
          "({.val {effort_family_methods()}})."
        ),
        "i" = "Dividing a rate or a fish-valued total here would relabel it as effort."
      ),
      call = call
    )
  }

  invisible(effort)
}

#' Estimate angler trips from extrapolated effort
#'
#' @description
#' Computes estimated trips by dividing extrapolated effort by the mean trip
#' length per stratum, with Delta Method variance propagation (Powell 2007).
#' This is a composable estimator: the effort object must be pre-computed via
#' \code{\link{estimate_effort}} before calling this function.
#'
#' The divisor is hours per trip, so the result comes back in whichever actor
#' the effort was measured in: angler-hours give angler trips, party-hours give
#' party trips. The returned \code{unit} field records which, and is \code{NA}
#' when the effort's own unit was unknown. The method string is
#' \code{"angler-trips"} in every case and so is not a guide to the actor.
#'
#' @section Trip length:
#' Trips are effort divided by mean trip length (Pollock et al. 1994, p. 175).
#' That divisor has to be the mean length of \emph{completed} trips, sampled
#' without regard to how long they were, so:
#' \itemize{
#'   \item Only complete trips (\code{trip_status == "complete"}) enter it. An
#'     incomplete trip records the time fished so far, not a trip length.
#'   \item Roving designs (\code{interview_type = "roving"}) are refused. A
#'     roving clerk meets anglers in proportion to how long they fish
#'     (length-of-stay bias; Pollock et al. 1994, sec. 11.4; Robson 1961), and
#'     the time fished at interview cannot be inverted into a trip count
#'     (Hoenig et al. 1997). Pollock et al. (1994, p. 175): "an unbiased
#'     estimate of mean trip length cannot be obtained from a roving survey
#'     ... and must be achieved by other means."
#'   \item Angler-hours are divided by hours per angler trip: every angler in
#'     a party of \eqn{n} makes one trip, so each trip length is weighted by
#'     its party size. Party-hours are divided by hours per party trip,
#'     unweighted. When the effort's unit is unknown and party sizes vary, the
#'     two divisors differ and nothing says which applies, so the call is
#'     refused; give \code{add_counts()} a period length to make the effort
#'     angler-hours.
#'   \item Bus-route and ice interviews are weighted by their inclusion
#'     weights (\code{.expansion / .pi_i}; Jones and Pollock 2012), as their
#'     effort is.
#' }
#' The mean is a ratio estimator on the interview survey design, so
#' interviews on the same day are not treated as independent, and the
#' confidence interval uses that design's degrees of freedom (days less
#' strata) rather than the number of interviews.
#'
#' @param effort A \code{creel_estimates} object returned by
#'   \code{\link{estimate_effort}}. Must have a numeric \code{estimate} column
#'   and a \code{se} column in \code{effort$estimates}.
#' @param design A \code{creel_design} object with interview data containing
#'   a trip duration column (set via \code{add_interviews(trip_duration = ...)}).
#'   Used to compute per-stratum mean trip length.
#' @param conf_level Confidence level for confidence intervals. Default 0.95.
#' @param ... Reserved for future arguments.
#'
#' @return A \code{creel_estimates} object with \code{method = "angler-trips"}
#'   and \code{variance_method = "delta"}. The \code{estimates} tibble contains:
#'   \describe{
#'     \item{by_vars columns}{Any grouping columns from the effort object (if
#'       grouped).}
#'     \item{estimate}{Estimated trips per stratum (effort / mean trip
#'       length), in the actor the effort was measured in.}
#'     \item{se}{Standard error via Delta Method variance propagation.}
#'     \item{ci_lower}{Lower confidence interval bound.}
#'     \item{ci_upper}{Upper confidence interval bound.}
#'     \item{n}{Number of interviews contributing to mean trip length per
#'       stratum.}
#'   }
#'   For grouped effort, an \code{.overall} row is appended with
#'   \code{estimate = sum(stratum trips)}. Its \code{se} adds the stratum
#'   variances in quadrature when the effort rows are independent (ground
#'   counts). Aerial effort rows share the visibility correction and
#'   angler-to-people ratio, and GLMM rows also share model coefficients, so
#'   for those the covariance of the effort rows is used and each shared term
#'   enters the total once.
#'
#'   Grouping columns that are not character (numeric, factor, \code{Date})
#'   are returned as character, so the \code{.overall} marker can share them.
#'
#' @references
#'   Hoenig, J. M., Jones, C. M., Pollock, K. H., Robson, D. S., and Wade,
#'   D. L. (1997). Calculation of catch rate and total catch in roving surveys
#'   of anglers. \emph{Biometrics}, 53(1), 306-317.
#'
#'   Jones, C. M., and Pollock, K. H. (2012). Recreational angler survey
#'   methods: estimation of effort, harvest, and released catch. In A. V. Zale,
#'   D. L. Parrish, and T. M. Sutton (eds.), \emph{Fisheries Techniques} (3rd
#'   ed., pp. 883-919). American Fisheries Society.
#'
#'   Pollock, K. H., Jones, C. M., and Brown, T. L. (1994). \emph{Angler
#'   Survey Methods and Their Applications in Fisheries Management}. American
#'   Fisheries Society Special Publication 25. Chapter 11.
#'
#'   Powell, L. A. (2007). Approximating variance of demographic
#'   parameters using the delta method. \emph{Journal of Wildlife Management},
#'   71(3), 1018-1024.
#'
#'   Robson, D. S. (1961). On the statistical theory of a roving creel census
#'   of fishermen. \emph{Biometrics}, 17(3), 415-437.
#'
#' @examples
#' data(example_calendar)
#' data(example_counts)
#' data(example_interviews)
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, trip_duration = trip_duration
#' )
#' effort <- estimate_effort(design)
#' estimate_angler_trips(effort, design)
#'
#' @seealso \code{\link{estimate_effort}}, \code{\link{estimate_exploitation_rate}}
#'
#' @export
estimate_angler_trips <- function(effort, design, conf_level = 0.95, ...) {
  # --- input guards ---
  require_effort_estimates(effort)

  # GLMM aerial effort can be one average day (`target = "mean_day"`). Trips
  # from it would be trips per average day, and the grouped `.overall` row
  # would add the daily values of different day types as if they were totals
  # over disjoint days, which is neither a daily nor a season figure. The
  # result also carries no target label, so a daily figure would read as a
  # total (GH #582).
  if (identical(effort$effort_target, "mean_day")) {
    cli::cli_abort(
      c(
        "{.arg effort} is effort on one average day ({.code target = \"mean_day\"}).",
        "x" = "Trips are a total over days, and summing daily values across groups has no meaning.",
        "i" = "Estimate effort with {.code target = \"sampled_days\"} instead."
      ),
      class = "creel_error_invalid_input"
    )
  }

  if (is.null(design$trip_duration_col)) {
    cli::cli_abort(c(
      "{.arg design} has no {.code trip_duration_col}.",
      "i" = "Set it via {.code add_interviews(trip_duration = <col>)}."
    ))
  }

  dur_col <- design$trip_duration_col

  # Check that by_vars columns exist in interviews
  if (!is.null(effort$by_vars)) {
    missing_bv <- setdiff(effort$by_vars, names(design$interviews))
    if (length(missing_bv) > 0) {
      cli::cli_abort(c(
        "Grouping column(s) from {.arg effort} are absent from {.code design$interviews}.",
        "x" = "Missing: {.val {missing_bv}}"
      ))
    }
  }

  tl <- trip_length_estimates(design, effort)
  df_L <- tl$df
  min_n_se <- 2L

  # --- ungrouped case ---
  if (is.null(effort$by_vars)) {
    L <- tl$table$mean_L
    se_L <- tl$table$se_L
    n_int <- tl$table$n_interviews
    n_days <- tl$table$n_days
    if (n_days < min_n_se) {
      creel_warn(c(
        "!" = "Complete trips come from {n_days} day{?s} ({n_int} trip{?s}); \\
               SE of mean trip length is undefined.",
        "i" = "SE and CI will be {.val NA}. Point estimate (trips) is still returned."
      ),
      class = c("creel_warning_trip_length_se_undefined", "creel_warning")
      )
      se_L <- NA_real_
    }

    if (L <= 0) {
      cli::cli_abort(
        "Mean trip length is zero or negative; check {.code {dur_col}} values."
      )
    }

    E <- effort$estimates$estimate
    se_E <- effort$estimates$se

    var_trips <- se_E^2 / L^2 + E^2 * se_L^2 / L^4
    se_trips <- sqrt(var_trips)
    trips <- E / L
    # Design df of the interview survey (days less strata), not the number of
    # interviews: interviews on one day are not independent (GH #689).
    z <- stats::qt(1 - (1 - conf_level) / 2, df = max(1, df_L))

    estimates_df <- tibble::tibble(
      estimate = trips,
      se = se_trips,
      ci_lower = trips - z * se_trips,
      ci_upper = trips + z * se_trips,
      n = n_int
    )

    return( # nolint: object_usage_linter
      new_creel_estimates( # nolint: object_usage_linter
        estimates = estimates_df,
        method = "angler-trips",
        variance_method = "delta",
        design = NULL,
        conf_level = conf_level,
        by_vars = NULL,
        # Carried, not dropped: trips over the sampled days are not a season
        # total, and the label is what says so (GH #689).
        effort_target = effort$effort_target,
        # Inherited, not fixed: trips = E / L divides by hours per trip, so the
        # count is in whichever actor E was measured in. The method name says
        # "angler-trips" for every caller; the unit must not.
        unit = trips_unit(effort$unit) # nolint: object_usage_linter
      )
    )
  }

  # --- grouped case ---
  summary_df <- tl$table
  summary_df$.tl_row <- seq_len(nrow(summary_df))

  # A group whose complete trips all fall on one day has no between-day
  # variation to estimate its trip length's SE from (GH #689).
  singleton <- summary_df$n_days < min_n_se
  if (any(singleton)) {
    singleton_strata <- summary_df[singleton, , drop = FALSE]
    summary_df$se_L[singleton] <- NA_real_
    stratum_labels <- apply(
      singleton_strata[effort$by_vars],
      1,
      paste,
      collapse = " / "
    )
    creel_warn(c(
      "!" = "{nrow(singleton_strata)} group{?s} {?has/have} complete trips on only one day; \\
             SE of mean trip length is undefined.",
      "i" = "SE and CI will be {.val NA} for: {.val {stratum_labels}}. Point estimates are still returned."
    ),
    class = c("creel_warning_single_interview_strata", "creel_warning")
    )
  }

  # Guard against zero mean trip length
  if (any(summary_df$mean_L <= 0, na.rm = TRUE)) {
    cli::cli_abort(
      "Mean trip length is zero or negative in at least one stratum; check {.code {dur_col}} values."
    )
  }

  # Join effort estimates with interview summary
  joined <- dplyr::left_join(effort$estimates, summary_df, by = effort$by_vars)

  # An effort group present among the interviews but with no usable complete
  # trip has no trip length; say so rather than reporting a key mismatch.
  na_strata <- joined[is.na(joined$mean_L), effort$by_vars, drop = FALSE]
  in_interviews <- group_key(na_strata, effort$by_vars) %in% # nolint: object_usage_linter
    group_key(design$interviews, effort$by_vars) # nolint: object_usage_linter
  if (any(in_interviews)) {
    cli::cli_abort(
      c(
        "Some groups have no complete trip with a usable {.code {dur_col}}.",
        "x" = "Groups: {.val {apply(na_strata[in_interviews, , drop = FALSE], 1, paste, collapse = ' / ')}}",
        "i" = "Mean trip length is estimated from complete trips only."
      ),
      class = "creel_error_missing_data"
    )
  }
  if (nrow(na_strata) > 0) {
    cli::cli_abort(c(
      "Stratum key mismatch: some effort rows did not match any interview group.",
      "x" = "Unmatched strata: {.val {apply(na_strata, 1, paste, collapse = ' / ')}}"
    ))
  }

  # Row-wise Delta Method
  E <- joined$estimate
  se_E <- joined$se
  L <- joined$mean_L
  se_L_vec <- joined$se_L

  var_trips <- se_E^2 / L^2 + E^2 * se_L_vec^2 / L^4
  trips <- E / L
  se_trips <- sqrt(var_trips)

  # One design df for every row: the interview survey's days less strata
  # (GH #689). The per-row interview count overstated it.
  z_crit <- stats::qt(1 - (1 - conf_level) / 2, df = max(1, df_L))

  # Per-stratum rows
  stratum_rows <- tibble::tibble(
    dplyr::select(joined, dplyr::all_of(effort$by_vars)),
    estimate = trips,
    se = se_trips,
    ci_lower = trips - z_crit * se_trips,
    ci_upper = trips + z_crit * se_trips,
    n = joined$n_interviews
  )
  # The `.overall` marker is text, so a numeric, logical, factor or Date
  # grouping column is reported as text; binding the marker into it otherwise
  # fails (GH #689).
  for (v in effort$by_vars) {
    if (!is.character(stratum_rows[[v]])) {
      stratum_rows[[v]] <- as.character(stratum_rows[[v]])
    }
  }

  # .overall row: additive aggregate. The effort part of its variance is
  # g' Sigma_E g with g = 1 / L, so a multiplier shared by every row (aerial v
  # and a) enters once on the total rather than once per row in quadrature
  # (GH #582). The trip-length part is treated as independent per stratum.
  # Ground effort has a diagonal Sigma_E and reduces to sum(var_trips).
  overall_est <- sum(trips)
  # The trip-length part uses the covariance of the group means: groups that
  # are not strata share interview days, so their means move together
  # (GH #689). A group whose SE is unknown makes the total's unknown too.
  idx <- joined$.tl_row
  vc_L <- tl$vcov_L[idx, idx, drop = FALSE]
  unknown_L <- is.na(se_L_vec)
  vc_L[unknown_L, ] <- NA_real_
  vc_L[, unknown_L] <- NA_real_
  g_L <- E / L^2
  overall_var <- effort_rows_weighted_var(effort, se_E, 1 / L) + drop(crossprod(g_L, vc_L %*% g_L))
  overall_se <- sqrt(overall_var)

  overall_vals <- stats::setNames(
    rep(".overall", length(effort$by_vars)),
    effort$by_vars
  )
  overall_row <- tibble::as_tibble(as.list(overall_vals))
  overall_row$estimate <- overall_est
  overall_row$se <- overall_se
  overall_row$ci_lower <- overall_est - z_crit * overall_se
  overall_row$ci_upper <- overall_est + z_crit * overall_se
  overall_row$n <- sum(joined$n_interviews)

  estimates_df <- dplyr::bind_rows(stratum_rows, overall_row)

  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "angler-trips",
    variance_method = "delta",
    design = NULL,
    conf_level = conf_level,
    by_vars = effort$by_vars,
    effort_target = effort$effort_target,
    # Same inheritance as the ungrouped branch above.
    unit = trips_unit(effort$unit) # nolint: object_usage_linter
  )
}

# Mean trip length, its SE and design df, from the interview survey (GH #689).
#
# Trips are effort / mean trip length (Pollock et al. 1994, p. 175), and that
# divisor must be a mean of COMPLETED trip lengths drawn without regard to
# length:
#
# - Incomplete trips record the time fished so far, not a trip length, so only
#   complete trips enter.
# - A roving clerk meets an angler in proportion to the length of the trip
#   (Pollock et al. 1994, sec. 11.4; Robson 1961), and the reciprocal of time
#   fished at interview has infinite expectation (Hoenig et al. 1997, eq. 2.5).
#   No mean of roving lengths is unbiased, so roving designs are refused.
# - Angler-hours need hours per ANGLER trip: each angler in a party of n is
#   one trip, so lengths are weighted by party size (the #513 analogue for
#   trip length). Party-hours need hours per party trip, unweighted. When the
#   effort's actor is unknown and party sizes vary, the two differ and nothing
#   says which applies, so the call is refused rather than guessed.
# - Bus-route and ice interviews carry Horvitz-Thompson weights
#   (.expansion / .pi_i, Jones & Pollock 2012 eq. 19.4), as their effort does.
#
# L = sum(w a L_i) / sum(w a) over complete trips, estimated with svyratio()
# on the interview survey so interviews are clustered within days. The df is
# that design's (days less strata), not the interview count.
trip_length_estimates <- function(design, effort, call = rlang::caller_env()) {
  iv <- design$interviews
  dur_col <- design$trip_duration_col
  by_vars <- effort$by_vars

  if (identical(design$interview_type, "roving")) {
    cli::cli_abort(
      c(
        "Mean trip length cannot be estimated from roving interviews.",
        "x" = paste(
          "A roving clerk meets anglers in proportion to how long they fish,",
          "and an incomplete trip records only the time fished so far",
          "(Pollock et al. 1994, sec. 11.4; Robson 1961)."
        ),
        "i" = paste(
          "Trip length must come from completed trips sampled without regard",
          "to their length, such as access-point interviews.",
          "See {.code ?estimate_angler_trips} for why."
        )
      ),
      class = c("creel_error_roving_trip_length", "creel_error_invalid_input"),
      call = call
    )
  }

  status_col <- design$trip_status_col
  complete <- if (is.null(status_col)) {
    rep(TRUE, nrow(iv))
  } else {
    !is.na(iv[[status_col]]) & iv[[status_col]] == "complete"
  }
  dur <- iv[[dur_col]]
  bad_dur <- complete & (is.na(dur) | dur <= 0)
  if (any(bad_dur)) {
    creel_warn(c(
      "!" = paste0(
        sum(bad_dur),
        " complete trip(s) have non-positive or missing {.code {dur_col}} values."
      ),
      "i" = "These rows are excluded from the mean trip length calculation."
    ),
    class = c("creel_warning_trip_duration_excluded", "creel_warning")
    )
  }
  use <- complete & !bad_dur
  # A bus-route row with nothing counted and nothing interviewed is a site
  # visit with no parties, not a trip: it has no inclusion weight and no
  # length, so it is not part of the trip-length sample.
  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col
  has_site_counts <- !is.null(n_counted_col) && !is.null(n_interviewed_col) &&
    all(c(n_counted_col, n_interviewed_col) %in% names(iv))
  if (has_site_counts) {
    empty_site <- !is.na(iv[[n_counted_col]]) & iv[[n_counted_col]] == 0 &
      !is.na(iv[[n_interviewed_col]]) & iv[[n_interviewed_col]] == 0
    use <- use & !empty_site
  }
  if (!any(use)) {
    cli::cli_abort(
      c(
        "No complete trip has a usable {.code {dur_col}}.",
        "x" = "Mean trip length is estimated from complete trips only.",
        "i" = "Incomplete trips record the time fished so far, not a trip length."
      ),
      class = "creel_error_missing_data",
      call = call
    )
  }

  unit <- effort$unit %||% NA_character_
  n_col <- design$n_anglers_col
  party <- if (!is.null(n_col) && n_col %in% names(iv)) iv[[n_col]] else NULL
  per_angler <- !is.na(unit) && startsWith(unit, "angler")
  # A missing party size is checked before deciding whether sizes vary: an
  # all-missing column has one unique value and would read as constant, so
  # angler-hours would silently be divided by hours per party trip.
  if (per_angler && !is.null(party) && anyNA(party[use])) {
    cli::cli_abort(
      c(
        "{sum(is.na(party[use]))} complete trip{?s} {?has/have} no party size.",
        "x" = "Hours per angler trip weight each trip by its party size.",
        "i" = "Supply the missing {.code {n_col}} values."
      ),
      class = "creel_error_missing_data",
      call = call
    )
  }
  varies <- !is.null(party) && length(unique(party[use])) > 1L
  if (varies && is.na(unit)) {
    cli::cli_abort(
      c(
        "The effort's unit is unknown, and party sizes vary.",
        "x" = paste(
          "Angler-hours are divided by hours per angler trip, party-hours by",
          "hours per party trip, and with varying party sizes the two differ",
          "(Pollock et al. 1994, p. 175)."
        ),
        "i" = paste(
          "Give {.fn add_counts} a period length so the effort is in angler-hours.",
          "See {.code ?estimate_angler_trips} for why."
        )
      ),
      class = c("creel_error_unknown_effort_unit", "creel_error_invalid_input"),
      call = call
    )
  }
  a <- if (per_angler && varies) party else rep(1, nrow(iv))

  w <- rep(1, nrow(iv))
  ht_weighted <- isTRUE(design$design_type %in% c("bus_route", "ice")) &&
    all(c(".expansion", ".pi_i") %in% names(iv))
  if (ht_weighted) {
    w <- iv$.expansion / iv$.pi_i
    if (anyNA(w[use])) {
      cli::cli_abort(
        c(
          "A complete trip has no inclusion weight.",
          "x" = "Bus-route trip lengths are weighted by {.code .expansion / .pi_i}."
        ),
        class = "creel_error_missing_data",
        call = call
      )
    }
  }

  svy <- design$interview_survey
  aligned <- !is.null(svy) && nrow(svy$variables) == nrow(iv) &&
    identical(svy$variables[[dur_col]], iv[[dur_col]])
  if (!aligned) {
    cli::cli_abort(
      "Internal error: the interview survey does not match the interviews.",
      .internal = TRUE
    )
  }
  svy$variables$.tl_num <- ifelse(use, w * a * dur, 0)
  svy$variables$.tl_den <- ifelse(use, w * a, 0)
  # Indexing keeps the whole design and zeroes the other rows' weights, so the
  # variance is the domain variance over every interview day. The df is the
  # whole interview design's, as the effort estimators use theirs.
  sub <- svy[use, ]
  df <- as.numeric(survey::degf(svy))

  # Complete trips on one day only: the ratio's linearised residuals sum to
  # zero within that day, so the SE would come out as 0 rather than unknown.
  psu <- interview_psu_col(design, iv) # nolint: object_usage_linter
  day_of <- if (is.null(psu)) seq_len(nrow(iv)) else iv[[psu]]

  if (is.null(by_vars)) {
    r <- survey::svyratio(~.tl_num, ~.tl_den, sub)
    tab <- tibble::tibble(
      mean_L = as.numeric(stats::coef(r)),
      se_L = as.numeric(survey::SE(r)),
      n_interviews = sum(use),
      n_days = length(unique(day_of[use]))
    )
    return(list(table = tab, df = df, vcov_L = NULL))
  }

  # An unknown group keeps its own row, as in estimate_effort(by = ): svyby()
  # drops NA keys unless they are promoted to a level first.
  sub <- promote_na_groups(sub, by_vars) # nolint: object_usage_linter
  r <- survey::svyby(
    ~.tl_num, stats::reformulate(by_vars), sub, survey::svyratio,
    denominator = ~.tl_den, covmat = TRUE
  )
  tab <- tibble::as_tibble(restore_group_types(as.data.frame(r)[by_vars], iv, by_vars)) # nolint: object_usage_linter
  tab$mean_L <- as.numeric(stats::coef(r))
  tab$se_L <- as.numeric(survey::SE(r))
  keys_use <- group_key(iv[use, , drop = FALSE], by_vars) # nolint: object_usage_linter
  tab_keys <- group_key(tab, by_vars) # nolint: object_usage_linter
  n_by_key <- table(keys_use)
  tab$n_interviews <- as.integer(n_by_key[match(tab_keys, names(n_by_key))])
  days_by_key <- tapply(day_of[use], keys_use, function(x) length(unique(x)))
  tab$n_days <- as.integer(days_by_key[match(tab_keys, names(days_by_key))])
  # vcov.svyby() cannot shape a single group's variance into a matrix.
  vcov_L <- if (nrow(tab) == 1L) {
    matrix(tab$se_L^2)
  } else {
    unname(as.matrix(stats::vcov(r)))
  }
  list(table = tab, df = df, vcov_L = vcov_L)
}


#' Compute effort density as effort per acre
#'
#' @description
#' Divides all effort estimate columns in a pre-computed \code{creel_estimates}
#' object by a surface area scalar (\code{acres}). Standard error propagates
#' linearly because \code{acres} is a constant (not a random variable), so no
#' Delta Method is needed: \code{se_per_acre = se_effort / acres}.
#'
#' \code{acres} is a constant divisor, so the result is whatever the effort was,
#' per acre: the returned \code{unit} field composes the effort's own unit
#' (\code{"angler-hours/acre"}, \code{"party-hours/acre"}), and stays \code{NA}
#' when the effort's unit was unknown.
#'
#' This is a composable estimator: the effort object must be pre-computed via
#' \code{\link{estimate_effort}} before calling this function.
#'
#' @param effort A \code{creel_estimates} object returned by
#'   \code{\link{estimate_effort}}. Must contain \code{estimate}, \code{se},
#'   \code{ci_lower}, and \code{ci_upper} columns in \code{effort$estimates}.
#' @param acres A single positive numeric scalar giving the total lake surface
#'   area in acres. All effort estimate columns are divided by this value.
#' @param ... Reserved for future arguments.
#'
#' @return A \code{creel_estimates} object with \code{method = "effort-per-acre"}.
#'   The \code{estimates} tibble has the same rows as the input but with
#'   \code{estimate}, \code{se}, \code{ci_lower}, \code{ci_upper} (and
#'   \code{se_between}, \code{se_within} when present in the input) all divided
#'   by \code{acres}. Grouping columns (\code{by_vars}) and \code{n} are
#'   carried through unchanged. \code{variance_method} and \code{conf_level}
#'   are inherited from the input effort object.
#'
#' @examples
#' data(example_calendar)
#' data(example_counts)
#' data(example_interviews)
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' effort <- estimate_effort(design)
#' # Surface area of the water body, in acres.
#' estimate_effort_per_acre(effort, acres = 120)
#'
#' @seealso \code{\link{estimate_effort}}, \code{\link{estimate_angler_trips}}
#'
#' @export
estimate_effort_per_acre <- function(effort, acres, ...) {
  # --- input guards ---
  require_effort_estimates(effort)

  if (!is.numeric(acres) || length(acres) != 1 || acres <= 0) {
    cli::cli_abort(
      "{.arg acres} must be a single positive number."
    )
  }

  # --- scale columns ---
  est_df <- effort$estimates

  est_df$estimate <- est_df$estimate / acres
  est_df$se <- est_df$se / acres
  est_df$ci_lower <- est_df$ci_lower / acres
  est_df$ci_upper <- est_df$ci_upper / acres

  if ("se_between" %in% names(est_df)) {
    est_df$se_between <- est_df$se_between / acres
  }
  if ("se_within" %in% names(est_df)) {
    est_df$se_within <- est_df$se_within / acres
  }

  # Derived rather than looked up: acres is a constant divisor, so this is
  # whatever the effort was, per acre. Composing the string keeps
  # party-hours/acre distinguishable from angler-hours/acre, which a hardcoded
  # "angler-hours/acre" would silently conflate. Unknown in, unknown out --
  # appending "/acre" to NA would invent a dimension.
  effort_unit <- effort$unit %||% NA_character_
  density_unit <- if (is.na(effort_unit)) {
    NA_character_
  } else {
    paste0(effort_unit, "/acre")
  }

  # --- return ---
  new_creel_estimates( # nolint: object_usage_linter
    estimates = est_df,
    method = "effort-per-acre",
    variance_method = effort$variance_method,
    design = NULL,
    conf_level = effort$conf_level,
    by_vars = effort$by_vars,
    unit = density_unit
  )
}
