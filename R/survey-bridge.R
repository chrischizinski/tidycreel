# Exported escape hatch ----

#' Extract internal survey design object for advanced use
#'
#' @description
#' Provides power users with direct access to the internal survey.design2 object
#' for advanced analysis using survey package functions. This is an escape hatch
#' for workflows not yet wrapped by tidycreel. Most users should use
#' [estimate_effort()] instead.
#'
#' The function issues a once-per-session warning to educate users that this is
#' an advanced feature with risks if the returned object is modified incorrectly.
#'
#' @param design A creel_design object with counts attached via \code{\link{add_counts}}
#'
#' @return A survey.design2 object (from survey::svydesign). Due to R's
#'   copy-on-modify semantics, modifications to the returned object will not
#'   affect the internal design$survey object.
#'
#' @section Warning:
#' This function issues a once-per-session warning explaining:
#' \itemize{
#'   \item This is an advanced feature for power users
#'   \item Most users should use \code{estimate_effort()} instead
#'   \item Modifying the survey design may produce incorrect variance estimates
#' }
#'
#' @examples
#' # Basic workflow
#' library(survey)
#' cal <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend")
#' )
#' design <- creel_design(cal, date = date, strata = day_type)
#'
#' counts <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   count = c(15, 23, 45, 52)
#' )
#'
#' design2 <- add_counts(design, counts)
#'
#' # Extract survey object for advanced use
#' svy <- as_survey_design(design2)
#'
#' # Use with survey package functions
#' survey::svytotal(~count, svy)
#' survey::svymean(~count, svy)
#'
#' @export
as_survey_design <- function(design) {
  # Validate input is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Check counts/survey exist
  if (is.null(design$counts) || is.null(design$survey)) {
    cli::cli_abort(c(
      "No survey design available.",
      "x" = "Call {.fn add_counts} before extracting survey design.",
      "i" = "Example: {.code design <- add_counts(design, counts)}"
    ))
  }

  # Issue once-per-session warning
  rlang::warn(
    message = c(
      "Accessing internal survey design object.",
      "i" = "This is an advanced feature. Most users should use {.fn estimate_effort} instead.",
      "!" = "Modifying the survey design may produce incorrect variance estimates."
    ),
    .frequency = "once",
    .frequency_id = "tidycreel_as_survey_design"
  )

  # Return design$survey
  # R's copy-on-modify semantics ensure modifications don't affect original
  design$survey
}

# Internal survey bridge functions ----

#' Get survey design for specified variance method
#'
#' Internal helper that converts a survey design to use replicate weights for
#' bootstrap or jackknife variance estimation. For Taylor linearization, returns
#' the design unchanged.
#'
#' @param design Survey design object (survey.design2 from survey::svydesign)
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#'
#' @return Survey design object: original for Taylor, svrepdesign for bootstrap/jackknife
#'
#' @keywords internal
#' @noRd
get_variance_design <- function(design, variance_method) {
  if (variance_method == "taylor") {
    design
  } else if (variance_method == "bootstrap") {
    suppressWarnings(
      survey::as.svrepdesign(design, type = "bootstrap", replicates = 500)
    )
  } else if (variance_method == "jackknife") {
    tryCatch(
      suppressWarnings(survey::as.svrepdesign(design, type = "auto")),
      error = function(e) {
        msg <- conditionMessage(e)
        if (grepl("has only one PSU", msg, fixed = TRUE)) {
          # survey encodes: "Stratum<name>has only one PSU" (no spaces)
          strat <- regmatches(
            msg,
            regexpr("(?<=Stratum)(.+?)(?=has only one PSU)", msg, perl = TRUE)
          )
          strat_label <- if (length(strat) > 0L && nzchar(strat)) { # nolint: object_usage_linter
            strat
          } else {
            "unknown"
          }
          cli::cli_abort(
            c(
              paste0(
                "Stratum {.val {strat_label}} has only 1 PSU \u2014 ",
                "jackknife variance cannot be estimated."
              ),
              "x" = paste0(
                "A stratum must have at least 2 PSUs for jackknife ",
                "resampling."
              ),
              "i" = paste0(
                "Increase the sampling rate for stratum ",
                "{.val {strat_label}}, or use {.code variance = 'taylor'}."
              )
            ),
            class = "creel_error_single_psu"
          )
        }
        stop(e)
      }
    )
  }
}

#' Build interview survey design with explicit equal-probability weights
#'
#' Internal helper that constructs a \code{survey.design2} object for interview
#' data. Creel interview designs assume equal probability of selection within
#' each stratum: interviewers contact all available anglers encountered during a
#' survey period. Passing \code{weights = rep(1, nrow(data))} makes this
#' assumption explicit and suppresses the survey package diagnostic
#' "No weights or probabilities supplied, assuming equal probability", which
#' would otherwise appear on every \code{add_interviews()} call.
#'
#' Equal-probability weights do not affect downstream means or ratios
#' (\code{svymean}, \code{svyratio}), nor variance estimates from Taylor
#' linearization, bootstrap, or jackknife when all weights are identical.
#'
#' @param data Data frame of interview records.
#' @param strata A one-sided formula (e.g. \code{~.strata}) or \code{NULL} for
#'   no stratification.
#'
#' @return A \code{survey.design2} object.
#'
#' @keywords internal
#' @noRd
build_interview_survey <- function(data, strata = NULL) {
  survey::svydesign(
    ids = ~1,
    strata = strata,
    weights = rep(1, nrow(data)),
    data = data
  )
}

#' Validate count data structure (Tier 1)
#'
#' Internal validator that checks count data matches the creel_design structure.
#' Verifies that design-critical columns exist in the count data and contain no
#' NA values. This is Tier 1 validation - structural checks that must pass before
#' constructing a survey design object.
#'
#' @param counts Data frame containing count data
#' @param design A creel_design object
#' @param psu Character name of PSU column in counts data
#' @param allow_invalid Logical flag. If FALSE (default), validation failures
#'   abort with cli error. If TRUE, failures generate warnings instead.
#'
#' @return A creel_validation object with tier = 1L
#'
#' @keywords internal
#' @noRd
validate_counts_tier1 <- function(counts, design, psu, allow_invalid = FALSE) {
  collection <- checkmate::makeAssertCollection()

  # Check 1: design$date_col exists in counts
  if (!design$date_col %in% names(counts)) {
    collection$push(sprintf(
      "Date column '%s' from design not found in count data",
      design$date_col
    ))
  }

  # Check 2: all design$strata_cols exist in counts
  missing_strata <- setdiff(design$strata_cols, names(counts))
  if (length(missing_strata) > 0) {
    collection$push(sprintf(
      "Strata column(s) from design not found in count data: %s",
      paste(missing_strata, collapse = ", ")
    ))
  }

  # Check 3: PSU column exists in counts
  if (!psu %in% names(counts)) {
    collection$push(sprintf(
      "PSU column '%s' not found in count data",
      psu
    ))
  }

  # If columns exist, check for NA values
  if (design$date_col %in% names(counts)) {
    na_count_date <- sum(is.na(counts[[design$date_col]]))
    if (na_count_date > 0) {
      collection$push(sprintf(
        "Date column '%s' contains %d NA value(s)",
        design$date_col, na_count_date
      ))
    }
  }

  # Check NA values in strata columns
  for (col in design$strata_cols) {
    if (col %in% names(counts)) {
      na_count_strata <- sum(is.na(counts[[col]]))
      if (na_count_strata > 0) {
        collection$push(sprintf(
          "Strata column '%s' contains %d NA value(s)",
          col, na_count_strata
        ))
      }
    }
  }

  # Check NA values in PSU column
  if (psu %in% names(counts)) {
    na_count_psu <- sum(is.na(counts[[psu]]))
    if (na_count_psu > 0) {
      collection$push(sprintf(
        "PSU column '%s' contains %d NA value(s)",
        psu, na_count_psu
      ))
    }
  }

  # Build validation results data frame
  if (!collection$isEmpty()) {
    msgs <- collection$getMessages()
    results <- data.frame(
      check = paste0("check_", seq_along(msgs)),
      status = "fail",
      message = msgs,
      stringsAsFactors = FALSE
    )

    if (!allow_invalid) {
      cli::cli_abort(c(
        "Count data validation failed (Tier 1):",
        stats::setNames(paste0("{.var ", msgs, "}"), rep("x", length(msgs))),
        "i" = "Count data must have all design columns with no NA values."
      ))
    } else {
      # Warn but continue
      for (msg in msgs) {
        cli::cli_warn(msg)
      }
    }
  } else {
    # All checks passed
    results <- data.frame(
      check = "all_checks",
      status = "pass",
      message = "All Tier 1 validation checks passed",
      stringsAsFactors = FALSE
    )
  }

  # Return validation object
  new_creel_validation( # nolint: object_usage_linter
    results = results,
    tier = 1L,
    context = "add_counts validation"
  )
}

#' Detect duplicate PSU rows in count data
#'
#' @param counts Data frame containing count data
#' @param psu Character name of PSU column
#' @param call Caller environment for error reporting
#'
#' @keywords internal
#' @noRd
detect_duplicate_psus <- function(counts, psu, call = rlang::caller_env()) {
  dup_psus <- counts[[psu]][duplicated(counts[[psu]])]
  if (length(dup_psus) > 0) {
    cli::cli_warn(
      c(
        "Duplicate PSU values detected in count data.",
        "i" = "Found {length(dup_psus)} duplicate value(s) in column {.field {psu}}.",
        "i" = "If multiple counts were taken per day, specify {.arg count_time_col}.",
        "i" = "Example: {.code add_counts(design, counts, count_time_col = count_time)}"
      ),
      call = call
    )
  }
}

#' Aggregate within-day count observations to PSU-level means
#'
#' Groups multiple count rows per PSU into a single-row mean, storing the
#' within-day sum of squared deviations (SS_d) and count (K_d) needed for
#' Rasmussen two-stage variance estimation.
#'
#' @param counts Data frame of count data (multiple rows per PSU allowed)
#' @param psu_col Character name of PSU column (e.g. "date")
#' @param count_var Character name of the numeric count column
#' @param count_time_col Character name of the column identifying sub-PSU
#'   observations (used for grouping only -- not ordered or weighted)
#' @param key_cols Character vector of all grouping key columns
#'   (psu_col + strata_cols). These define a unique PSU.
#'
#' @return A list with elements:
#'   \describe{
#'     \item{aggregated}{Data frame with one row per PSU; count_var replaced by C-bar_d}
#'     \item{within_day_var}{Data frame with columns: key_cols + ss_d + k_d}
#'   }
#'
#' @keywords internal
#' @noRd
aggregate_within_day <- function(counts, psu_col, count_var, count_time_col, key_cols) {
  # Create grouping key as character for split()
  if (length(key_cols) == 1) {
    group_key <- as.character(counts[[key_cols]])
  } else {
    group_key <- do.call(paste, c(counts[key_cols], sep = "\u001f"))
  }

  groups <- split(seq_len(nrow(counts)), group_key)

  agg_rows <- vector("list", length(groups))
  var_rows <- vector("list", length(groups))

  for (i in seq_along(groups)) {
    idx <- groups[[i]]
    g <- counts[idx, , drop = FALSE]
    vals <- g[[count_var]]

    c_mean <- mean(vals)
    ss_d <- sum((vals - c_mean)^2)
    k_d <- length(vals)

    # Build one aggregated row: take first row, replace count_var with mean
    row <- g[1L, , drop = FALSE]
    row[[count_var]] <- c_mean
    # Drop the count_time_col column -- no longer meaningful after aggregation
    row[[count_time_col]] <- NULL

    # Build within-day stats row
    var_row <- g[1L, key_cols, drop = FALSE]
    var_row$ss_d <- ss_d
    var_row$k_d <- k_d

    agg_rows[[i]] <- row
    var_rows[[i]] <- var_row
  }

  list(
    aggregated     = do.call(rbind, agg_rows),
    within_day_var = do.call(rbind, var_rows)
  )
}

#' Compute progressive daily effort estimates (Ê_d = C × τ × κ)
#'
#' Replaces raw count values with per-PSU daily effort estimates following the
#' progressive count formula from Hoenig et al. (1993) and Pope et al. Ch. 17:
#'
#'   Ê_d = C × τ × κ = C × τ × (T_d / τ) = C × T_d
#'
#' where C is the raw angler count, τ is circuit_time (hours), and T_d is the
#' period length (hours). The count column is replaced in-place with Ê_d values
#' and period_length_col is dropped (to prevent it being treated as a second
#' count variable by estimate_effort_total()).
#'
#' @param counts Data frame of count data (one row per PSU after aggregation)
#' @param count_var Character name of the raw count column (replaced with Ê_d)
#' @param period_length_col Character name of the T_d column (hours, dropped after)
#' @param circuit_time Numeric circuit duration τ (hours)
#'
#' @return Modified counts data frame with count_var replaced by Ê_d values
#'   and period_length_col removed
#'
#' @references Hoenig, Robson, Jones, Pollock (1993). Scheduling counts in the
#'   instantaneous and progressive count methods. NAJFM 13:723-736.
#'   Pope et al. (draft) Ch. 17 Creel Surveys, p. 39.
#'
#' @keywords internal
#' @noRd
compute_progressive_effort <- function(counts, count_var, period_length_col, circuit_time) {
  period_length <- counts[[period_length_col]]
  kappa <- period_length / circuit_time
  effort_d <- counts[[count_var]] * circuit_time * kappa
  counts[[count_var]] <- effort_d
  counts[[period_length_col]] <- NULL
  counts
}

#' Construct survey design object
#'
#' Internal function that wraps survey::svydesign() with domain-specific error
#' handling. Constructs a stratified survey design from creel count data using
#' the strata and PSU specifications from the creel_design object.
#'
#' For multiple strata columns, creates an interaction variable to combine them
#' into a single stratification factor before passing to svydesign.
#'
#' @param design A creel_design object with $counts already populated
#'
#' @return An object of class "survey.design2" (from survey::svydesign)
#'
#' @keywords internal
#' @noRd
construct_survey_design <- function(design) {
  counts_data <- design$counts
  psu_col <- design$psu_col
  strata_cols <- design$strata_cols

  # Create strata variable
  if (length(strata_cols) == 1) {
    # Single stratum - use directly
    counts_data$.strata <- counts_data[[strata_cols]]
  } else {
    # Multiple strata - create interaction
    strata_factors <- counts_data[strata_cols]
    counts_data$.strata <- interaction(strata_factors, drop = TRUE)
  }

  # Build formulas
  psu_formula <- stats::reformulate(psu_col)
  strata_formula <- stats::reformulate(".strata")

  # Attempt to construct survey design with error wrapping
  tryCatch(
    {
      survey::svydesign(
        ids = psu_formula,
        strata = strata_formula,
        data = counts_data,
        nest = TRUE
      )
    },
    error = function(e) {
      # Detect specific error types and provide domain guidance
      err_msg <- conditionMessage(e)

      if (grepl("Stratum.*has only one PSU", err_msg, ignore.case = TRUE)) {
        # Lonely PSU error
        cli::cli_abort(
          c(
            "Survey design construction failed: lonely PSU detected.",
            "x" = paste(
              "At least one stratum has only one PSU (Primary Sampling Unit).",
              "Variance estimation requires 2+ PSUs per stratum."
            ),
            "i" = "Possible solutions:",
            "*" = "Combine small strata with similar characteristics",
            "*" = "Use a different stratification scheme",
            "*" = "Collect data from more PSUs (days) in sparse strata"
          ),
          class = "creel_error_single_psu"
        )
      } else if (grepl("variable.*not found", err_msg, ignore.case = TRUE)) {
        # Column not found
        required_cols <- c(psu_col, strata_cols) # nolint: object_usage_linter
        cli::cli_abort(c(
          "Survey design construction failed: missing column.",
          "x" = err_msg,
          "i" = "Required columns: {.field {required_cols}}"
        ))
      } else {
        # Generic survey error - wrap with guidance
        cli::cli_abort(c(
          "Survey design construction failed.",
          "x" = err_msg,
          "i" = paste(
            "Check that count data has correct structure for PSU column",
            "{.field {psu_col}} and strata columns {.field {strata_cols}}."
          )
        ))
      }
    }
  )
}

#' Validate data quality (Tier 2)
#'
#' Internal function that checks for data quality issues in a creel_design with
#' attached counts. Issues warnings (not errors) for zero/negative count values
#' and sparse strata (< 3 observations). These are Tier 2 checks - data quality
#' issues that should be investigated but don't prevent estimation.
#'
#' @param design A creel_design object with counts attached
#'
#' @return NULL (invisible) - function called for side effects (warnings)
#'
#' @keywords internal
#' @noRd
warn_tier2_issues <- function(design) {
  counts_data <- design$counts
  date_col <- design$date_col
  strata_cols <- design$strata_cols
  psu_col <- design$psu_col

  # Identify count variable(s): numeric columns that are not design metadata
  excluded_cols <- c(date_col, strata_cols, psu_col)
  numeric_cols <- names(counts_data)[sapply(counts_data, is.numeric)]
  count_vars <- setdiff(numeric_cols, excluded_cols)

  # Check each count variable for zero/negative values
  for (count_var in count_vars) {
    values <- counts_data[[count_var]]

    # Check for zero values
    n_zero <- sum(values == 0, na.rm = TRUE)
    if (n_zero > 0) {
      cli::cli_warn(c(
        "Count variable {.field {count_var}} contains {n_zero} zero value{?s}.",
        "i" = "Zero values may indicate days with no fishing activity or data collection issues.",
        "i" = "Consider whether zeros are true zeros or missing data."
      ))
    }

    # Check for negative values
    n_negative <- sum(values < 0, na.rm = TRUE)
    if (n_negative > 0) {
      cli::cli_warn(c(
        "Count variable {.field {count_var}} contains {n_negative} negative value{?s}.",
        "!" = "Negative values indicate data entry errors or incorrect calculations.",
        "i" = "Review and correct negative values before estimation."
      ))
    }
  }

  # Check for sparse strata (< 3 observations per stratum)
  # Create the same strata variable used in survey design
  if (length(strata_cols) == 1) {
    strata_var <- counts_data[[strata_cols]]
  } else {
    strata_factors <- counts_data[strata_cols]
    strata_var <- interaction(strata_factors, drop = TRUE)
  }

  # Count observations per stratum
  strata_counts <- table(strata_var)
  sparse_strata <- strata_counts[strata_counts < 3]

  if (length(sparse_strata) > 0) {
    # Build bullet items for each sparse stratum
    bullet_items <- character(length(sparse_strata))
    for (i in seq_along(sparse_strata)) {
      stratum_name <- names(sparse_strata)[i]
      n_obs <- sparse_strata[i]
      bullet_items[i] <- sprintf("Stratum %s: %d observation%s", stratum_name, n_obs, ifelse(n_obs == 1, "", "s"))
    }
    names(bullet_items) <- rep("*", length(sparse_strata))

    cli::cli_warn(c(
      "{length(sparse_strata)} strat{?um/a} ha{?s/ve} fewer than 3 observations:",
      bullet_items,
      "!" = "Sparse strata produce unstable variance estimates.",
      "i" = "Consider combining sparse strata or collecting more data."
    ))
  }

  invisible(NULL)
}

#' Validate data quality for groups (Tier 2)
#'
#' Internal function that checks for sparse groups (< 3 observations per group
#' level) in grouped estimation. Issues warnings (not errors) for data quality
#' issues. This is a Tier 2 check - data quality issue that should be
#' investigated but doesn't prevent estimation.
#'
#' @param design A creel_design object with counts attached
#' @param by_vars Character vector of grouping variable names
#'
#' @return NULL (invisible) - function called for side effects (warnings)
#'
#' @keywords internal
#' @noRd
warn_tier2_group_issues <- function(design, by_vars) {
  counts_data <- design$counts

  # Count observations per group combination
  group_data <- counts_data[by_vars]
  group_data$count <- 1
  group_counts <- stats::aggregate(
    count ~ .,
    data = group_data,
    FUN = sum
  )

  # Identify sparse groups (< 3 observations)
  sparse_groups <- group_counts[group_counts$count < 3, ]

  if (nrow(sparse_groups) > 0) {
    # Build bullet items for each sparse group
    bullet_items <- character(nrow(sparse_groups))
    for (i in seq_len(nrow(sparse_groups))) {
      group_vals <- sparse_groups[i, by_vars, drop = FALSE]
      group_label <- paste(
        paste0(by_vars, "=", group_vals),
        collapse = ", "
      )
      n_obs <- sparse_groups$count[i]
      bullet_items[i] <- sprintf(
        "Group %s: %d observation%s",
        group_label,
        n_obs,
        ifelse(n_obs == 1, "", "s")
      )
    }
    names(bullet_items) <- rep("*", length(bullet_items))

    cli::cli_warn(c(
      "{nrow(sparse_groups)} group{?s} ha{?s/ve} fewer than 3 observations:",
      bullet_items,
      "!" = "Sparse groups produce unstable variance estimates.",
      "i" = "Consider combining sparse groups or collecting more data."
    ))
  }

  invisible(NULL)
}

#' Validate interview data quality (Tier 2)
#'
#' Internal function that checks for data quality issues in interview data
#' attached to a creel_design. Issues warnings (not errors) for suspicious
#' values. These are Tier 2 checks - data quality issues that should be
#' investigated but don't prevent estimation.
#'
#' @param design A creel_design object with interviews attached
#'
#' @return NULL (invisible) - function called for side effects (warnings)
#'
#' @keywords internal
#' @noRd
warn_tier2_interview_issues <- function(design) {
  interviews <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$effort_col
  strata_cols <- design$strata_cols

  # Check for very short trips (effort < 0.1 hours = 6 minutes)
  if (!is.null(effort_col)) {
    n_short <- sum(interviews[[effort_col]] < 0.1, na.rm = TRUE)
    if (n_short > 0) {
      cli::cli_warn(c(
        "{n_short} interview{?s} ha{?s/ve} effort < 0.1 hours (6 minutes).",
        "i" = "Very short trips may indicate data entry errors."
      ))
    }
  }

  # Check for zero catch values
  n_zero <- sum(interviews[[catch_col]] == 0, na.rm = TRUE)
  if (n_zero > 0) {
    cli::cli_warn(c(
      "{n_zero} interview{?s} ha{?s/ve} zero catch.",
      "i" = "Zero catch may be valid (skunked) or indicate missing data."
    ))
  }

  # Check for negative catch values
  n_neg_catch <- sum(interviews[[catch_col]] < 0, na.rm = TRUE)
  if (n_neg_catch > 0) {
    cli::cli_warn(c(
      "{n_neg_catch} interview{?s} ha{?s/ve} negative catch values.",
      "!" = "Negative catch indicates data entry errors.",
      "i" = "Review and correct before estimation."
    ))
  }

  # Check for negative effort values
  if (!is.null(effort_col)) {
    n_neg_effort <- sum(interviews[[effort_col]] < 0, na.rm = TRUE)
    if (n_neg_effort > 0) {
      cli::cli_warn(c(
        "{n_neg_effort} interview{?s} ha{?s/ve} negative effort values.",
        "!" = "Negative effort indicates data entry errors.",
        "i" = "Review and correct before estimation."
      ))
    }
  }

  # Check for missing effort values (NA)
  if (!is.null(effort_col)) {
    n_na_effort <- sum(is.na(interviews[[effort_col]]))
    if (n_na_effort > 0) {
      cli::cli_warn(c(
        "{n_na_effort} interview{?s} ha{?s/ve} missing effort values.",
        "i" = "Missing effort limits CPUE estimation."
      ))
    }
  }

  # Check for sparse interview coverage per stratum (< 3 interviews per stratum)
  # Create the same strata variable used in survey design
  if (length(strata_cols) == 1) {
    strata_var <- interviews[[strata_cols]]
  } else {
    strata_factors <- interviews[strata_cols]
    strata_var <- interaction(strata_factors, drop = TRUE)
  }

  # Count interviews per stratum
  strata_counts <- table(strata_var)
  sparse_strata <- strata_counts[strata_counts < 3]

  if (length(sparse_strata) > 0) {
    # Build bullet items for each sparse stratum
    bullet_items <- character(length(sparse_strata))
    for (i in seq_along(sparse_strata)) {
      stratum_name <- names(sparse_strata)[i]
      n_obs <- sparse_strata[i]
      bullet_items[i] <- sprintf(
        "Stratum %s: %d interview%s",
        stratum_name,
        n_obs,
        ifelse(n_obs == 1, "", "s")
      )
    }
    names(bullet_items) <- rep("*", length(bullet_items))

    cli::cli_warn(c(
      "{length(sparse_strata)} strat{?um/a} ha{?s/ve} fewer than 3 interviews:",
      bullet_items,
      "!" = "Sparse strata produce unstable variance estimates.",
      "i" = "Consider combining sparse strata or collecting more data."
    ))
  }

  invisible(NULL)
}

#' Validate ratio estimator sample size
#'
#' Internal function that checks sample size adequacy for ratio estimation (CPUE or
#' harvest HPUE). Errors if n < 10 (ungrouped or any group), warns if 10 <= n < 30.
#' These thresholds follow best practices for ratio estimation stability.
#'
#' @param design A creel_design object with interviews attached
#' @param by_vars NULL for ungrouped, or character vector of grouping variable names
#' @param type Character string: "cpue" (default) or "harvest" for error message context
#'
#' @return NULL (invisible) - function called for side effects (errors/warnings)
#'
#' @keywords internal
#' @noRd
validate_ratio_sample_size <- function(design, by_vars, type = "cpue") {
  interviews <- design$interviews

  # Set estimation type for messages
  estimation_type <- if (type == "harvest") "harvest" else "CPUE" # nolint: object_usage_linter

  if (is.null(by_vars)) {
    # Ungrouped validation
    n <- nrow(interviews)

    if (n < 10) {
      cli::cli_abort(c(
        "Insufficient sample size for {estimation_type} estimation.",
        "x" = "Sample size is {n}, but ratio estimation requires n >= 10.",
        "i" = "Collect more interview observations before estimating {estimation_type}."
      ))
    }

    if (n >= 10 && n < 30) {
      cli::cli_warn(c(
        "Small sample size for {estimation_type} estimation.",
        "!" = "Sample size is {n}. Ratio estimates are more stable with n >= 30.",
        "i" = "Variance estimates may be unstable with n < 30."
      ))
    }
  } else {
    # Grouped validation
    # Count interviews per group combination
    group_data <- interviews[by_vars]
    group_data$.count <- 1
    group_counts <- stats::aggregate(
      .count ~ .,
      data = group_data,
      FUN = sum
    )
    names(group_counts)[names(group_counts) == ".count"] <- "n"

    # Check for groups with n < 10 (error condition)
    small_groups <- group_counts[group_counts$n < 10, ]
    if (nrow(small_groups) > 0) {
      # Build bullet items for each small group
      bullet_items <- character(nrow(small_groups))
      for (i in seq_len(nrow(small_groups))) {
        group_vals <- small_groups[i, by_vars, drop = FALSE]
        group_label <- paste(
          paste0(by_vars, "=", group_vals),
          collapse = ", "
        )
        n_obs <- small_groups$n[i]
        bullet_items[i] <- sprintf(
          "Group %s: n=%d",
          group_label,
          n_obs
        )
      }
      names(bullet_items) <- rep("*", length(bullet_items))

      cli::cli_abort(c(
        "Insufficient sample size in {nrow(small_groups)} group{?s}:",
        bullet_items,
        "x" = "Ratio estimation requires n >= 10 per group.",
        "i" = "Combine small groups or collect more interview observations."
      ))
    }

    # Check for groups with 10 <= n < 30 (warning condition)
    medium_groups <- group_counts[group_counts$n >= 10 & group_counts$n < 30, ]
    if (nrow(medium_groups) > 0) {
      # Build bullet items for each medium group
      bullet_items <- character(nrow(medium_groups))
      for (i in seq_len(nrow(medium_groups))) {
        group_vals <- medium_groups[i, by_vars, drop = FALSE]
        group_label <- paste(
          paste0(by_vars, "=", group_vals),
          collapse = ", "
        )
        n_obs <- medium_groups$n[i]
        bullet_items[i] <- sprintf(
          "Group %s: n=%d",
          group_label,
          n_obs
        )
      }
      names(bullet_items) <- rep("*", length(bullet_items))

      cli::cli_warn(c(
        "Small sample size in {nrow(medium_groups)} group{?s}:",
        bullet_items,
        "!" = "Ratio estimates are more stable with n >= 30 per group.",
        "i" = "Variance estimates may be unstable with n < 30."
      ))
    }
  }

  invisible(NULL)
}

#' Validate MOR estimator availability
#'
#' Checks that trip_status field exists and incomplete trips are available
#' for mean-of-ratios estimation.
#'
#' @param design creel_design object
#'
#' @keywords internal
#' @noRd
validate_mor_availability <- function(design) {
  # Check trip_status_col exists
  if (is.null(design$trip_status_col)) {
    cli::cli_abort(c(
      "MOR estimator requires trip_status field.",
      "x" = "Design has no trip_status_col set.",
      "i" = "Call {.fn add_interviews} with {.arg trip_status} parameter.",
      "i" = "See {.code ?add_interviews} for trip status specification."
    ))
  }

  # Check trip_status column exists in data
  if (!design$trip_status_col %in% names(design$interviews)) {
    cli::cli_abort(c(
      "trip_status column missing from interview data.",
      "x" = "Expected column: {.val {design$trip_status_col}}",
      "i" = "This is an internal error - please report."
    ))
  }

  # Count incomplete trips
  trip_statuses <- design$interviews[[design$trip_status_col]]
  n_incomplete <- sum(trip_statuses == "incomplete", na.rm = TRUE)
  n_total <- length(trip_statuses) # nolint: object_usage_linter

  # Error if no incomplete trips
  if (n_incomplete == 0) {
    cli::cli_abort(c(
      "MOR estimator requires incomplete trips.",
      "x" = "All {n_total} interviews are complete trips.",
      "i" = "Use {.code estimator = 'ratio-of-means'} for complete trips.",
      "i" = "MOR is only appropriate for incomplete trip interviews."
    ))
  }

  invisible(TRUE)
}

#' Issue warning about MOR estimator assumptions
#'
#' Every MOR estimation call warns user about incomplete trip assumptions
#' and complete trip preference per CONTEXT.md locked decisions.
#'
#' @param n_incomplete Number of incomplete trips
#' @param n_total Total interviews
#'
#' @keywords internal
#' @noRd
mor_estimation_warning <- function(n_incomplete, n_total) {
  cli::cli_warn(c(
    "!" = "MOR estimator for incomplete trips. Complete trips preferred.",
    "i" = "Using MOR with n={n_incomplete} incomplete of {n_total} total interviews.",
    "i" = "Incomplete trips may have length-of-stay bias (Pollock et al.).",
    "i" = "Validate incomplete estimates with {.fn validate_incomplete_trips} (Phase 19)."
  ))
}

#' Validate interview data structure (Tier 1)
#'
#' Internal validator that checks interview data matches the creel_design structure.
#' Verifies that design-critical columns exist in the interview data and contain no
#' NA values. This is Tier 1 validation - structural checks that must pass before
#' constructing a survey design object.
#'
#' @param interviews Data frame containing interview data
#' @param design A creel_design object
#' @param catch_col Character name of catch column in interviews data
#' @param effort_col Character name of effort column in interviews data
#' @param harvest_col Character name of harvest column in interviews data, or NULL
#' @param date_col Character name of date column in interviews data
#' @param allow_invalid Logical flag. If FALSE (default), validation failures
#'   abort with cli error. If TRUE, failures generate warnings instead.
#'
#' @return A creel_validation object with tier = 1L
#'
#' @keywords internal
#' @noRd
validate_interviews_tier1 <- function(interviews, design, catch_col, effort_col,
                                      harvest_col, date_col, allow_invalid = FALSE) {
  collection <- checkmate::makeAssertCollection()

  # Check 1: date_col exists in interviews
  if (!date_col %in% names(interviews)) {
    collection$push(sprintf(
      "Date column '%s' not found in interview data",
      date_col
    ))
  }

  # Check 2: catch_col exists and is numeric
  if (!catch_col %in% names(interviews)) {
    collection$push(sprintf(
      "Catch column '%s' not found in interview data",
      catch_col
    ))
  } else if (!is.numeric(interviews[[catch_col]])) {
    collection$push(sprintf(
      "Catch column '%s' must be numeric, not %s",
      catch_col,
      class(interviews[[catch_col]])[1]
    ))
  }

  # Check 3: effort_col exists and is numeric
  if (!effort_col %in% names(interviews)) {
    collection$push(sprintf(
      "Effort column '%s' not found in interview data",
      effort_col
    ))
  } else if (!is.numeric(interviews[[effort_col]])) {
    collection$push(sprintf(
      "Effort column '%s' must be numeric, not %s",
      effort_col,
      class(interviews[[effort_col]])[1]
    ))
  }

  # Check 4: harvest_col exists and is numeric (only if not NULL)
  if (!is.null(harvest_col)) {
    if (!harvest_col %in% names(interviews)) {
      collection$push(sprintf(
        "Harvest column '%s' not found in interview data",
        harvest_col
      ))
    } else if (!is.numeric(interviews[[harvest_col]])) {
      collection$push(sprintf(
        "Harvest column '%s' must be numeric, not %s",
        harvest_col,
        class(interviews[[harvest_col]])[1]
      ))
    }
  }

  # Check 5: No NA values in date_col
  if (date_col %in% names(interviews)) {
    na_count_date <- sum(is.na(interviews[[date_col]]))
    if (na_count_date > 0) {
      collection$push(sprintf(
        "Date column '%s' contains %d NA value(s)",
        date_col, na_count_date
      ))
    }
  }

  # Check 6: Interview dates all exist in design calendar
  if (date_col %in% names(interviews)) {
    interview_dates <- unique(interviews[[date_col]])
    calendar_dates <- design$calendar[[design$date_col]]
    missing_dates <- setdiff(interview_dates, calendar_dates)
    if (length(missing_dates) > 0) {
      collection$push(sprintf(
        "Interview dates not found in design calendar: %s",
        paste(as.character(missing_dates), collapse = ", ")
      ))
    }
  }

  # Check 7: harvest <= catch consistency (if harvest_col provided)
  harvest_col_present <- !is.null(harvest_col) && harvest_col %in% names(interviews)
  catch_col_present <- catch_col %in% names(interviews)
  if (harvest_col_present && catch_col_present) {
    catch_vals <- interviews[[catch_col]]
    harvest_vals <- interviews[[harvest_col]]
    # Check only non-NA rows
    valid_rows <- !is.na(catch_vals) & !is.na(harvest_vals)
    if (any(valid_rows)) {
      violations <- sum(harvest_vals[valid_rows] > catch_vals[valid_rows])
      if (violations > 0) {
        collection$push(sprintf(
          "Harvest exceeds catch in %d row(s) - harvest must be <= catch",
          violations
        ))
      }
    }
  }

  # Build validation results data frame
  if (!collection$isEmpty()) {
    msgs <- collection$getMessages()
    results <- data.frame(
      check = paste0("check_", seq_along(msgs)),
      status = "fail",
      message = msgs,
      stringsAsFactors = FALSE
    )

    if (!allow_invalid) {
      cli::cli_abort(c(
        "Interview data validation failed (Tier 1):",
        stats::setNames(paste0("{.var ", msgs, "}"), rep("x", length(msgs))),
        "i" = "Interview data must have all design columns with no NA values."
      ))
    } else {
      # Warn but continue
      for (msg in msgs) {
        cli::cli_warn(msg)
      }
    }
  } else {
    # All checks passed
    results <- data.frame(
      check = "all_checks",
      status = "pass",
      message = "All Tier 1 validation checks passed",
      stringsAsFactors = FALSE
    )
  }

  # Return validation object
  new_creel_validation( # nolint: object_usage_linter
    results = results,
    tier = 1L,
    context = "add_interviews validation"
  )
}

#' Validate trip metadata in interview data
#'
#' Internal function that validates trip completion status and duration fields
#' in interview data. Enforces data quality rules for trip_status, trip_duration,
#' trip_start, and interview_time columns.
#'
#' @param interviews Data frame containing interview data
#' @param trip_status_col Character name of trip status column
#' @param trip_duration_col Character name of trip duration column (hours), or NULL
#' @param trip_start_col Character name of trip start time column (POSIXct), or NULL
#' @param interview_time_col Character name of interview time column (POSIXct), or NULL
#'
#' @return invisible(NULL) on success; aborts on validation failure
#'
#' @keywords internal
#' @noRd
validate_trip_metadata <- function(interviews, trip_status_col, trip_duration_col,
                                   trip_start_col, interview_time_col) {
  collection <- checkmate::makeAssertCollection()

  # Check 1: trip_status_col exists in interviews
  if (!trip_status_col %in% names(interviews)) {
    collection$push(sprintf(
      "Trip status column '%s' not found in interview data",
      trip_status_col
    ))
  } else {
    # Check 2: trip_status_col values are valid
    status_vals <- interviews[[trip_status_col]]
    status_vals_lower <- tolower(status_vals)
    valid_statuses <- c("complete", "incomplete")
    invalid_mask <- !is.na(status_vals_lower) & !status_vals_lower %in% valid_statuses
    if (any(invalid_mask)) {
      invalid_vals <- unique(status_vals[invalid_mask])
      collection$push(sprintf(
        "Trip status column '%s' contains invalid value(s): %s. Must be 'complete' or 'incomplete' (case-insensitive)",
        trip_status_col,
        paste(invalid_vals, collapse = ", ")
      ))
    }

    # Check 3: No NA in trip_status
    na_count <- sum(is.na(status_vals))
    if (na_count > 0) {
      collection$push(sprintf(
        "Trip status column '%s' contains %d NA value(s). Trip status is required for all interviews",
        trip_status_col, na_count
      ))
    }
  }

  # Check 4: Mutually exclusive input - error if BOTH trip_duration_col AND (trip_start_col or interview_time_col)
  has_duration <- !is.null(trip_duration_col)
  has_start <- !is.null(trip_start_col)
  has_interview_time <- !is.null(interview_time_col)

  if (has_duration && (has_start || has_interview_time)) {
    collection$push(
      "Provide either trip_duration or trip_start/interview_time, not both"
    )
  }

  # Check 5: trip_start requires interview_time
  if (has_start && !has_interview_time) {
    collection$push(
      "trip_start requires interview_time to calculate duration"
    )
  }

  # Check 6: interview_time requires trip_start
  if (has_interview_time && !has_start) {
    collection$push(
      "interview_time requires trip_start to calculate duration"
    )
  }

  # Check 7: Duration column validation (if trip_duration_col provided)
  if (has_duration) {
    if (!trip_duration_col %in% names(interviews)) {
      collection$push(sprintf(
        "Trip duration column '%s' not found in interview data",
        trip_duration_col
      ))
    } else {
      duration_vals <- interviews[[trip_duration_col]]

      # Must be numeric
      if (!is.numeric(duration_vals)) {
        collection$push(sprintf(
          "Trip duration column '%s' must be numeric, not %s",
          trip_duration_col,
          class(duration_vals)[1]
        ))
      } else {
        # No NA values
        na_count_duration <- sum(is.na(duration_vals))
        if (na_count_duration > 0) {
          collection$push(sprintf(
            "Trip duration column '%s' contains %d NA value(s). Trip duration is required for all interviews",
            trip_duration_col, na_count_duration
          ))
        }

        # No negative values
        if (any(duration_vals < 0, na.rm = TRUE)) {
          collection$push(sprintf(
            "Trip duration column '%s' contains negative values",
            trip_duration_col
          ))
        }

        # No values < 1/60 hours (1 minute)
        min_duration <- 1 / 60
        if (any(duration_vals < min_duration & duration_vals >= 0, na.rm = TRUE)) {
          collection$push(sprintf( # nolint: line_length_linter
            paste(
              "Trip duration column '%s' contains values less than 1 minute (1/60 hours).",
              "Trip durations less than 1 minute are unrealistic"
            ),
            trip_duration_col
          ))
        }

        # Warn if any values > 48 hours
        if (any(duration_vals > 48, na.rm = TRUE)) {
          n_long <- sum(duration_vals > 48, na.rm = TRUE) # nolint: object_usage_linter
          cli::cli_warn(c( # nolint: line_length_linter
            "!" = "Trip duration column '{trip_duration_col}' contains {n_long} value{?s} > 48 hours",
            "i" = "Multi-day trips are valid, but verify these are not data entry errors"
          ))
        }
      }
    }
  }

  # Check 8: Time column validation (if trip_start_col and interview_time_col provided)
  if (has_start && has_interview_time) {
    # Check trip_start_col exists
    if (!trip_start_col %in% names(interviews)) {
      collection$push(sprintf(
        "Trip start column '%s' not found in interview data",
        trip_start_col
      ))
    } else {
      start_vals <- interviews[[trip_start_col]]

      # Must be POSIXct or POSIXlt
      if (!inherits(start_vals, "POSIXct") && !inherits(start_vals, "POSIXlt")) {
        collection$push(sprintf(
          "Trip start column '%s' must be POSIXct or POSIXlt, not %s",
          trip_start_col,
          class(start_vals)[1]
        ))
      }

      # No NA values
      na_count_start <- sum(is.na(start_vals))
      if (na_count_start > 0) {
        collection$push(sprintf(
          "Trip start column '%s' contains %d NA value(s)",
          trip_start_col, na_count_start
        ))
      }
    }

    # Check interview_time_col exists
    if (!interview_time_col %in% names(interviews)) {
      collection$push(sprintf(
        "Interview time column '%s' not found in interview data",
        interview_time_col
      ))
    } else {
      interview_vals <- interviews[[interview_time_col]]

      # Must be POSIXct or POSIXlt
      if (!inherits(interview_vals, "POSIXct") && !inherits(interview_vals, "POSIXlt")) {
        collection$push(sprintf(
          "Interview time column '%s' must be POSIXct or POSIXlt, not %s",
          interview_time_col,
          class(interview_vals)[1]
        ))
      }

      # No NA values
      na_count_interview <- sum(is.na(interview_vals))
      if (na_count_interview > 0) {
        collection$push(sprintf(
          "Interview time column '%s' contains %d NA value(s)",
          interview_time_col, na_count_interview
        ))
      }
    }

    # If both columns exist and are time-like, check computed duration
    if (trip_start_col %in% names(interviews) && # nolint: indentation_linter
      interview_time_col %in% names(interviews)) { # nolint: indentation_linter
      start_vals <- interviews[[trip_start_col]]
      interview_vals <- interviews[[interview_time_col]]

      if ((inherits(start_vals, "POSIXct") || inherits(start_vals, "POSIXlt")) && # nolint: indentation_linter
        (inherits(interview_vals, "POSIXct") || inherits(interview_vals, "POSIXlt"))) { # nolint: indentation_linter
        # Check timezone consistency
        tz_start <- attr(start_vals, "tzone")
        tz_interview <- attr(interview_vals, "tzone")
        # Only error if both explicitly set to different timezones
        if (!is.null(tz_start) && !is.null(tz_interview) && # nolint: indentation_linter
          nzchar(tz_start) && nzchar(tz_interview) && # nolint: indentation_linter
          tz_start != tz_interview) {
          collection$push(sprintf( # nolint: line_length_linter
            "trip_start timezone '%s' differs from interview_time timezone '%s'. Use the same timezone for both columns", # nolint: line_length_linter
            tz_start, tz_interview
          ))
        }

        # Calculate duration in hours
        computed_duration <- as.numeric(
          difftime(interview_vals, start_vals, units = "hours")
        )

        # No negative durations
        if (any(computed_duration < 0, na.rm = TRUE)) {
          collection$push(sprintf(
            paste(
              "Computed duration (interview_time - trip_start) is negative for some interviews.",
              "Check that interview_time > trip_start"
            )
          ))
        }

        # No durations < 1 minute
        min_duration <- 1 / 60
        if (any(computed_duration < min_duration & computed_duration >= 0, na.rm = TRUE)) {
          collection$push(sprintf(
            paste(
              "Computed duration (interview_time - trip_start) is less than 1 minute",
              "for some interviews. This is unrealistic"
            )
          ))
        }

        # Warn if any > 48 hours
        if (any(computed_duration > 48, na.rm = TRUE)) {
          n_long <- sum(computed_duration > 48, na.rm = TRUE) # nolint: object_usage_linter
          cli::cli_warn(c( # nolint: line_length_linter
            "!" = "Computed duration (interview_time - trip_start) > 48 hours for {n_long} interview{?s}",
            "i" = "Multi-day trips are valid, but verify these are not data entry errors"
          ))
        }
      }
    }
  }

  # Abort if any validation errors
  if (!collection$isEmpty()) {
    msgs <- collection$getMessages()
    cli::cli_abort(c(
      "Trip metadata validation failed:",
      stats::setNames(paste0("{.var ", msgs, "}"), rep("x", length(msgs)))
    ))
  }

  invisible(NULL)
}

#' Construct interview survey design object
#'
#' Internal function that wraps survey::svydesign() for interview data with
#' domain-specific error handling. Constructs a stratified survey design from
#' interview data using terminal sampling units (ids = ~1) since interviews
#' are individual observations, not clustered by day.
#'
#' For multiple strata columns, creates an interaction variable to combine them
#' into a single stratification factor before passing to svydesign.
#'
#' @param design A creel_design object with $interviews already populated
#'
#' @return An object of class "survey.design2" (from survey::svydesign)
#'
#' @keywords internal
#' @noRd
construct_interview_survey <- function(design) {
  interviews_data <- design$interviews
  strata_cols <- design$strata_cols

  # Create strata variable
  if (length(strata_cols) == 1) {
    # Single stratum - use directly
    interviews_data$.strata <- interviews_data[[strata_cols]]
  } else {
    # Multiple strata - create interaction
    strata_factors <- interviews_data[strata_cols]
    interviews_data$.strata <- interaction(strata_factors, drop = TRUE)
  }

  # Build formulas - use ~1 for ids (terminal sampling units)
  strata_formula <- stats::reformulate(".strata")

  # Attempt to construct survey design with error wrapping
  tryCatch(
    {
      build_interview_survey(interviews_data, strata = strata_formula)
    },
    error = function(e) {
      # Detect specific error types and provide domain guidance
      err_msg <- conditionMessage(e)

      if (grepl("Stratum.*has only one PSU", err_msg, ignore.case = TRUE)) {
        # Lonely PSU error (less likely for interviews but handle it)
        cli::cli_abort(
          c(
            "Interview survey construction failed: lonely PSU detected.",
            "x" = paste(
              "At least one stratum has only one observation.",
              "Variance estimation requires 2+ observations per stratum."
            ),
            "i" = "Possible solutions:",
            "*" = "Combine small strata with similar characteristics",
            "*" = "Use a different stratification scheme",
            "*" = "Collect more interview observations in sparse strata"
          ),
          class = "creel_error_single_psu"
        )
      } else if (grepl("variable.*not found", err_msg, ignore.case = TRUE)) {
        # Column not found
        required_cols <- strata_cols # nolint: object_usage_linter
        cli::cli_abort(c(
          "Interview survey construction failed: missing column.",
          "x" = err_msg,
          "i" = "Required columns: {.field {required_cols}}"
        ))
      } else {
        # Generic survey error - wrap with guidance
        cli::cli_abort(c(
          "Interview survey construction failed.",
          "x" = err_msg,
          "i" = paste(
            "Check that interview data has correct structure for",
            "strata columns {.field {strata_cols}}."
          )
        ))
      }
    }
  )
}

#' Validate design compatibility for total catch/harvest estimation
#'
#' Checks that design has both count data (for effort) and interview data
#' (for CPUE/HPUE) required to compute total catch/harvest as effort × rate.
#'
#' @param design A creel_design object
#'
#' @return NULL (invisible) - function called for side effects (errors)
#'
#' @keywords internal
#' @noRd
validate_design_compatibility <- function(design) {
  # Check count data exists
  if (is.null(design$counts) || is.null(design$survey)) {
    cli::cli_abort(c(
      "No count data available for effort estimation.",
      "x" = "Total catch/harvest requires both effort (from counts) and catch rates (from interviews).",
      "i" = "Call {.fn add_counts} before estimating total catch or harvest:",
      "i" = "{.code design <- add_counts(design, count_data)}"
    ))
  }

  # Check interview data exists
  if (is.null(design$interviews) || is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview data available for catch rate estimation.",
      "x" = "Total catch/harvest requires both effort (from counts) and catch rates (from interviews).",
      "i" = "Call {.fn add_interviews} before estimating total catch or harvest:",
      "i" = "{.code design <- add_interviews(design, interviews, catch = catch, effort = effort)}"
    ))
  }

  invisible(NULL)
}

#' Validate grouping variable compatibility for total catch/harvest
#'
#' Checks that grouping variables specified in by parameter exist in both
#' count data (for effort) and interview data (for CPUE/HPUE), enabling grouped
#' total catch/harvest estimation.
#'
#' @param design A creel_design object
#' @param by_vars Character vector of grouping variable names
#'
#' @return NULL (invisible) - function called for side effects (errors)
#'
#' @keywords internal
#' @noRd
validate_grouping_compatibility <- function(design, by_vars) { # nolint: object_length_linter
  # Check grouping variables exist in count data
  missing_in_counts <- setdiff(by_vars, names(design$counts))
  if (length(missing_in_counts) > 0) {
    n_missing_counts <- length(missing_in_counts) # nolint: object_usage_linter
    cli::cli_abort(c(
      "{n_missing_counts} grouping variable{?s} not found in count data:",
      "x" = "Missing: {.val {missing_in_counts}}",
      "i" = "Available in counts: {.val {names(design$counts)}}",
      "i" = "Grouped total estimation requires variables present in both counts and interviews"
    ))
  }

  # Check grouping variables exist in interview data
  missing_in_interviews <- setdiff(by_vars, names(design$interviews))
  if (length(missing_in_interviews) > 0) {
    n_missing_interviews <- length(missing_in_interviews) # nolint: object_usage_linter
    cli::cli_abort(c(
      "{n_missing_interviews} grouping variable{?s} not found in interview data:",
      "x" = "Missing: {.val {missing_in_interviews}}",
      "i" = "Available in interviews: {.val {names(design$interviews)}}",
      "i" = "Grouped total estimation requires variables present in both counts and interviews"
    ))
  }

  invisible(NULL)
}

#' Issue truncation message for MOR estimation
#'
#' @param n_truncated Number of trips excluded by truncation
#' @param n_incomplete_original Original incomplete trip count (before truncation)
#' @param truncate_at Threshold used (hours)
#'
#' @importFrom scales percent
#'
#' @keywords internal
#' @noRd
mor_truncation_message <- function(n_truncated, n_incomplete_original, truncate_at) {
  pct_truncated <- n_truncated / n_incomplete_original

  if (n_truncated == 0) {
    # No trips truncated - informative message
    cli::cli_inform(c(
      "i" = "MOR truncation: 0 trips excluded (all >= {truncate_at} hours)"
    ))
  } else if (pct_truncated > 0.10) {
    # >10% truncated - data quality warning
    cli::cli_warn(c(
      "!" = "MOR truncation: {n_truncated} trip{?s} excluded ({scales::percent(pct_truncated, accuracy = 0.1)})",
      "i" = "Trips < {truncate_at} hours excluded to prevent unstable variance",
      "!" = "High truncation rate may indicate data quality issues",
      "i" = "Consider reviewing trip duration data for errors"
    ))
  } else {
    # Normal truncation - informative message
    cli::cli_inform(c(
      "i" = "MOR truncation: {n_truncated} trip{?s} excluded (< {truncate_at} hours)"
    ))
  }
}

#' Warn when complete trip percentage is below threshold
#'
#' Internal function that issues a warning when the percentage of complete trips
#' is below the recommended threshold following Pollock et al. roving-access
#' design best practices. Alerts users to insufficient complete trip samples
#' for scientifically valid estimation.
#'
#' The threshold is controlled by the package option tidycreel.min_complete_pct
#' (default 0.10 = 10%). Users can set a custom threshold for their session:
#' options(tidycreel.min_complete_pct = 0.05)
#'
#' @param n_complete Number of complete trips (integer)
#' @param n_total Total number of interviews (integer)
#' @param threshold Minimum percentage threshold for complete trips (numeric).
#'   If NULL (default), uses getOption("tidycreel.min_complete_pct", 0.10)
#'
#' @return NULL (invisible) - function called for side effects (warnings)
#'
#' @keywords internal
#' @noRd
warn_low_complete_pct <- function(n_complete, n_total, threshold = NULL) {
  # Handle edge case: n_total = 0
  if (n_total == 0) {
    return(invisible(NULL))
  }

  # Get threshold from package option if not provided
  if (is.null(threshold)) {
    threshold <- getOption("tidycreel.min_complete_pct", default = 0.10)
  }

  # Calculate percentage complete
  pct_complete <- n_complete / n_total

  # Skip if percentage meets threshold
  if (pct_complete >= threshold) {
    return(invisible(NULL))
  }

  # Format percentages for display
  pct_complete_display <- sprintf("%.1f", pct_complete * 100) # nolint: object_usage_linter
  threshold_display <- sprintf("%.0f", threshold * 100) # nolint: object_usage_linter

  # Issue warning with scientific rationale and guidance
  cli::cli_warn(c(
    "!" = "Only {pct_complete_display}% of interviews are complete trips (threshold: {threshold_display}%)",
    "i" = "Pollock et al. recommends >=10% complete trips for valid estimation",
    "i" = "Consider use_trips='diagnostic' to validate incomplete trip estimates"
  ))

  invisible(NULL)
}
