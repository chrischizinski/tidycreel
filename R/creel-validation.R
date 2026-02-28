# creel_validation S3 class ----

#' Create a creel_validation object
#'
#' Internal constructor for validation results. Creates an S3 object containing
#' validation check results with pass/fail status, organized by tier and context.
#' The passed flag is computed automatically based on whether all checks pass.
#'
#' @param results Data frame with columns: check (character), status (character:
#'   "pass" or "fail" or "warn"), message (character)
#' @param tier Integer validation tier (1, 2, or 3)
#' @param context Character string describing validation context (e.g.,
#'   "creel_design creation", "effort estimation")
#'
#' @return List of class "creel_validation" with components:
#'   - results: data frame of validation checks
#'   - tier: validation tier
#'   - context: validation context
#'   - passed: logical flag (TRUE if all checks pass, FALSE otherwise)
#'
#' @keywords internal
#' @noRd
new_creel_validation <- function(results, tier, context) {
  # Input validation
  stopifnot(
    "results must be a data.frame" = is.data.frame(results),
    "tier must be integer" = is.integer(tier) && length(tier) == 1,
    "context must be character" = is.character(context) && length(context) == 1
  )

  # Compute passed flag - only "pass" status counts as passed
  passed <- all(results$status == "pass")

  structure(
    list(
      results = results,
      tier = tier,
      context = context,
      passed = passed
    ),
    class = "creel_validation"
  )
}

#' Format creel_validation for printing
#'
#' @param x A creel_validation object
#' @param ... Additional arguments (currently ignored)
#'
#' @return Character vector with formatted output
#'
#' @export
format.creel_validation <- function(x, ...) {
  # Build formatted output using cli
  output <- character()

  output <- c(output, cli::cli_format_method({
    cli::cli_h1("Validation Results")
    cli::cli_text("Context: {x$context}")
    cli::cli_text("Tier: {x$tier}")

    # Status with styling
    if (x$passed) {
      cli::cli_text("Status: {.emph PASSED}")
    } else {
      cli::cli_text("Status: {.emph FAILED}")
    }

    cli::cli_text("")
    cli::cli_text("Checks:")

    # List individual checks with status indicators
    for (i in seq_len(nrow(x$results))) {
      check_name <- x$results$check[i] # nolint: object_usage_linter
      check_status <- x$results$status[i]
      check_msg <- x$results$message[i] # nolint: object_usage_linter

      if (check_status == "pass") {
        cli::cli_alert_success("{check_name}: {check_msg}")
      } else if (check_status == "fail") {
        cli::cli_alert_danger("{check_name}: {check_msg}")
      } else if (check_status == "warn") {
        cli::cli_alert_warning("{check_name}: {check_msg}")
      }
    }
  }))

  output
}

#' Print creel_validation
#'
#' @param x A creel_validation object
#' @param ... Additional arguments passed to format
#'
#' @return The input object, invisibly
#'
#' @export
print.creel_validation <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
