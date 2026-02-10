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
    suppressWarnings(
      survey::as.svrepdesign(design, type = "auto")
    )
  }
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
        cli::cli_abort(c(
          "Survey design construction failed: lonely PSU detected.",
          "x" = paste(
            "At least one stratum has only one PSU (Primary Sampling Unit).",
            "Variance estimation requires 2+ PSUs per stratum."
          ),
          "i" = "Possible solutions:",
          "*" = "Combine small strata with similar characteristics",
          "*" = "Use a different stratification scheme",
          "*" = "Collect data from more PSUs (days) in sparse strata"
        ))
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
  if (!is.null(harvest_col) &&
        catch_col %in% names(interviews) &&
        harvest_col %in% names(interviews)) {
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
      survey::svydesign(
        ids = ~1,
        strata = strata_formula,
        data = interviews_data
      )
    },
    error = function(e) {
      # Detect specific error types and provide domain guidance
      err_msg <- conditionMessage(e)

      if (grepl("Stratum.*has only one PSU", err_msg, ignore.case = TRUE)) {
        # Lonely PSU error (less likely for interviews but handle it)
        cli::cli_abort(c(
          "Interview survey construction failed: lonely PSU detected.",
          "x" = paste(
            "At least one stratum has only one observation.",
            "Variance estimation requires 2+ observations per stratum."
          ),
          "i" = "Possible solutions:",
          "*" = "Combine small strata with similar characteristics",
          "*" = "Use a different stratification scheme",
          "*" = "Collect more interview observations in sparse strata"
        ))
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
