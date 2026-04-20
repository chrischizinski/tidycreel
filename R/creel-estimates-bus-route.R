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
estimate_effort_br <- function(design, by_vars, variance_method, conf_level, verbose,
                               effort_target = "sampled_days", call = rlang::caller_env()) { # nolint: object_usage_linter
  # Retrieve interview data (contains .pi_i and .expansion from add_interviews())
  interviews <- design$interviews

  # Defensive check: .expansion column must exist
  if (!".expansion" %in% names(interviews)) {
    cli::cli_abort(c(
      "Bus-route effort estimation requires .expansion column.",
      "x" = ".expansion not found in interview data.",
      "i" = paste0(
        "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
      )
    ), call = call)
  }

  # Defensive check: .pi_i column must exist
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(c(
      "Bus-route effort estimation requires .pi_i column.",
      "x" = ".pi_i not found in interview data.",
      "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
    ), call = call)
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
    cli::cli_abort(c(
      "Missing inclusion probability (.pi_i) for {n_combos} site+circuit combination{?s}:",
      msg_parts,
      "x" = "All interview site+circuit combinations must appear in the sampling frame.",
      "i" = "Check that interview data site and circuit values match sampling frame."
    ), call = call)
  }

  # Identify the effort column stored during add_interviews()
  effort_col <- design$effort_col

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
    ci_lower <- ci[1, 1] # nolint: object_usage_linter
    ci_upper <- ci[1, 2] # nolint: object_usage_linter

    estimates_df <- tibble::tibble(
      estimate = total_estimate,
      se = se,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      n = n
    )

    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = "total",
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = NULL,
      effort_target = effort_target
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
    ci_lower <- svy_result[["ci_l"]]
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
      estimates = estimates_df,
      method = "total",
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = by_vars,
      effort_target = effort_target
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
#' Called by estimate_harvest_rate() after bus-route dispatch.
#'
#' @param design A creel_design object with bus-route interviews attached
#' @param by_vars NULL or character vector of grouping variable names
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (0-1)
#' @param verbose Logical. If TRUE, prints informational message about estimator
#' @param use_trips Character: "complete", "incomplete", or "diagnostic"
#'
#' @return A creel_estimates object with site_contributions attribute,
#'   or creel_estimates_diagnostic for use_trips = "diagnostic"
#'
#' @keywords internal
#' @noRd
estimate_harvest_br <- function(
  # nolint: object_usage_linter
  design, by_vars, variance_method, conf_level, verbose, use_trips,
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
    cli::cli_abort(c(
      "Bus-route harvest estimation requires .expansion column.",
      "x" = ".expansion not found in interview data.",
      "i" = msg
    ), call = call)
  }

  # Defensive check: .pi_i column must exist
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(c(
      "Bus-route harvest estimation requires .pi_i column.",
      "x" = ".pi_i not found in interview data.",
      "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
    ), call = call)
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
    cli::cli_abort(c(
      "Missing .pi_i for {n_combos} site+circuit combination{?s}:",
      msg_parts,
      "x" = "All interview site+circuit combinations must appear in the sampling frame.",
      "i" = "Check that interview data site and circuit values match sampling frame."
    ), call = call)
  }

  # Diagnostic mode: run both complete and incomplete paths, return diagnostic
  if (use_trips == "diagnostic") {
    complete_result <- estimate_harvest_br(
      design, by_vars, variance_method, conf_level,
      verbose = FALSE, use_trips = "complete", call = call
    )
    incomplete_result <- suppressWarnings(estimate_harvest_br(
      design, by_vars, variance_method, conf_level,
      verbose = FALSE, use_trips = "incomplete", call = call
    ))
    result <- list(complete = complete_result, incomplete = incomplete_result)
    class(result) <- c("creel_estimates_diagnostic", "list")
    return(result)
  }

  harvest_col <- design$harvest_col
  effort_col <- design$effort_col
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col
  trip_status_col <- design$trip_status_col
  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col

  # Apply use_trips filtering
  if (use_trips == "complete" && !is.null(trip_status_col)) {
    is_complete <- tolower(interviews[[trip_status_col]]) == "complete"
    interviews <- interviews[is_complete, , drop = FALSE]
  } else if (use_trips == "incomplete") {
    if (!is.null(trip_status_col)) {
      is_incomplete <- tolower(interviews[[trip_status_col]]) == "incomplete"
      interviews <- interviews[is_incomplete, , drop = FALSE]
    }
    # Incomplete path: pi_i-weighted MOR (h_ratio_i = harvest / effort)
    interviews$.h_ratio_i <- interviews[[harvest_col]] / interviews[[effort_col]]
    interviews$.contribution <- interviews$.h_ratio_i / interviews$.pi_i

    # Build per-site breakdown table
    # Use intersect() to skip synthetic site/circuit cols absent in ice interviews
    avail_site_cols_inc <- intersect(c(site_col, circuit_col), names(interviews))
    site_table <- interviews[c(avail_site_cols_inc, ".h_ratio_i", ".pi_i", ".contribution")]
    names(site_table)[names(site_table) == ".h_ratio_i"] <- "h_ratio_i"
    names(site_table)[names(site_table) == ".pi_i"] <- "pi_i"
    names(site_table)[names(site_table) == ".contribution"] <- "h_ratio_i_over_pi_i"

    return(br_build_estimates(
      interviews, by_vars, variance_method, conf_level, design,
      site_table, harvest_col
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

  # Build per-site attribution table for site_contributions attribute
  # Use intersect() to skip synthetic site/circuit cols absent in ice interviews
  avail_site_cols <- intersect(c(site_col, circuit_col), names(interviews))
  site_table <- interviews[c(avail_site_cols, ".h_i", ".pi_i", ".contribution")]
  names(site_table)[names(site_table) == ".h_i"] <- "h_i"
  names(site_table)[names(site_table) == ".pi_i"] <- "pi_i"
  names(site_table)[names(site_table) == ".contribution"] <- "h_i_over_pi_i"

  br_build_estimates(
    interviews, by_vars, variance_method, conf_level, design,
    site_table, harvest_col
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
  design, by_vars, variance_method, conf_level, verbose,
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
    cli::cli_abort(c(
      "Bus-route total catch estimation requires .expansion column.",
      "x" = ".expansion not found in interview data.",
      "i" = msg
    ), call = call)
  }

  # Defensive check: .pi_i column must exist
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(c(
      "Bus-route total catch estimation requires .pi_i column.",
      "x" = ".pi_i not found in interview data.",
      "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
    ), call = call)
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
        site_col_name, "=", r[[site_col_name]], ", ",
        circuit_col_name, "=", r[[circuit_col_name]]
      )
    })
    msg_parts <- stats::setNames(combo_strs, rep("*", length(combo_strs)))
    cli::cli_abort(c(
      "Missing .pi_i for {n_combos} site+circuit combination{?s}:",
      msg_parts,
      "x" = "All interview site+circuit combinations must appear in the sampling frame.",
      "i" = "Check that interview data site and circuit values match sampling frame."
    ), call = call)
  }

  catch_col <- design$catch_col
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col
  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col

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
    interviews, by_vars, variance_method, conf_level, design,
    site_table, catch_col
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
  design, by_vars, variance_method, conf_level, verbose,
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
    cli::cli_abort(c(
      "Bus-route total harvest estimation requires .expansion column.",
      "x" = ".expansion not found in interview data.",
      "i" = paste0(
        "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
      )
    ), call = call)
  }
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(c(
      "Bus-route total harvest estimation requires .pi_i column.",
      "x" = ".pi_i not found in interview data.",
      "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
    ), call = call)
  }

  harvest_col <- design$harvest_col
  trip_status_col <- design$trip_status_col
  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col

  # Filter to complete trips only
  if (!is.null(trip_status_col)) {
    is_complete <- tolower(interviews[[trip_status_col]]) == "complete"
    interviews <- interviews[is_complete, , drop = FALSE]
  }

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
    interviews, by_vars, variance_method, conf_level, design,
    site_table, harvest_col
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
  design, by_vars, variance_method, conf_level, verbose,
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
    cli::cli_abort(c(
      "Bus-route total release estimation requires .expansion column.",
      "x" = ".expansion not found in interview data.",
      "i" = paste0(
        "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
      )
    ), call = call)
  }
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(c(
      "Bus-route total release estimation requires .pi_i column.",
      "x" = ".pi_i not found in interview data.",
      "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
    ), call = call)
  }

  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col

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
    interviews, by_vars, variance_method, conf_level, design,
    site_table, ".release_count"
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
#' @param key_col Name of the primary column (harvest_col or catch_col) for n
#'
#' @return A creel_estimates object with site_contributions attribute
#'
#' @keywords internal
#' @noRd
br_build_estimates <- function(
  # nolint: object_usage_linter
  interviews, by_vars, variance_method, conf_level, design, site_table, key_col
) {
  strata_cols <- design$strata_cols

  if (is.null(by_vars)) {
    total_estimate <- sum(interviews$.contribution, na.rm = TRUE) # nolint
    n <- nrow(interviews) # nolint: object_usage_linter

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
    ci_lower <- ci[1, 1] # nolint: object_usage_linter
    ci_upper <- ci[1, 2] # nolint: object_usage_linter

    estimates_df <- tibble::tibble(
      estimate = total_estimate,
      se = se,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      n = n
    )

    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = "total",
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = NULL
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
    ci_lower <- svy_result[["ci_l"]]
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

    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = "total",
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = by_vars
    )
    attr(result, "site_contributions") <- site_table
    result
  }
}
