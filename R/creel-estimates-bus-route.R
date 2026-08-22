# Bus-route effort estimation ----
# Implements Jones & Pollock (2012) Eq. 19.4: E_hat = sum(e_i / pi_i)
# where e_i = raw_effort * expansion (enumeration expansion factor)
# Called by estimate_effort() when design$design_type == "bus_route"

#' Bus-route Horvitz-Thompson effort estimator
#'
#' Internal function implementing Jones & Pollock (2012) Eq. 19.4.
#' Called by estimate_effort() after bus-route dispatch.
#'
#' @param design A creel_design object with bus-route interviews attached
#' @param by_vars NULL or character vector of grouping variable names
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (0-1)
#' @param verbose Logical. If TRUE, prints informational message about estimator
#'
#' @return A creel_estimates object with site_contributions attribute
#'
#' @keywords internal
#' @noRd
estimate_effort_br <- function(
  design,
  by_vars,
  variance_method,
  conf_level,
  verbose,
  effort_target = "sampled_days",
  call = rlang::caller_env()
) {
  # nolint: object_usage_linter
  # Retrieve interview data (contains .pi_i and .expansion from add_interviews())
  interviews <- design$interviews

  # Defensive check: .expansion column must exist
  if (!".expansion" %in% names(interviews)) {
    cli::cli_abort(
      c(
        "Bus-route effort estimation requires .expansion column.",
        "x" = ".expansion not found in interview data.",
        "i" = paste0(
          "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
        )
      ),
      call = call
    )
  }

  # Defensive check: .pi_i column must exist
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(
      c(
        "Bus-route effort estimation requires .pi_i column.",
        "x" = ".pi_i not found in interview data.",
        "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
      ),
      call = call
    )
  }

  # Check for missing .pi_i values — hard error listing site+circuit combinations
  if (any(is.na(interviews$.pi_i))) {
    bad_rows <- interviews[is.na(interviews$.pi_i), ]
    site_col <- design$bus_route$site_col
    circuit_col <- design$bus_route$circuit_col
    combos <- unique(bad_rows[c(site_col, circuit_col)])
    n_combos <- nrow(combos) # nolint: object_usage_linter
    combo_strs <- apply(combos, 1, function(r) {
      paste0(site_col, "=", r[[site_col]], ", ", circuit_col, "=", r[[circuit_col]])
    })
    msg_parts <- stats::setNames(combo_strs, rep("*", length(combo_strs)))
    cli::cli_abort(
      c(
        "Missing inclusion probability (.pi_i) for {n_combos} site+circuit combination{?s}:",
        msg_parts,
        "x" = "All interview site+circuit combinations must appear in the sampling frame.",
        "i" = "Check that interview data site and circuit values match sampling frame."
      ),
      call = call
    )
  }

  # Use angler-effort (duration x n_anglers), not the raw per-party trip duration.
  # e_i must be angler-hours: the reported total is labelled angler-hours, and CPUE on
  # the same design is fish per angler-hour, so a party-hours e_i both understates the
  # total by the mean party size and mixes denominators in any E x CPUE product.
  # Every other rate estimator reads angler_effort_col for this reason. When
  # add_interviews() was given no n_anglers, .angler_effort equals the raw effort and
  # this is a no-op -- add_interviews() already warns in that case.
  effort_col <- design$angler_effort_col

  # Compute enumeration-expanded effort per interview row (Jones & Pollock Eq. 19.4)
  # NA expansion with n_counted=0, n_interviewed=0: treat e_i as 0 (zero-effort site)
  interviews$.e_i <- interviews[[effort_col]] * interviews$.expansion

  # Replace NA .e_i where n_counted=0 AND n_interviewed=0 with 0
  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col
  if (!is.null(n_counted_col) && !is.null(n_interviewed_col)) {
    zero_effort_mask <- !is.na(interviews[[n_counted_col]]) &
      interviews[[n_counted_col]] == 0 &
      !is.na(interviews[[n_interviewed_col]]) &
      interviews[[n_interviewed_col]] == 0
    interviews$.e_i[zero_effort_mask] <- 0
  }

  # Compute e_i / pi_i (Eq. 19.4 site contribution)
  interviews$.contribution <- interviews$.e_i / interviews$.pi_i

  # Build per-site attribution table for attribute storage
  # For ice designs the synthetic site/circuit columns are not in interviews — use row index
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col
  avail_cols <- intersect(c(site_col, circuit_col), names(interviews))
  site_table_cols <- c(avail_cols, ".e_i", ".pi_i", ".contribution")
  site_table <- interviews[site_table_cols]
  names(site_table)[names(site_table) == ".e_i"] <- "e_i"
  names(site_table)[names(site_table) == ".pi_i"] <- "pi_i"
  names(site_table)[names(site_table) == ".contribution"] <- "e_i_over_pi_i"

  # Compute the HT estimate: E_hat = sum(e_i / pi_i)
  if (is.null(by_vars)) {
    # Ungrouped: single total
    total_estimate <- sum(interviews$.contribution, na.rm = TRUE) # nolint: object_usage_linter
    n <- nrow(interviews) # nolint: object_usage_linter

    # Variance via survey package using svytotal on .contribution column
    strata_cols <- design$strata_cols
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    svy_br <- build_interview_survey(interviews, strata = strata_formula) # nolint: object_usage_linter
    svy_br <- get_variance_design(svy_br, variance_method) # nolint: object_usage_linter
    svy_result <- suppressWarnings(survey::svytotal(~.contribution, svy_br))
    se <- as.numeric(survey::SE(svy_result)) # nolint: object_usage_linter
    ci <- confint(svy_result, level = conf_level)
    # Effort is bounded below by zero; the symmetric Wald bound is not.
    ci_lower <- pmax(0, ci[1, 1]) # nolint: object_usage_linter
    ci_upper <- ci[1, 2] # nolint: object_usage_linter

    estimates_df <- tibble::tibble(
      estimate = total_estimate,
      se = se,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      n = n
    )

    result <- new_creel_estimates( # nolint: object_usage_linter
      # nolint: object_usage_linter
      estimates = estimates_df,
      method = "total",
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = NULL,
      effort_target = effort_target,
      # The HT total sums interview contributions e_i / pi_i, so its unit comes
      # from the interview side, not design$effort_unit (the counts side).
      # Labelling it from the counts would restate finding 2 in machine-readable
      # form.
      unit = interview_effort_unit(design) # nolint: object_usage_linter
    )
    attr(result, "site_contributions") <- site_table
    result
  } else {
    # Grouped estimation (e.g., by = "circuit")
    # For by="circuit": compute per-group total, then add proportion of overall
    by_formula <- stats::reformulate(by_vars)
    strata_cols <- design$strata_cols
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    svy_br <- build_interview_survey(interviews, strata = strata_formula) # nolint: object_usage_linter
    svy_br <- get_variance_design(svy_br, variance_method) # nolint: object_usage_linter

    svy_result <- suppressWarnings(survey::svyby(
      formula = ~.contribution,
      by = by_formula,
      design = svy_br,
      FUN = survey::svytotal,
      vartype = c("se", "ci"),
      ci.level = conf_level,
      keep.names = FALSE
    ))

    estimate <- svy_result[[".contribution"]]
    se <- svy_result[["se"]]
    # Effort is bounded below by zero; the symmetric Wald bound is not.
    ci_lower <- pmax(0, svy_result[["ci_l"]])
    ci_upper <- svy_result[["ci_u"]]

    # Compute proportion of overall total for each group
    overall_total <- sum(interviews$.contribution, na.rm = TRUE)
    proportion <- estimate / overall_total

    # Per-group sample sizes
    group_data_for_n <- interviews[by_vars]
    group_data_for_n$.count <- 1
    n_by_group <- stats::aggregate(.count ~ ., data = group_data_for_n, FUN = sum)
    names(n_by_group)[names(n_by_group) == ".count"] <- "n"

    estimates_df <- svy_result[by_vars]
    estimates_df$estimate <- estimate
    estimates_df$se <- se
    estimates_df$ci_lower <- ci_lower
    estimates_df$ci_upper <- ci_upper
    estimates_df$proportion <- proportion
    estimates_df <- merge(estimates_df, n_by_group, by = by_vars, all.x = TRUE, sort = FALSE)
    estimates_df <- tibble::as_tibble(estimates_df)

    # Column order: group cols, estimate cols, proportion, n
    col_order <- c(by_vars, "estimate", "se", "ci_lower", "ci_upper", "proportion", "n")
    estimates_df <- estimates_df[col_order]

    result <- new_creel_estimates( # nolint: object_usage_linter
      # nolint: object_usage_linter
      estimates = estimates_df,
      method = "total",
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = by_vars,
      effort_target = effort_target,
      # Same interview-side provenance as the ungrouped branch above.
      unit = interview_effort_unit(design) # nolint: object_usage_linter
    )
    attr(result, "site_contributions") <- site_table
    result
  }
}

# Bus-route harvest estimation ----
# Implements Jones & Pollock (2012) Eq. 19.5: H_hat = sum(h_i / pi_i)
# where h_i = harvest_col * .expansion (enumeration expansion factor)
# Called by estimate_harvest_rate() when design$design_type == "bus_route"

#' Bus-route Horvitz-Thompson harvest estimator
#'
#' Internal function implementing Jones & Pollock (2012) Eq. 19.5.
#' Called by estimate_harvest_rate() after bus-route dispatch, and by
#' estimate_release_br() with a design whose harvest_col names the joined
#' release count.
#'
#' @param design A creel_design object with bus-route interviews attached
#' @param by_vars NULL or character vector of grouping variable names
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (0-1)
#' @param verbose Logical. If TRUE, prints informational message about estimator
#' @param use_trips Character: "complete", "incomplete", or "diagnostic"
#' @param truncate_at Numeric minimum trip duration (hours) below which
#'   incomplete trips are discarded before mean-of-ratios estimation, or NULL
#'   to disable. Ignored on the complete-trip path.
#' @param metric Either "hpue" or "rpue". Selects the reported `method` string
#'   and the noun used in conditions. The estimator is identical either way; the
#'   numerator is whatever column `design$harvest_col` names.
#'
#' @return A creel_estimates object with site_contributions attribute,
#'   or creel_estimates_diagnostic for use_trips = "diagnostic"
#'
#' @keywords internal
#' @noRd
estimate_harvest_br <- function(
  # nolint: object_usage_linter
  design,
  by_vars,
  variance_method,
  conf_level,
  verbose,
  use_trips,
  truncate_at = 0.5,
  metric = c("hpue", "rpue", "cpue"),
  call = rlang::caller_env()
) {
  metric <- match.arg(metric)
  metric_label <- toupper(metric) # nolint: object_usage_linter
  if (verbose) {
    cli::cli_inform(c(
      "i" = if (identical(use_trips, "incomplete")) {
        "Using bus-route {metric_label}: truncated mean of ratios (Hoenig et al. 1997)"
      } else {
        "Using bus-route {metric_label}: ratio of HT totals \\
         (Jones & Pollock 2012, Eq. 19.5 / Eq. 19.4)"
      }
    ))
  }

  interviews <- design$interviews

  # Defensive check: .expansion column must exist
  if (!".expansion" %in% names(interviews)) {
    msg <- paste0(
      "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
    )
    cli::cli_abort(
      c(
        "Bus-route harvest estimation requires .expansion column.",
        "x" = ".expansion not found in interview data.",
        "i" = msg
      ),
      call = call
    )
  }

  # Defensive check: .pi_i column must exist
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(
      c(
        "Bus-route harvest estimation requires .pi_i column.",
        "x" = ".pi_i not found in interview data.",
        "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
      ),
      call = call
    )
  }

  # Check for missing .pi_i values — hard error listing site+circuit combinations
  if (any(is.na(interviews$.pi_i))) {
    bad_rows <- interviews[is.na(interviews$.pi_i), ]
    site_col <- design$bus_route$site_col
    circuit_col <- design$bus_route$circuit_col
    combos <- unique(bad_rows[c(site_col, circuit_col)])
    n_combos <- nrow(combos) # nolint: object_usage_linter
    combo_strs <- apply(combos, 1, function(r) {
      paste0(site_col, "=", r[[site_col]], ", ", circuit_col, "=", r[[circuit_col]])
    })
    msg_parts <- stats::setNames(combo_strs, rep("*", length(combo_strs)))
    cli::cli_abort(
      c(
        "Missing .pi_i for {n_combos} site+circuit combination{?s}:",
        msg_parts,
        "x" = "All interview site+circuit combinations must appear in the sampling frame.",
        "i" = "Check that interview data site and circuit values match sampling frame."
      ),
      call = call
    )
  }

  # Diagnostic mode: run both complete and incomplete paths, return diagnostic
  if (use_trips == "diagnostic") {
    # Both slots are now fish per angler-hour, so the gap between them is
    # attributable to trip status rather than to a change of physical quantity
    # (GH #108). They remain different estimators -- ratio of HT totals for
    # complete trips, truncated mean of ratios for incomplete ones -- because
    # each is the estimator its trip type supports.
    br_require_trip_status(design, interviews, call)
    complete_result <- estimate_harvest_br(
      design,
      by_vars,
      variance_method,
      conf_level,
      verbose = FALSE,
      use_trips = "complete",
      truncate_at = truncate_at,
      metric = metric,
      call = call
    )
    incomplete_result <- suppressWarnings(estimate_harvest_br(
      design,
      by_vars,
      variance_method,
      conf_level,
      verbose = FALSE,
      use_trips = "incomplete",
      truncate_at = truncate_at,
      metric = metric,
      call = call
    ))
    result <- list(complete = complete_result, incomplete = incomplete_result)
    class(result) <- c("creel_estimates_diagnostic", "list")
    return(result)
  }

  harvest_col <- design$harvest_col
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col
  trip_status_col <- design$trip_status_col
  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col

  # Apply use_trips filtering
  if (use_trips == "complete" && !is.null(trip_status_col)) {
    is_complete <- tolower(interviews[[trip_status_col]]) == "complete"
    interviews <- br_abort_if_no_complete(
      interviews[is_complete, , drop = FALSE],
      paste(toupper(metric), "estimation"),
      call = call
    )
  } else if (use_trips == "incomplete") {
    if (!is.null(trip_status_col)) {
      is_incomplete <- tolower(interviews[[trip_status_col]]) == "incomplete"
      interviews <- interviews[is_incomplete, , drop = FALSE]
    }
    return(br_incomplete_harvest_rate(
      interviews,
      by_vars,
      variance_method,
      conf_level,
      design,
      truncate_at,
      metric = metric,
      call = call
    ))
  }

  # Complete trips path: Eq. 19.5 h_i = harvest_col * .expansion
  interviews$.h_i <- interviews[[harvest_col]] * interviews$.expansion

  # Zero-effort sites (n_counted=0, n_interviewed=0): set .h_i to 0
  if (!is.null(n_counted_col) && !is.null(n_interviewed_col)) {
    zero_mask <- !is.na(interviews[[n_counted_col]]) &
      interviews[[n_counted_col]] == 0 &
      !is.na(interviews[[n_interviewed_col]]) &
      interviews[[n_interviewed_col]] == 0
    interviews$.h_i[zero_mask] <- 0
  }

  # Compute h_i / pi_i (Eq. 19.5 site contribution)
  interviews$.contribution <- interviews$.h_i / interviews$.pi_i

  # Denominator: the same HT effort total that estimate_effort() reports, built
  # the same way -- angler-effort x expansion, then / pi_i. Using angler-effort
  # (not the raw per-party duration) is what makes the ratio fish per
  # angler-hour rather than fish per party-hour (#106).
  angler_effort_col <- design$angler_effort_col
  interviews$.e_i <- interviews[[angler_effort_col]] * interviews$.expansion
  if (!is.null(n_counted_col) && !is.null(n_interviewed_col)) {
    interviews$.e_i[zero_mask] <- 0
  }
  interviews$.e_contribution <- interviews$.e_i / interviews$.pi_i

  # Build per-site attribution table for site_contributions attribute
  # Use intersect() to skip synthetic site/circuit cols absent in ice interviews
  avail_site_cols <- intersect(c(site_col, circuit_col), names(interviews))
  site_table <- interviews[c(
    avail_site_cols, ".h_i", ".e_i", ".pi_i", ".contribution", ".e_contribution"
  )]
  names(site_table)[names(site_table) == ".h_i"] <- "h_i"
  names(site_table)[names(site_table) == ".e_i"] <- "e_i"
  names(site_table)[names(site_table) == ".pi_i"] <- "pi_i"
  names(site_table)[names(site_table) == ".contribution"] <- "h_i_over_pi_i"
  names(site_table)[names(site_table) == ".e_contribution"] <- "e_i_over_pi_i"

  # Interpolated here, not in the message string: cli_abort() glues in the
  # aborting function's environment, where these locals do not exist.
  quantity <- switch(metric, rpue = "release", cpue = "catch", "harvest")
  rate_fn <- paste0("estimate_", quantity, "_rate")

  br_harvest_rate_estimates(
    interviews,
    by_vars,
    variance_method,
    conf_level,
    design,
    site_table,
    method = paste0("ratio-of-means-", metric),
    zero_denom_msg = c(
      paste0("Cannot compute a ", quantity, " rate: estimated total effort is zero."),
      "x" = paste0("{.fn ", rate_fn, "} divides ", quantity, " by the HT effort total."),
      "i" = "Check that {.arg effort} and {.arg n_anglers} were supplied to {.fn add_interviews}."
    )
  )
}

#' Bus-route harvest rate as a ratio of Horvitz-Thompson totals
#'
#' Jones & Pollock (2012) Eq. 19.4 and 19.5 give bus-route effort and harvest as
#' HT *totals*; the framework has no rate estimator. The rate this design
#' supports is the ratio of those two totals, `H_hat / E_hat`, which is the
#' ratio-of-means form -- the same quantity `estimate_harvest_rate()` returns for
#' standard designs, and reported under the same `method` string.
#'
#' The ratio is computed with [survey::svyratio()] rather than by dividing two
#' separately estimated totals. `H_hat` and `E_hat` come from the same
#' interviews and are positively correlated, so Taylor linearisation over both is
#' required; dividing point estimates and propagating the SEs as if independent
#' overstates the standard error.
#'
#' The same machinery serves the incomplete-trip mean-of-ratios path, where the
#' numerator is the weighted sum of per-angler rates and the denominator is the
#' sum of those weights (a Hajek mean). Both are ratio estimators over the same
#' interviews, so both need the same linearisation.
#'
#' @param interviews Interview rows carrying `.contribution` and the denominator
#'   contribution column named by `denom_col`
#' @param by_vars NULL or character vector of grouping variable names
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (0-1)
#' @param design The creel_design object
#' @param site_table Per-site attribution table to attach as an attribute
#' @param method Character method string recorded on the result
#' @param denom_col Name of the denominator contribution column
#' @param zero_denom_msg Character vector passed to [cli::cli_abort()] when the
#'   denominator sums to zero
#'
#' @return A creel_estimates object carrying `method`
#'
#' @keywords internal
#' @noRd
br_harvest_rate_estimates <- function(
  # nolint: object_usage_linter
  interviews,
  by_vars,
  variance_method,
  conf_level,
  design,
  site_table,
  method = "ratio-of-means-hpue",
  denom_col = ".e_contribution",
  zero_denom_msg = c(
    "Cannot compute a harvest rate: estimated total effort is zero.",
    "x" = "{.fn estimate_harvest_rate} divides harvest by the HT effort total.",
    "i" = "Check that {.arg effort} and {.arg n_anglers} were supplied to {.fn add_interviews}."
  )
) {
  strata_cols <- design$strata_cols
  strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
    stats::reformulate(strata_cols)
  } else {
    NULL
  }
  svy_br <- build_interview_survey(interviews, strata = strata_formula) # nolint: object_usage_linter
  svy_br <- get_variance_design(svy_br, variance_method) # nolint: object_usage_linter

  # A zero denominator leaves the rate undefined. Abort rather than return Inf
  # or NaN dressed up as a harvest rate.
  denom_formula <- stats::reformulate(denom_col)
  if (isTRUE(all.equal(sum(interviews[[denom_col]], na.rm = TRUE), 0))) {
    cli::cli_abort(zero_denom_msg)
  }

  if (is.null(by_vars)) {
    svy_result <- suppressWarnings(
      survey::svyratio(~.contribution, denom_formula, svy_br)
    )
    ci <- confint(svy_result, level = conf_level)
    estimates_df <- tibble::tibble(
      estimate = as.numeric(coef(svy_result)),
      se = as.numeric(survey::SE(svy_result)),
      # A catch rate is bounded below by zero; the symmetric Wald bound is not.
      ci_lower = pmax(0, ci[1, 1]),
      ci_upper = ci[1, 2],
      n = nrow(interviews)
    )
    result <- new_creel_estimates( # nolint: object_usage_linter
      # nolint: object_usage_linter
      estimates = estimates_df,
      method = method,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = NULL,
      unit = rate_unit(design) # nolint: object_usage_linter
    )
    attr(result, "site_contributions") <- site_table
    return(result)
  }

  by_formula <- stats::reformulate(by_vars)
  svy_result <- suppressWarnings(survey::svyby(
    formula = ~.contribution,
    by = by_formula,
    design = svy_br,
    FUN = survey::svyratio,
    denominator = denom_formula,
    vartype = c("se", "ci"),
    ci.level = conf_level,
    keep.names = FALSE
  ))

  ratio_col <- paste0(".contribution/", denom_col)
  n_by_group <- stats::aggregate(
    list(n = rep(1L, nrow(interviews))),
    by = interviews[by_vars],
    FUN = sum
  )

  estimates_df <- tibble::as_tibble(svy_result[by_vars])
  estimates_df$estimate <- svy_result[[ratio_col]]
  estimates_df$se <- svy_result[[paste0("se.", ratio_col)]]
  # A catch rate is bounded below by zero; the symmetric Wald bound is not.
  estimates_df$ci_lower <- pmax(0, svy_result[["ci_l"]])
  estimates_df$ci_upper <- svy_result[["ci_u"]]
  estimates_df$n <- n_by_group$n[match(
    do.call(paste, estimates_df[by_vars]),
    do.call(paste, n_by_group[by_vars])
  )]

  # No `proportion` column here, unlike the HT total paths. A share-of-total is
  # meaningful for a total and meaningless for a rate -- group rates do not sum
  # to the overall rate.

  result <- new_creel_estimates( # nolint: object_usage_linter
    # nolint: object_usage_linter
    estimates = estimates_df,
    method = method,
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars,
    unit = rate_unit(design) # nolint: object_usage_linter
  )
  attr(result, "site_contributions") <- site_table
  result
}

#' Abort when a trip-status column is required but absent or one-sided
#'
#' @param design The creel_design object
#' @param interviews Interview rows
#' @param call Calling environment for the condition
#'
#' @keywords internal
#' @noRd
br_require_trip_status <- function(design, interviews, call = rlang::caller_env()) {
  trip_status_col <- design$trip_status_col
  if (is.null(trip_status_col) || !trip_status_col %in% names(interviews)) {
    cli::cli_abort(
      c(
        "{.code use_trips = \"diagnostic\"} requires a trip status column.",
        "x" = "The design has no trip status column, so the two slots cannot be separated.",
        "i" = "Supply {.arg trip_status} to {.fn add_interviews}."
      ),
      call = call
    )
  }
  status <- tolower(interviews[[trip_status_col]])
  n_complete <- sum(status == "complete", na.rm = TRUE) # nolint: object_usage_linter
  n_incomplete <- sum(status == "incomplete", na.rm = TRUE) # nolint: object_usage_linter
  if (n_complete == 0 || n_incomplete == 0) {
    cli::cli_abort(
      c(
        "{.code use_trips = \"diagnostic\"} needs both complete and incomplete trips.",
        "x" = "Found {n_complete} complete and {n_incomplete} incomplete interview{?s}.",
        "i" = "A one-sided comparison has nothing to compare; \\
               use {.code use_trips = \"complete\"} or {.code \"incomplete\"} instead."
      ),
      call = call
    )
  }
  invisible(TRUE)
}

#' Bus-route incomplete-trip harvest rate by truncated mean of ratios
#'
#' Hoenig, Jones, Pollock, Robson & Wade (1997, *Biometrics* 53:306-317) analyse
#' both candidate catch-rate estimators for anglers intercepted mid-trip. The
#' ratio of means "does not provide an estimate of catch rate that can be used
#' with an independent estimate of total effort to provide an unbiased estimate
#' of total catch except in the unrealistic case where lambda is constant over
#' all anglers" -- its expectation weights individual rates by the *square* of
#' completed trip length. The mean of ratios has the correct expectation, and is
#' what this path computes.
#'
#' Two departures from the paper's plain average are forced by the bus-route
#' design:
#'
#' * Interviews are not equally likely. Each is weighted by
#'   `.expansion / .pi_i` -- the within-site subsampling expansion over the
#'   site-by-period inclusion probability -- giving a Hajek weighted mean rather
#'   than an arithmetic one. The previous code divided each *ratio* by `.pi_i`
#'   and summed, which is neither a rate nor a total: it grew linearly with the
#'   number of interviews (GH #108). It also dropped `.expansion` entirely,
#'   which the complete-trip path applies.
#' * The per-angler rate divides by angler-effort, not the party's elapsed
#'   hours, so the result is fish per angler-hour and not fish per party-hour
#'   (GH #106).
#'
#' The mean of ratios has *infinite* asymptotic variance, because `1/L_j` has
#' infinite expectation as trip length approaches zero. Hoenig et al. recommend
#' discarding trips shorter than 30 minutes, which is the `truncate_at` default.
#' Truncation is applied to elapsed trip duration, not to angler-hours: it is the
#' short *clock* interval that makes the reciprocal explode, and a large party
#' fishing briefly can clear an angler-hour threshold while still being the
#' unstable case the truncation exists to remove.
#'
#' @param interviews Incomplete-trip interview rows, already filtered
#' @param by_vars NULL or character vector of grouping variable names
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (0-1)
#' @param design The creel_design object
#' @param truncate_at Numeric minimum trip duration in hours, or NULL to disable
#' @param metric Either "hpue" (harvest per unit effort) or "rpue" (release per
#'   unit effort). Selects the reported `method` string and the noun used in
#'   conditions; the estimator itself is identical, because the numerator column
#'   is whatever `design$harvest_col` names.
#' @param call Calling environment for conditions
#'
#' @return A creel_estimates object with method "mean-of-ratios-hpue" or
#'   "mean-of-ratios-rpue"
#'
#' @keywords internal
#' @noRd
br_incomplete_harvest_rate <- function(
  # nolint: object_usage_linter
  interviews,
  by_vars,
  variance_method,
  conf_level,
  design,
  truncate_at,
  metric = c("hpue", "rpue", "cpue"),
  call = rlang::caller_env()
) {
  metric <- match.arg(metric)
  quantity <- switch(metric, rpue = "release", cpue = "catch", "harvest") # nolint: object_usage_linter
  harvest_col <- design$harvest_col
  angler_effort_col <- design$angler_effort_col
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col

  if (
    !is.null(truncate_at) &&
      (!is.numeric(truncate_at) || length(truncate_at) != 1L || truncate_at <= 0)
  ) {
    cli::cli_abort(
      c(
        "Invalid {.arg truncate_at}: {.val {truncate_at}}",
        "x" = "{.arg truncate_at} must be a positive number of hours, or NULL."
      ),
      call = call
    )
  }

  # Truncate on elapsed duration. trip_duration_col is the explicit clock
  # interval when the design carries one; effort_col is the party's hours fished
  # to the time of interview, which is the same elapsed interval.
  duration_col <- design$trip_duration_col
  if (is.null(duration_col) || !duration_col %in% names(interviews)) {
    duration_col <- design$effort_col
  }

  if (!is.null(truncate_at)) {
    keep <- !is.na(interviews[[duration_col]]) &
      interviews[[duration_col]] >= truncate_at
    n_truncated <- sum(!keep) # nolint: object_usage_linter
    interviews <- interviews[keep, , drop = FALSE]
    if (n_truncated > 0) {
      cli::cli_inform(c(
        "i" = "Discarded {n_truncated} incomplete trip{?s} shorter than \\
               {truncate_at} hour{?s} before mean-of-ratios estimation.",
        " " = "Hoenig et al. (1997) recommend this truncation; \\
               untruncated MOR has infinite variance."
      ))
    }
  } else {
    cli::cli_warn(c(
      "{.arg truncate_at = NULL} disables short-trip truncation.",
      "x" = "The mean-of-ratios estimator has infinite asymptotic variance \\
             without it (Hoenig et al. 1997).",
      "i" = "The reported SE understates the true sampling variability."
    ))
  }

  # Guard against zero/NA angler-effort (angler intercepted at trip start).
  # Survives truncation only when truncate_at is NULL.
  valid_effort <- !is.na(interviews[[angler_effort_col]]) &
    interviews[[angler_effort_col]] > 0
  if (any(!valid_effort)) {
    n_dropped <- sum(!valid_effort) # nolint: object_usage_linter
    cli::cli_warn(
      "Dropping {n_dropped} incomplete-trip interview{?s} with zero or missing effort \\
      before computing {quantity} rate."
    )
    interviews <- interviews[valid_effort, , drop = FALSE]
  }

  if (nrow(interviews) == 0) {
    cli::cli_abort(
      c(
        "No incomplete trips remain for mean-of-ratios estimation.",
        "x" = "All incomplete-trip interviews were truncated or had zero effort.",
        "i" = "Lower {.arg truncate_at} or check the interview effort column."
      ),
      call = call
    )
  }

  # Per-angler rate, then Hajek weights. .contribution / .w_contribution is the
  # weighted mean of the rates; svyratio linearises over both.
  interviews$.h_ratio_i <- interviews[[harvest_col]] /
    interviews[[angler_effort_col]]
  interviews$.w_i <- interviews$.expansion / interviews$.pi_i
  interviews$.contribution <- interviews$.h_ratio_i * interviews$.w_i
  interviews$.w_contribution <- interviews$.w_i

  # Build per-site breakdown table
  # Use intersect() to skip synthetic site/circuit cols absent in ice interviews
  avail_site_cols_inc <- intersect(c(site_col, circuit_col), names(interviews))
  site_table <- interviews[c(
    avail_site_cols_inc, ".h_ratio_i", ".pi_i", ".w_i", ".contribution"
  )]
  names(site_table)[names(site_table) == ".h_ratio_i"] <- "h_ratio_i"
  names(site_table)[names(site_table) == ".pi_i"] <- "pi_i"
  names(site_table)[names(site_table) == ".w_i"] <- "w_i"
  names(site_table)[names(site_table) == ".contribution"] <- "w_i_times_h_ratio_i"

  br_harvest_rate_estimates(
    interviews,
    by_vars,
    variance_method,
    conf_level,
    design,
    site_table,
    method = paste0("mean-of-ratios-", metric),
    denom_col = ".w_contribution",
    zero_denom_msg = c(
      paste0(
        "Cannot compute a ", quantity,
        " rate: the mean-of-ratios weights sum to zero."
      ),
      "x" = "Every incomplete-trip interview has zero weight (.expansion / .pi_i).",
      "i" = "Check {.arg n_counted}, {.arg n_interviewed}, and the sampling frame."
    )
  )
}

# Bus-route release rate estimation ----
# RPUE on a bus-route design is the HPUE estimator with a different numerator.
# Called by estimate_release_rate() when design$design_type == "bus_route"

#' Bus-route release rate estimator
#'
#' `estimate_release_rate()` carried no bus-route dispatch (GH #110), so RPUE on
#' a bus-route design came from the standard interview survey and ignored
#' `.pi_i` and `.expansion` entirely -- the interviews were treated as if equally
#' likely, which for a bus route they are not.
#'
#' Release differs from harvest only in which column supplies the numerator, so
#' this joins the per-interview release count with [estimate_release_build_data()]
#' and hands the result to [estimate_harvest_br()] with `harvest_col` pointed at
#' that column. Both trip paths, the truncation, and the diagnostic pair come
#' along unchanged; only the reported `method` string differs.
#'
#' @inheritParams estimate_harvest_br
#'
#' @return A creel_estimates object with method "ratio-of-means-rpue" or
#'   "mean-of-ratios-rpue", or a creel_estimates_diagnostic for
#'   `use_trips = "diagnostic"`
#'
#' @keywords internal
#' @noRd
estimate_release_br <- function(
  # nolint: object_usage_linter
  design,
  by_vars,
  variance_method,
  conf_level,
  verbose,
  use_trips,
  truncate_at = 0.5,
  call = rlang::caller_env()
) {
  design_rel <- design
  design_rel$interviews <- estimate_release_build_data(design, species = NULL) # nolint: object_usage_linter
  design_rel$harvest_col <- ".release_count"

  estimate_harvest_br(
    design_rel,
    by_vars,
    variance_method,
    conf_level,
    verbose = verbose,
    use_trips = use_trips,
    truncate_at = truncate_at,
    metric = "rpue",
    call = call
  )
}

# Bus-route catch rate estimation ----
# Called by estimate_catch_rate() when design$design_type is "bus_route" or "ice"

#' Bus-route catch rate estimator
#'
#' `estimate_catch_rate()` carried no bus-route or ice dispatch, so CPUE on both
#' design types came from the standard interview survey and ignored `.pi_i` and
#' `.expansion` -- while `estimate_total_catch()` and `estimate_effort()` on the
#' same design object both took the Horvitz-Thompson route. The rate and the
#' totals therefore disagreed: on a bus-route fixture CPUE read 0.466438 where
#' the design's own totals imply 0.433603.
#'
#' Catch differs from harvest only in which column supplies the numerator, so
#' this repoints `harvest_col` at `catch_col` and hands the design to
#' [estimate_harvest_br()], the same delegation [estimate_release_br()] uses.
#' Both trip paths, the truncation and the diagnostic pair come along unchanged;
#' only the reported `method` string differs.
#'
#' Species-level CPUE (`by = species`) is not routed here: it is a different
#' estimator ([estimate_cpue_species()]) returning a `-cpue-species` method, and
#' it keeps the standard path for now.
#'
#' @inheritParams estimate_harvest_br
#'
#' @return A creel_estimates object with method "ratio-of-means-cpue" or
#'   "mean-of-ratios-cpue", or a creel_estimates_diagnostic for
#'   `use_trips = "diagnostic"`
#'
#' @keywords internal
#' @noRd
estimate_catch_br <- function(
  # nolint: object_usage_linter
  design,
  by_vars,
  variance_method,
  conf_level,
  verbose,
  use_trips,
  truncate_at = 0.5,
  call = rlang::caller_env()
) {
  design_catch <- design
  design_catch$harvest_col <- design$catch_col

  estimate_harvest_br(
    design_catch,
    by_vars,
    variance_method,
    conf_level,
    verbose = verbose,
    use_trips = use_trips,
    truncate_at = truncate_at,
    metric = "cpue",
    call = call
  )
}

# Species-level rates on bus-route and ice designs ----
# Called by estimate_catch_rate(), estimate_harvest_rate() and
# estimate_release_rate() when design$design_type is "bus_route" or "ice" and
# `by` names the species column.

#' Species-level CPUE, HPUE and RPUE on a bus-route or ice design
#'
#' The species-level rate estimators ([estimate_cpue_species()],
#' [estimate_hpue_species()], [estimate_release_rate_species()]) build a per-species
#' interview table and hand it to the *standard* interview-survey estimators, so
#' on a bus-route or ice design they ignore `.pi_i` and `.expansion` -- the
#' defect findings 14 and 17 removed from the all-species rates, one estimator
#' over (finding 18).
#'
#' The falsifier is a partition identity rather than a reference value: species
#' partition the catch and every species shares the same effort denominator, so
#' `sum_s rate_s` must equal the all-species rate the same object returns. On a
#' bus-route fixture the species rates summed to 0.937805 against an all-species
#' CPUE of 0.748339 -- 25.3% apart, both reported under a `-cpue` method. The
#' species sum matched the standard-path rate to the last digit, which is what
#' identified the species path rather than the all-species one as the wrong side.
#'
#' Per species this repoints `harvest_col` at that species' count column and
#' delegates to [estimate_harvest_br()] -- the delegation [estimate_release_br()]
#' and [estimate_catch_br()] already use -- so the species rates come off the
#' same estimator body as the all-species ones and cannot drift from them.
#'
#' @param design A creel_design with a non-NULL catch slot.
#' @param species_col Character(1). Name of the species column in `design$catch`.
#' @param interview_by_vars Character vector or NULL. Non-species grouping vars.
#' @param metric One of "cpue", "hpue", "rpue".
#' @inheritParams estimate_harvest_br
#'
#' @return A creel_estimates object whose `method` is the delegate's method with
#'   `-species` appended, matching the standard path's labels.
#'
#' @keywords internal
#' @noRd
estimate_rate_species_br <- function(
  # nolint: object_usage_linter
  design,
  species_col,
  interview_by_vars,
  variance_method,
  conf_level,
  use_trips,
  truncate_at = 0.5,
  metric = c("cpue", "hpue", "rpue"),
  call = rlang::caller_env()
) {
  metric <- match.arg(metric)

  # The diagnostic pair returns two estimates per species, which does not fit
  # one row per species. Refused rather than silently collapsed to one of them:
  # returning either half under a single label is finding 5's failure mode.
  if (identical(use_trips, "diagnostic")) {
    cli::cli_abort(
      c(
        "{.arg use_trips = \"diagnostic\"} is not supported with species grouping.",
        "x" = "The diagnostic pair returns two estimates per species.",
        "i" = "Call the estimator once per {.arg use_trips} value instead."
      ),
      call = call
    )
  }

  all_species <- sort(unique(design[["catch"]][[species_col]]))
  results_list <- vector("list", length(all_species))
  method <- NULL

  for (i in seq_along(all_species)) {
    sp <- all_species[[i]]

    # Same per-species builders the standard path uses, so the two paths differ
    # only in which estimator consumes the table.
    if (identical(metric, "rpue")) {
      sp_data <- estimate_release_build_data(design, species = sp) # nolint: object_usage_linter
      count_col <- ".release_count"
    } else {
      catch_type_val <- if (identical(metric, "cpue")) "caught" else "harvested"
      sp_data <- make_species_catch_for_interviews(design, sp, catch_type_val) # nolint: object_usage_linter
      count_col <- ".species_count"
    }

    design_sp <- design
    design_sp$interviews <- sp_data
    design_sp$catch_col <- count_col
    design_sp$harvest_col <- count_col

    res <- estimate_harvest_br(
      design_sp,
      interview_by_vars,
      variance_method,
      conf_level,
      verbose = FALSE,
      use_trips = use_trips,
      truncate_at = truncate_at,
      metric = metric,
      call = call
    )

    # Taken from the delegate rather than rebuilt, so the ratio-of-means and
    # mean-of-ratios halves stay distinguishable and cannot drift from the
    # all-species labels.
    method <- paste0(res$method, "-species")

    sp_df <- res$estimates
    sp_df[[species_col]] <- sp
    results_list[[i]] <- sp_df[c(species_col, setdiff(names(sp_df), species_col))]
  }

  new_creel_estimates( # nolint: object_usage_linter
    # nolint: object_usage_linter
    estimates = tibble::as_tibble(do.call(rbind, results_list)),
    method = method,
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = c(species_col, interview_by_vars),
    unit = rate_unit(design) # nolint: object_usage_linter
  )
}

# Bus-route total catch estimation ----
# Implements Jones & Pollock (2012) Eq. 19.5 variant: C_hat = sum(c_i / pi_i)
# where c_i = catch_col * .expansion (enumeration expansion factor)
# Called by estimate_total_catch() when design$design_type == "bus_route"

#' Bus-route Horvitz-Thompson total catch estimator
#'
#' Internal function implementing the catch-column variant of Jones & Pollock
#' (2012) Eq. 19.5: C_hat = sum(c_i / pi_i) where c_i = catch_col * .expansion.
#' Called by estimate_total_catch() after bus-route dispatch.
#'
#' @param design A creel_design object with bus-route interviews attached
#' @param by_vars NULL or character vector of grouping variable names
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (0-1)
#' @param verbose Logical. If TRUE, prints informational message about estimator
#'
#' @return A creel_estimates object with site_contributions attribute
#'
#' @keywords internal
#' @noRd
estimate_total_catch_br <- function(
  # nolint: object_usage_linter
  design,
  by_vars,
  variance_method,
  conf_level,
  verbose,
  ci_method = "delta",
  call = rlang::caller_env()
) {
  if (verbose) {
    cli::cli_inform(c(
      "i" = "Using bus-route estimator (Jones & Pollock 2012, Eq. 19.5)"
    ))
  }

  interviews <- design$interviews

  # Defensive check: .expansion column must exist
  if (!".expansion" %in% names(interviews)) {
    msg <- paste0(
      "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
    )
    cli::cli_abort(
      c(
        "Bus-route total catch estimation requires .expansion column.",
        "x" = ".expansion not found in interview data.",
        "i" = msg
      ),
      call = call
    )
  }

  # Defensive check: .pi_i column must exist
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(
      c(
        "Bus-route total catch estimation requires .pi_i column.",
        "x" = ".pi_i not found in interview data.",
        "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
      ),
      call = call
    )
  }

  # Check for missing .pi_i values — hard error listing site+circuit combinations
  if (any(is.na(interviews$.pi_i))) {
    bad_rows <- interviews[is.na(interviews$.pi_i), ]
    site_col_name <- design$bus_route$site_col
    circuit_col_name <- design$bus_route$circuit_col
    combos <- unique(bad_rows[c(site_col_name, circuit_col_name)])
    n_combos <- nrow(combos) # nolint: object_usage_linter
    combo_strs <- apply(combos, 1, function(r) {
      paste0(
        site_col_name,
        "=",
        r[[site_col_name]],
        ", ",
        circuit_col_name,
        "=",
        r[[circuit_col_name]]
      )
    })
    msg_parts <- stats::setNames(combo_strs, rep("*", length(combo_strs)))
    cli::cli_abort(
      c(
        "Missing .pi_i for {n_combos} site+circuit combination{?s}:",
        msg_parts,
        "x" = "All interview site+circuit combinations must appear in the sampling frame.",
        "i" = "Check that interview data site and circuit values match sampling frame."
      ),
      call = call
    )
  }

  catch_col <- design$catch_col
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col
  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col

  # Filter to complete trips only (see br_complete_trips_only)
  interviews <- br_complete_trips_only(interviews, design, "total catch estimation")

  # Compute c_i = catch_col * .expansion (Eq. 19.5 catch variant)
  interviews$.c_i <- interviews[[catch_col]] * interviews$.expansion

  # Zero-count sites (n_counted=0, n_interviewed=0): set .c_i to 0
  if (!is.null(n_counted_col) && !is.null(n_interviewed_col)) {
    zero_mask <- !is.na(interviews[[n_counted_col]]) &
      interviews[[n_counted_col]] == 0 &
      !is.na(interviews[[n_interviewed_col]]) &
      interviews[[n_interviewed_col]] == 0
    interviews$.c_i[zero_mask] <- 0
  }

  # Compute c_i / pi_i (Eq. 19.5 site contribution, catch variant)
  interviews$.contribution <- interviews$.c_i / interviews$.pi_i

  # Build per-site attribution table for site_contributions attribute
  # Use intersect() to skip synthetic site/circuit cols absent in ice interviews
  avail_site_cols <- intersect(c(site_col, circuit_col), names(interviews))
  site_table <- interviews[c(avail_site_cols, ".c_i", ".pi_i", ".contribution")]
  names(site_table)[names(site_table) == ".c_i"] <- "c_i"
  names(site_table)[names(site_table) == ".pi_i"] <- "pi_i"
  names(site_table)[names(site_table) == ".contribution"] <- "c_i_over_pi_i"

  br_build_estimates(
    interviews,
    by_vars,
    variance_method,
    conf_level,
    design,
    site_table,
    method = "ht-total-catch",
    ci_method = ci_method
  )
}

# Bus-route total harvest estimation ----
# Implements Jones & Pollock (2012) Eq. 19.5 variant for complete-trip harvest.
# HT formula: H_hat = sum(h_i * expansion / pi_i) # nolint: commented_code_linter
# Called by estimate_total_harvest() when design$design_type is bus_route or ice

#' Bus-route Horvitz-Thompson total harvest estimator
#'
#' Internal function implementing the harvest-column HT estimator for bus-route
#' and ice designs. Computes H_hat = sum(h_i * expansion / pi_i) using only
#' complete-trip interview rows.
#' Called by estimate_total_harvest() after bus-route/ice dispatch.
#'
#' @param design A creel_design object with bus-route interviews attached
#' @param by_vars NULL or character vector of grouping variable names
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (0-1)
#' @param verbose Logical. If TRUE, prints informational message about estimator
#'
#' @return A creel_estimates object with site_contributions attribute
#'
#' @keywords internal
#' @noRd
estimate_total_harvest_br <- function(
  # nolint: object_usage_linter
  design,
  by_vars,
  variance_method,
  conf_level,
  verbose,
  ci_method = "delta",
  call = rlang::caller_env()
) {
  if (verbose) {
    cli::cli_inform(c(
      "i" = "Using bus-route HT total harvest estimator (Jones & Pollock 2012, Eq. 19.5)"
    ))
  }

  interviews <- design$interviews

  # Defensive checks
  if (!".expansion" %in% names(interviews)) {
    cli::cli_abort(
      c(
        "Bus-route total harvest estimation requires .expansion column.",
        "x" = ".expansion not found in interview data.",
        "i" = paste0(
          "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
        )
      ),
      call = call
    )
  }
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(
      c(
        "Bus-route total harvest estimation requires .pi_i column.",
        "x" = ".pi_i not found in interview data.",
        "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
      ),
      call = call
    )
  }

  harvest_col <- design$harvest_col
  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col

  # Filter to complete trips only (see br_complete_trips_only)
  interviews <- br_complete_trips_only(interviews, design, "total harvest estimation")

  # Compute h_i = harvest_col * .expansion
  interviews$.h_i <- interviews[[harvest_col]] * interviews$.expansion

  # Zero-effort sites: set .h_i to 0
  if (!is.null(n_counted_col) && !is.null(n_interviewed_col)) {
    zero_mask <- !is.na(interviews[[n_counted_col]]) &
      interviews[[n_counted_col]] == 0 &
      !is.na(interviews[[n_interviewed_col]]) &
      interviews[[n_interviewed_col]] == 0
    interviews$.h_i[zero_mask] <- 0
  }

  # Compute h_i / pi_i contribution
  interviews$.contribution <- interviews$.h_i / interviews$.pi_i

  # Build site attribution table (intersect() guard for ice designs)
  avail_site_cols <- intersect(c(site_col, circuit_col), names(interviews))
  site_table <- interviews[c(avail_site_cols, ".h_i", ".pi_i", ".contribution")]
  names(site_table)[names(site_table) == ".h_i"] <- "h_i"
  names(site_table)[names(site_table) == ".pi_i"] <- "pi_i"
  names(site_table)[names(site_table) == ".contribution"] <- "h_i_over_pi_i"

  br_build_estimates(
    interviews,
    by_vars,
    variance_method,
    conf_level,
    design,
    site_table,
    method = "ht-total-harvest",
    ci_method = ci_method
  )
}

# Bus-route total release estimation ----
# Implements Jones & Pollock (2012) Eq. 19.5 variant for release counts.
# HT formula: R_hat = sum(r_i * expansion / pi_i) # nolint: commented_code_linter
# Called by estimate_total_release() when design$design_type is bus_route or ice

#' Bus-route Horvitz-Thompson total release estimator
#'
#' Internal function implementing the release-count HT estimator for bus-route
#' and ice designs. Computes R_hat = sum(r_i * expansion / pi_i) where r_i is
#' the per-interview release count from attached catch data.
#' Called by estimate_total_release() after bus-route/ice dispatch.
#'
#' @param design A creel_design object with bus-route interviews and catch data
#' @param by_vars NULL or character vector of grouping variable names
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (0-1)
#' @param verbose Logical. If TRUE, prints informational message about estimator
#'
#' @return A creel_estimates object with site_contributions attribute
#'
#' @keywords internal
#' @noRd
estimate_total_release_br <- function(
  # nolint: object_usage_linter
  design,
  by_vars,
  variance_method,
  conf_level,
  verbose,
  call = rlang::caller_env()
) {
  if (verbose) {
    cli::cli_inform(c(
      "i" = "Using bus-route HT total release estimator (Jones & Pollock 2012, Eq. 19.5)"
    ))
  }

  # Build release data: joins .release_count to interviews
  interviews <- estimate_release_build_data(design, species = NULL) # nolint: object_usage_linter

  # Defensive checks
  if (!".expansion" %in% names(interviews)) {
    cli::cli_abort(
      c(
        "Bus-route total release estimation requires .expansion column.",
        "x" = ".expansion not found in interview data.",
        "i" = paste0(
          "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
        )
      ),
      call = call
    )
  }
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(
      c(
        "Bus-route total release estimation requires .pi_i column.",
        "x" = ".pi_i not found in interview data.",
        "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
      ),
      call = call
    )
  }

  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col

  # Filter to complete trips only (see br_complete_trips_only)
  interviews <- br_complete_trips_only(interviews, design, "total release estimation")

  # Compute r_i = .release_count * .expansion
  interviews$.r_i <- interviews$.release_count * interviews$.expansion

  # Zero-effort sites: set .r_i to 0
  if (!is.null(n_counted_col) && !is.null(n_interviewed_col)) {
    zero_mask <- !is.na(interviews[[n_counted_col]]) &
      interviews[[n_counted_col]] == 0 &
      !is.na(interviews[[n_interviewed_col]]) &
      interviews[[n_interviewed_col]] == 0
    interviews$.r_i[zero_mask] <- 0
  }

  # Compute r_i / pi_i contribution
  interviews$.contribution <- interviews$.r_i / interviews$.pi_i

  # Build site attribution table (intersect() guard for ice designs)
  avail_site_cols <- intersect(c(site_col, circuit_col), names(interviews))
  site_table <- interviews[c(avail_site_cols, ".r_i", ".pi_i", ".contribution")]
  names(site_table)[names(site_table) == ".r_i"] <- "r_i"
  names(site_table)[names(site_table) == ".pi_i"] <- "pi_i"
  names(site_table)[names(site_table) == ".contribution"] <- "r_i_over_pi_i"

  br_build_estimates(
    interviews,
    by_vars,
    variance_method,
    conf_level,
    design,
    site_table,
    method = "ht-total-release"
  )
}

# Internal helper: restrict a bus-route/ice total to completed trips ----

# The bus-route method is an access-point design (Malvestuto 1996, section
# 20.3.1.2), and its totals are the access-point estimator of section 20.5.1:
# completed trip quantities summed over interviews. An uncompleted trip breaks it
# twice, in opposite directions. The observed count is catch *so far*, not the
# trip's catch, which biases the sum **down**; and pi_i is the inclusion
# probability of a completed trip at a site during the circuit, whereas an
# uncompleted trip is intercepted with probability proportional to its length
# ("length-of-stay bias", section 20.3.1.1), which biases it **up**. The two do
# not cancel predictably, so the net error cannot even be signed.
#
# Incomplete trips support a *rate* -- the truncated Hajek mean of ratios of
# Hoenig et al. (1997), see estimate_harvest_br() -- never a total.
#
# Shared by all three totals so they cannot drift onto different row sets again;
# that drift was the defect. A design with no trip status column records nothing
# to filter on, so its rows are treated as complete.
br_complete_trips_only <- function(
  interviews,
  design,
  quantity = "estimation",
  call = rlang::caller_env()
) {
  trip_status_col <- design$trip_status_col
  if (is.null(trip_status_col) || !trip_status_col %in% names(interviews)) {
    return(interviews)
  }
  is_complete <- tolower(interviews[[trip_status_col]]) == "complete"
  # `call` is threaded through so the abort names the estimator the user called,
  # not this helper, which they have no way to reach directly.
  br_abort_if_no_complete(interviews[is_complete, , drop = FALSE], quantity, call = call)
}

# A Horvitz-Thompson assembly handed a zero-row frame does not notice: it fails
# several calls later inside rowSums() with "all arguments must have the same
# length", which names nothing the caller can act on. The standard designs
# already refuse this by name -- "No complete trips available for HPUE
# estimation" -- so the bus-route and ice paths, which reach the same dead end
# through a different door, say the same thing (GH #128).
#
# `all` is deliberately not offered here: it is not a valid `use_trips` for a
# bus-route design, where an uncompleted trip supports a rate but never a total.
br_abort_if_no_complete <- function(interviews, quantity = "estimation", call = rlang::caller_env()) {
  if (nrow(interviews) > 0L) {
    return(interviews)
  }
  cli::cli_abort(
    c(
      "No complete trips available for {quantity}.",
      "x" = "{.arg use_trips} = 'complete' but this design has 0 complete trips.",
      "i" = paste0(
        "Use {.code use_trips = 'incomplete'} for a rate from uncompleted trips, ",
        "or {.code use_trips = 'diagnostic'} to see both."
      )
    ),
    call = call
  )
}

# Species-level totals on bus-route and ice designs ----
# Called by estimate_total_catch(), estimate_total_harvest() and
# estimate_total_release() when design$design_type is "bus_route" or "ice" and
# `by` names the species column.

#' Species-level HT totals on a bus-route or ice design
#'
#' The three totals resolved `by` against `design$interviews`, where there is no
#' species column, so `by = species` aborted on both design types rather than
#' returning a number (finding 19). The species-level total estimators they would
#' have reached are stratum product sums built on the *standard* interview
#' survey, so routing `by = species` there instead would have reintroduced
#' finding 18 in the totals: a species total that contradicts the all-species
#' total on the same object.
#'
#' The falsifier is the same partition identity finding 18 used, and it is
#' exact for a Horvitz-Thompson sum because that sum is linear in the numerator:
#' `sum_i (c_i * expansion_i / pi_i)` over a partition of `c_i` is the sum over
#' the parts. So `sum_s total_s` must equal the all-species total.
#'
#' Per species this repoints the numerator at that species' counts and delegates
#' to the all-species HT total estimator, the same delegation
#' [estimate_rate_species_br()] uses for the rates. Release is repointed by
#' subsetting `design$catch` rather than the interviews, because
#' [estimate_total_release_br()] derives its own per-interview release counts
#' from the catch table.
#'
#' @param design A creel_design with a non-NULL catch slot.
#' @param species_col Character(1). Name of the species column in `design$catch`.
#' @param interview_by_vars Character vector or NULL. Non-species grouping vars.
#' @param quantity One of "catch", "harvest", "release".
#' @inheritParams estimate_total_catch_br
#'
#' @return A creel_estimates object with method "ht-total-<quantity>-species".
#'
#' @keywords internal
#' @noRd
estimate_total_species_br <- function(
  # nolint: object_usage_linter
  design,
  species_col,
  interview_by_vars,
  variance_method,
  conf_level,
  quantity = c("catch", "harvest", "release"),
  ci_method = "delta",
  call = rlang::caller_env()
) {
  quantity <- match.arg(quantity)

  all_species <- sort(unique(design[["catch"]][[species_col]]))
  results_list <- vector("list", length(all_species))

  for (i in seq_along(all_species)) {
    sp <- all_species[[i]]
    design_sp <- design

    if (identical(quantity, "release")) {
      # estimate_total_release_br() calls estimate_release_build_data() itself,
      # so the species filter has to go in ahead of it, on the catch table.
      catch_df <- design[["catch"]]
      design_sp[["catch"]] <- catch_df[catch_df[[species_col]] == sp, , drop = FALSE]

      res <- estimate_total_release_br(
        design_sp,
        interview_by_vars,
        variance_method,
        conf_level,
        verbose = FALSE,
        call = call
      )
    } else {
      catch_type_val <- if (identical(quantity, "catch")) "caught" else "harvested"
      design_sp$interviews <- make_species_catch_for_interviews(design, sp, catch_type_val) # nolint: object_usage_linter
      design_sp$catch_col <- ".species_count"
      design_sp$harvest_col <- ".species_count"

      total_fn <- if (identical(quantity, "catch")) {
        estimate_total_catch_br
      } else {
        estimate_total_harvest_br
      }
      res <- total_fn(
        design_sp,
        interview_by_vars,
        variance_method,
        conf_level,
        verbose = FALSE,
        ci_method = ci_method,
        call = call
      )
    }

    sp_df <- res$estimates
    sp_df[[species_col]] <- sp
    results_list[[i]] <- sp_df[c(species_col, setdiff(names(sp_df), species_col))]
  }

  new_creel_estimates( # nolint: object_usage_linter
    # nolint: object_usage_linter
    estimates = tibble::as_tibble(do.call(rbind, results_list)),
    method = paste0("ht-total-", quantity, "-species"),
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = c(species_col, interview_by_vars),
    unit = "fish"
  )
}

# Internal helper: validate use_trips on the bus-route rate path ----

# estimate_harvest_br() branches on "diagnostic", then "complete", then
# "incomplete", with no final else, so an unrecognised string reaches the
# complete-trip code with the trip-status filter switched off and returns the
# all-trips answer silently. The standard path rejects the same input, so the
# same typo aborted or not depending on the design type.
#
# The valid set here is deliberately NOT the standard path's. "incomplete" is a
# legitimate rate (the truncated Hajek mean of ratios, Hoenig et al. 1997) and
# an illegitimate total; "all" is the reverse of what it means on the standard
# path -- pooling the two kinds of trip applies the complete-trip ratio of
# Horvitz-Thompson totals to numerators that are catch *so far*, which biases
# the pooled rate down by the incomplete rows' share.
#
# Not match.arg(): it partial-matches, so "comp" would be accepted here and
# rejected by the standard twin. Shared by both rate twins so their valid sets
# cannot drift apart.
validate_use_trips_br <- function(use_trips, call = rlang::caller_env()) {
  valid_use_trips_br <- c("complete", "incomplete", "diagnostic")
  if (use_trips %in% valid_use_trips_br) {
    return(invisible(use_trips))
  }
  cli::cli_abort(
    c(
      "Invalid use_trips value: {.val {use_trips}}",
      "x" = "Must be one of: {.val {valid_use_trips_br}}",
      "i" = if (identical(use_trips, "all")) {
        paste(
          "{.val all} pools completed and uncompleted trips into the",
          "complete-trip ratio estimator; use {.val incomplete} for the",
          "mean-of-ratios rate or {.val diagnostic} to compare the two."
        )
      } else {
        "Matching is exact: {.val complete} is not {.val Complete}."
      }
    ),
    call = call
  )
}

# Internal helper: build creel_estimates from .contribution column ----
# Shared by estimate_harvest_br(), estimate_total_catch_br(),
# estimate_total_harvest_br(), and estimate_total_release_br()

#' Build creel_estimates from pre-computed .contribution column
#'
#' @param interviews Data frame with .contribution column
#' @param by_vars NULL or character vector of grouping column names
#' @param variance_method Character variance method
#' @param conf_level Numeric confidence level
#' @param design creel_design object
#' @param site_table Data frame for site_contributions attribute
#' @param method Character method string recorded on the returned object. Names
#'   the estimator and the quantity it holds ("ht-total-catch",
#'   "ht-total-harvest", "ht-total-release"), so that downstream labelling
#'   (\code{autoplot()}, \code{print()}, \code{write_estimates()} provenance)
#'   reports the right quantity rather than defaulting to effort.
#' @param ci_method character. "delta" (default) or "bootstrap". When
#'   "bootstrap", a second survey-design pass is added using bootstrap
#'   resampling and the results are bound as ci_lo_boot/ci_hi_boot columns.
#'
#' @return A creel_estimates object with site_contributions attribute
#'
#' @keywords internal
#' @noRd
br_build_estimates <- function(
  # nolint: object_usage_linter
  interviews,
  by_vars,
  variance_method,
  conf_level,
  design,
  site_table,
  method,
  ci_method = "delta"
) {
  ci_method <- match.arg(ci_method, c("delta", "bootstrap"))
  strata_cols <- design$strata_cols

  if (is.null(by_vars)) {
    total_estimate <- sum(interviews$.contribution, na.rm = TRUE) # nolint
    n <- nrow(interviews) # nolint: object_usage_linter

    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    svy_br_base <- build_interview_survey(interviews, strata = strata_formula) # nolint: object_usage_linter
    svy_br_taylor <- get_variance_design(svy_br_base, variance_method) # nolint: object_usage_linter
    svy_result <- suppressWarnings(survey::svytotal(~.contribution, svy_br_taylor))
    se <- as.numeric(survey::SE(svy_result)) # nolint: object_usage_linter
    ci <- confint(svy_result, level = conf_level)
    # A catch total is bounded below by zero; the symmetric Wald bound is not.
    ci_lower <- pmax(0, ci[1, 1]) # nolint: object_usage_linter
    ci_upper <- ci[1, 2] # nolint: object_usage_linter

    estimates_df <- tibble::tibble(
      estimate = total_estimate,
      se = se,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      n = n
    )

    if (ci_method == "bootstrap") {
      svy_br_boot <- get_variance_design(svy_br_base, "bootstrap")
      svy_boot_res <- suppressWarnings(survey::svytotal(~.contribution, svy_br_boot))
      ci_boot <- confint(svy_boot_res, level = conf_level)
      estimates_df$ci_lo_boot <- pmax(0, ci_boot[1, 1])
      estimates_df$ci_hi_boot <- ci_boot[1, 2]
    }

    result <- new_creel_estimates( # nolint: object_usage_linter
      # nolint: object_usage_linter
      estimates = estimates_df,
      method = method,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = NULL,
      unit = "fish"
    )
    attr(result, "site_contributions") <- site_table
    result
  } else {
    by_formula <- stats::reformulate(by_vars)

    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    svy_br_base <- build_interview_survey(interviews, strata = strata_formula) # nolint: object_usage_linter
    svy_br_taylor <- get_variance_design(svy_br_base, variance_method) # nolint: object_usage_linter

    svy_result <- suppressWarnings(survey::svyby(
      formula = ~.contribution,
      by = by_formula,
      design = svy_br_taylor,
      FUN = survey::svytotal,
      vartype = c("se", "ci"),
      ci.level = conf_level,
      keep.names = FALSE
    ))

    estimate <- svy_result[[".contribution"]]
    se <- svy_result[["se"]]
    # A catch total is bounded below by zero; the symmetric Wald bound is not.
    ci_lower <- pmax(0, svy_result[["ci_l"]])
    ci_upper <- svy_result[["ci_u"]]

    overall_total <- sum(interviews$.contribution, na.rm = TRUE)
    proportion <- estimate / overall_total

    group_data_for_n <- interviews[by_vars]
    group_data_for_n$.count <- 1
    n_by_group <- stats::aggregate(.count ~ ., data = group_data_for_n, FUN = sum)
    names(n_by_group)[names(n_by_group) == ".count"] <- "n"

    estimates_df <- svy_result[by_vars]
    estimates_df$estimate <- estimate
    estimates_df$se <- se
    estimates_df$ci_lower <- ci_lower
    estimates_df$ci_upper <- ci_upper
    estimates_df$proportion <- proportion
    estimates_df <- merge(estimates_df, n_by_group, by = by_vars, all.x = TRUE, sort = FALSE)
    estimates_df <- tibble::as_tibble(estimates_df)

    col_order <- c(by_vars, "estimate", "se", "ci_lower", "ci_upper", "proportion", "n")
    estimates_df <- estimates_df[col_order]

    if (ci_method == "bootstrap") {
      svy_br_boot <- get_variance_design(svy_br_base, "bootstrap")
      svy_boot_by <- suppressWarnings(survey::svyby(
        formula = ~.contribution,
        by = by_formula,
        design = svy_br_boot,
        FUN = survey::svytotal,
        vartype = c("se", "ci"),
        ci.level = conf_level,
        keep.names = FALSE
      ))
      estimates_df$ci_lo_boot <- pmax(0, svy_boot_by[["ci_l"]])
      estimates_df$ci_hi_boot <- svy_boot_by[["ci_u"]]
    }

    result <- new_creel_estimates( # nolint: object_usage_linter
      # nolint: object_usage_linter
      estimates = estimates_df,
      method = method,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = by_vars,
      unit = "fish"
    )
    attr(result, "site_contributions") <- site_table
    result
  }
}
