# Internal survey bridge functions ----

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
