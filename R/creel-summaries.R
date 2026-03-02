# Interview-level unextrapolated summary functions (Phase 31, USUM-01 through USUM-08).
# All functions follow the three-guard pattern from creel-design.R.
# All return data.frame with class c("creel_summary_<type>", "data.frame").
# All percent values are rounded to 1 decimal; N columns are integer.
# Base R only: table(), aggregate(), merge(), cut(), format(). No dplyr.


#' Tabulate refused vs accepted interviews by month
#'
#' Counts the number of refused and accepted interviews in each calendar
#' month. Refusals are recorded as \code{TRUE} in the refused column set
#' via \code{\link{add_interviews}}.
#'
#' @param design A \code{creel_design} object with interviews attached and
#'   \code{refused} column set via \code{add_interviews(refused = ...)}.
#'
#' @return A \code{data.frame} with class \code{c("creel_summary_refusals",
#'   "data.frame")} and columns: \code{month} (full month name),
#'   \code{participation} ("accepted" or "refused"), \code{N} (integer count),
#'   \code{percent} (numeric, rounded to 1 decimal, percent within month).
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, refused = refused
#' )
#' summarize_refusals(d)
#' }
#'
#' @export
summarize_refusals <- function(design) {
  # Guard 1: type check
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Guard 2: interviews attached
  if (is.null(design$interviews)) {
    cli::cli_abort(c(
      "No interviews found in design.",
      "x" = "The design object has no interview data.",
      "i" = "Attach interviews with {.fn add_interviews}."
    ))
  }

  # Guard 3: refused column
  if (is.null(design$refused_col)) {
    cli::cli_abort(c(
      "No refused column found in design.",
      "x" = "Did you provide {.arg refused} in {.fn add_interviews}?"
    ))
  }

  refused_vals <- design$interviews[[design$refused_col]]
  participation <- ifelse(refused_vals, "refused", "accepted")

  dates <- design$interviews[[design$date_col]]
  month_chr <- format(dates, "%B")
  month_num <- format(dates, "%m")

  counts <- as.data.frame(
    table(month = month_chr, participation = participation),
    stringsAsFactors = FALSE
  )
  names(counts)[names(counts) == "Freq"] <- "N"
  counts$N <- as.integer(counts$N)

  sort_map <- unique(data.frame(
    month = month_chr, sort = month_num,
    stringsAsFactors = FALSE
  ))
  counts <- merge(counts, sort_map, by = "month")

  month_totals <- stats::aggregate(
    counts$N,
    by = list(month = counts$month), FUN = sum
  )
  names(month_totals)[2] <- "month_total"
  counts <- merge(counts, month_totals, by = "month")
  counts$percent <- round(100 * counts$N / counts$month_total, 1)

  counts <- counts[order(counts$sort, counts$participation), ]
  counts$sort <- NULL
  counts$month_total <- NULL
  row.names(counts) <- NULL

  class(counts) <- c("creel_summary_refusals", "data.frame")
  counts
}


#' Tabulate interviews by day type and month
#'
#' Counts the number of interviews in each day type stratum (e.g., weekday,
#' weekend) within each calendar month. Day type is taken from the first
#' strata column (\code{design$strata_cols[1]}), which is always present
#' after \code{\link{creel_design}} is called.
#'
#' @param design A \code{creel_design} object with interviews attached.
#'
#' @return A \code{data.frame} with class \code{c("creel_summary_day_type",
#'   "data.frame")} and columns: \code{month}, \code{day_type}, \code{N},
#'   \code{percent}.
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' summarize_by_day_type(d)
#' }
#'
#' @export
summarize_by_day_type <- function(design) {
  # Guard 1: type check
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Guard 2: interviews attached
  if (is.null(design$interviews)) {
    cli::cli_abort(c(
      "No interviews found in design.",
      "x" = "The design object has no interview data.",
      "i" = "Attach interviews with {.fn add_interviews}."
    ))
  }

  # No Guard 3 — strata_cols always set by creel_design()
  strata_col <- design$strata_cols[1]
  day_type_vals <- design$interviews[[strata_col]]

  dates <- design$interviews[[design$date_col]]
  month_chr <- format(dates, "%B")
  month_num <- format(dates, "%m")

  counts <- as.data.frame(
    table(month = month_chr, day_type = day_type_vals),
    stringsAsFactors = FALSE
  )
  names(counts)[names(counts) == "Freq"] <- "N"
  counts$N <- as.integer(counts$N)

  sort_map <- unique(data.frame(
    month = month_chr, sort = month_num,
    stringsAsFactors = FALSE
  ))
  counts <- merge(counts, sort_map, by = "month")

  month_totals <- stats::aggregate(
    counts$N,
    by = list(month = counts$month), FUN = sum
  )
  names(month_totals)[2] <- "month_total"
  counts <- merge(counts, month_totals, by = "month")
  counts$percent <- round(100 * counts$N / counts$month_total, 1)

  counts <- counts[order(counts$sort, counts$day_type), ]
  counts$sort <- NULL
  counts$month_total <- NULL
  row.names(counts) <- NULL

  class(counts) <- c("creel_summary_day_type", "data.frame")
  counts
}


#' Tabulate interviews by angler type and month
#'
#' Counts the number of interviews for each angler type within each calendar
#' month. Angler type is taken from the column set via
#' \code{add_interviews(angler_type = ...)}.
#'
#' @param design A \code{creel_design} object with interviews attached and
#'   \code{angler_type} column set via \code{add_interviews(angler_type = ...)}.
#'
#' @return A \code{data.frame} with class \code{c("creel_summary_angler_type",
#'   "data.frame")} and columns: \code{month}, \code{angler_type}, \code{N},
#'   \code{percent}.
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, angler_type = angler_type
#' )
#' summarize_by_angler_type(d)
#' }
#'
#' @export
summarize_by_angler_type <- function(design) {
  # Guard 1: type check
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Guard 2: interviews attached
  if (is.null(design$interviews)) {
    cli::cli_abort(c(
      "No interviews found in design.",
      "x" = "The design object has no interview data.",
      "i" = "Attach interviews with {.fn add_interviews}."
    ))
  }

  # Guard 3: angler_type column
  if (is.null(design$angler_type_col)) {
    cli::cli_abort(c(
      "No angler_type column found in design.",
      "x" = "Did you provide {.arg angler_type} in {.fn add_interviews}?"
    ))
  }

  angler_type_vals <- design$interviews[[design$angler_type_col]]

  dates <- design$interviews[[design$date_col]]
  month_chr <- format(dates, "%B")
  month_num <- format(dates, "%m")

  counts <- as.data.frame(
    table(month = month_chr, angler_type = angler_type_vals),
    stringsAsFactors = FALSE
  )
  names(counts)[names(counts) == "Freq"] <- "N"
  counts$N <- as.integer(counts$N)

  sort_map <- unique(data.frame(
    month = month_chr, sort = month_num,
    stringsAsFactors = FALSE
  ))
  counts <- merge(counts, sort_map, by = "month")

  month_totals <- stats::aggregate(
    counts$N,
    by = list(month = counts$month), FUN = sum
  )
  names(month_totals)[2] <- "month_total"
  counts <- merge(counts, month_totals, by = "month")
  counts$percent <- round(100 * counts$N / counts$month_total, 1)

  counts <- counts[order(counts$sort, counts$angler_type), ]
  counts$sort <- NULL
  counts$month_total <- NULL
  row.names(counts) <- NULL

  class(counts) <- c("creel_summary_angler_type", "data.frame")
  counts
}


#' Tabulate interviews by fishing method and month
#'
#' Counts the number of interviews for each fishing method within each calendar
#' month. Method is taken from the column set via
#' \code{add_interviews(angler_method = ...)}.
#'
#' @param design A \code{creel_design} object with interviews attached and
#'   \code{angler_method} column set via
#'   \code{add_interviews(angler_method = ...)}.
#'
#' @return A \code{data.frame} with class \code{c("creel_summary_method",
#'   "data.frame")} and columns: \code{month}, \code{method}, \code{N},
#'   \code{percent}.
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, angler_method = angler_method
#' )
#' summarize_by_method(d)
#' }
#'
#' @export
summarize_by_method <- function(design) {
  # Guard 1: type check
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Guard 2: interviews attached
  if (is.null(design$interviews)) {
    cli::cli_abort(c(
      "No interviews found in design.",
      "x" = "The design object has no interview data.",
      "i" = "Attach interviews with {.fn add_interviews}."
    ))
  }

  # Guard 3: angler_method column
  if (is.null(design$angler_method_col)) {
    cli::cli_abort(c(
      "No angler_method column found in design.",
      "x" = "Did you provide {.arg angler_method} in {.fn add_interviews}?"
    ))
  }

  method_vals <- design$interviews[[design$angler_method_col]]

  dates <- design$interviews[[design$date_col]]
  month_chr <- format(dates, "%B")
  month_num <- format(dates, "%m")

  counts <- as.data.frame(
    table(month = month_chr, method = method_vals),
    stringsAsFactors = FALSE
  )
  names(counts)[names(counts) == "Freq"] <- "N"
  counts$N <- as.integer(counts$N)

  sort_map <- unique(data.frame(
    month = month_chr, sort = month_num,
    stringsAsFactors = FALSE
  ))
  counts <- merge(counts, sort_map, by = "month")

  month_totals <- stats::aggregate(
    counts$N,
    by = list(month = counts$month), FUN = sum
  )
  names(month_totals)[2] <- "month_total"
  counts <- merge(counts, month_totals, by = "month")
  counts$percent <- round(100 * counts$N / counts$month_total, 1)

  counts <- counts[order(counts$sort, counts$method), ]
  counts$sort <- NULL
  counts$month_total <- NULL
  row.names(counts) <- NULL

  class(counts) <- c("creel_summary_method", "data.frame")
  counts
}


#' Tabulate interviews by species sought and month
#'
#' Counts the number of interviews for each species sought within each calendar
#' month. Species sought is taken from the column set via
#' \code{add_interviews(species_sought = ...)}.
#'
#' @param design A \code{creel_design} object with interviews attached and
#'   \code{species_sought} column set via
#'   \code{add_interviews(species_sought = ...)}.
#'
#' @return A \code{data.frame} with class \code{c("creel_summary_species_sought",
#'   "data.frame")} and columns: \code{month}, \code{species}, \code{N},
#'   \code{percent}.
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, species_sought = species_sought
#' )
#' summarize_by_species_sought(d)
#' }
#'
#' @export
summarize_by_species_sought <- function(design) {
  # Guard 1: type check
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Guard 2: interviews attached
  if (is.null(design$interviews)) {
    cli::cli_abort(c(
      "No interviews found in design.",
      "x" = "The design object has no interview data.",
      "i" = "Attach interviews with {.fn add_interviews}."
    ))
  }

  # Guard 3: species_sought column
  if (is.null(design$species_sought_col)) {
    cli::cli_abort(c(
      "No species_sought column found in design.",
      "x" = "Did you provide {.arg species_sought} in {.fn add_interviews}?"
    ))
  }

  species_vals <- design$interviews[[design$species_sought_col]]

  dates <- design$interviews[[design$date_col]]
  month_chr <- format(dates, "%B")
  month_num <- format(dates, "%m")

  counts <- as.data.frame(
    table(month = month_chr, species = species_vals),
    stringsAsFactors = FALSE
  )
  names(counts)[names(counts) == "Freq"] <- "N"
  counts$N <- as.integer(counts$N)

  sort_map <- unique(data.frame(
    month = month_chr, sort = month_num,
    stringsAsFactors = FALSE
  ))
  counts <- merge(counts, sort_map, by = "month")

  month_totals <- stats::aggregate(
    counts$N,
    by = list(month = counts$month), FUN = sum
  )
  names(month_totals)[2] <- "month_total"
  counts <- merge(counts, month_totals, by = "month")
  counts$percent <- round(100 * counts$N / counts$month_total, 1)

  counts <- counts[order(counts$sort, counts$species), ]
  counts$sort <- NULL
  counts$month_total <- NULL
  row.names(counts) <- NULL

  class(counts) <- c("creel_summary_species_sought", "data.frame")
  counts
}
