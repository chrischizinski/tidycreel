# Exported escape hatch ----

#' Extract internal survey design object for advanced use
#'
#' @description
#' Provides power users with direct access to the internal survey.design2 object
#' for advanced analysis using survey package functions. This is an escape hatch
#' for workflows not yet wrapped by tidycreel. Most users should use
#' \code{estimate_effort()} instead (available in future phase).
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
