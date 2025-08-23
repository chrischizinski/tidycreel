#' Run All Schema Validation Functions
#'
#' This function runs all available schema validation functions on a named list of tibbles.
#' It returns a list of results (invisible if all pass, errors if any fail).
#' @param data_list Named list of tibbles: names must match schema types (calendar, interviews, counts, auxiliary, reference)
#' @param strict Logical, if TRUE throws error on validation failure
#' @return Invisibly returns validated data, or errors if invalid
#' @examples
#' schema_test_runner(list(
#'   calendar = calendar_tbl,
#'   interviews = interviews_tbl,
#'   counts = counts_tbl,
#'   auxiliary = auxiliary_tbl,
#'   reference = reference_tbl
#' ))
#' @export
schema_test_runner <- function(data_list, strict = TRUE) {
  stopifnot(is.list(data_list))
  results <- list()
  if (!is.null(data_list$calendar)) {
    results$calendar <- validate_calendar(data_list$calendar, strict = strict)
  }
  if (!is.null(data_list$interviews)) {
    results$interviews <- validate_interviews(data_list$interviews, strict = strict)
  }
  if (!is.null(data_list$counts)) {
    results$counts <- validate_counts(data_list$counts, strict = strict)
  }
  if (!is.null(data_list$auxiliary)) {
    results$auxiliary <- validate_auxiliary(data_list$auxiliary, strict = strict)
  }
  if (!is.null(data_list$reference)) {
    results$reference <- validate_reference(data_list$reference, strict = strict)
  }
  invisible(results)
}
