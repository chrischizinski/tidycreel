#' Create Bus Route Survey Design
#'
#' Constructs a survey design object for bus route creel surveys, where surveyors follow a fixed route and sample anglers at multiple locations/times. This design accounts for unequal probability sampling and route-based coverage.
#'
#' @param interviews A tibble containing interview data validated by validate_interviews().
#' @param counts A tibble containing count data validated by validate_counts().
#' @param calendar A tibble containing calendar data validated by validate_calendar().
#' @param route_schedule A tibble describing the bus route schedule (stop, time, expected coverage).
#' @param strata_vars Character vector of variables to use for stratification. Default is c("date", "location").
#' @param weight_method Character specifying weight calculation method. Options: "standard", "unequal_prob", "calibrate".
#' @return A list object of class "busroute_design" and "creel_design".
#' @export
#'
#' @examples
#' # design_busroute(interviews, counts, calendar, route_schedule)
design_busroute <- function(interviews, counts, calendar, route_schedule,
                           strata_vars = c("date", "location"),
                           weight_method = "unequal_prob") {
  # Validate inputs
  interviews <- validate_interviews(interviews)
  counts <- validate_counts(counts)
  calendar <- validate_calendar(calendar)
  # Validate route_schedule
  stopifnot(is.data.frame(route_schedule))
  required_route_cols <- c("route_stop", "time", "expected_coverage")
  missing_cols <- setdiff(required_route_cols, names(route_schedule))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns in route_schedule:", paste(missing_cols, collapse = ", ")))
  }
  # Calculate design weights (placeholder, should use survey::svydesign with unequal probabilities)
  # For now, assign weights based on expected_coverage
  # Merge interviews with route_schedule to get probabilities
  interviews <- dplyr::left_join(interviews, route_schedule, by = c("location" = "route_stop"))

  # Derive selection probability from expected coverage; clamp to (0,1]
  if (!"expected_coverage" %in% names(interviews)) {
    stop("'expected_coverage' must be present after joining route_schedule; check join keys and route_schedule columns.")
  }
  interviews$probability <- pmin(pmax(interviews$expected_coverage, .Machine$double.eps), 1)
  interviews$design_weights <- 1 / interviews$probability

  # Build survey design object (unequal probability via weights)
  svy_design <- survey::svydesign(
    ids = ~1,
    strata = stats::as.formula(paste("~", paste(strata_vars, collapse = "+"))),
    weights = ~design_weights,
    data = interviews
  )

  # Create design object
  design <- list(
    design_type = "busroute",
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    route_schedule = route_schedule,
    strata_vars = strata_vars,
    weight_method = weight_method,
    svy_design = svy_design,
    metadata = list(
      creation_time = Sys.time(),
      package_version = utils::packageVersion("tidycreel")
    )
  )
  class(design) <- c("busroute_design", "creel_design", "list")
  return(design)
}
