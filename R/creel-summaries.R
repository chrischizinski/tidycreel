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
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' tabulates raw interview records without applying survey weighting by sampling
#' effort or effort stratum. For pressure-weighted extrapolated estimates, use
#' \code{\link{estimate_cpue}} or \code{\link{estimate_harvest}}.
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
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' tabulates raw interview records without applying survey weighting by sampling
#' effort or effort stratum. For pressure-weighted extrapolated estimates, use
#' \code{\link{estimate_cpue}} or \code{\link{estimate_harvest}}.
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
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' tabulates raw interview records without applying survey weighting by sampling
#' effort or effort stratum. For pressure-weighted extrapolated estimates, use
#' \code{\link{estimate_cpue}} or \code{\link{estimate_harvest}}.
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
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' tabulates raw interview records without applying survey weighting by sampling
#' effort or effort stratum. For pressure-weighted extrapolated estimates, use
#' \code{\link{estimate_cpue}} or \code{\link{estimate_harvest}}.
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
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' tabulates raw interview records without applying survey weighting by sampling
#' effort or effort stratum. For pressure-weighted extrapolated estimates, use
#' \code{\link{estimate_cpue}} or \code{\link{estimate_harvest}}.
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


#' Tabulate successful parties by angler type and species sought
#'
#' A party is "successful" if any row in the attached catch data has
#' \code{catch_type == "caught"} and \code{count > 0} for the species the
#' party was seeking (\code{species_sought}). Returns counts of successful
#' and total parties for each angler type x species sought combination.
#'
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' tabulates raw interview records without applying survey weighting by sampling
#' effort or effort stratum. For pressure-weighted extrapolated estimates, use
#' \code{\link{estimate_cpue}} or \code{\link{estimate_harvest}}.
#'
#' @param design A \code{creel_design} object with interviews attached
#'   (including \code{angler_type} and \code{species_sought} columns) and
#'   catch data attached via \code{\link{add_catch}}.
#'
#' @return A \code{data.frame} with class
#'   \code{c("creel_summary_successful_parties", "data.frame")} and columns:
#'   \code{angler_type}, \code{species_sought}, \code{N_successful} (integer),
#'   \code{N_total} (integer), \code{percent} (numeric, 1 decimal).
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' data(example_catch)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, angler_type = angler_type,
#'   species_sought = species_sought
#' )
#' d <- add_catch(d, example_catch,
#'   catch_uid = interview_id, interview_uid = interview_id,
#'   species = species, count = count, catch_type = catch_type
#' )
#' summarize_successful_parties(d)
#' }
#'
#' @export
summarize_successful_parties <- function(design) {
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

  # Guard 3a: angler_type column
  if (is.null(design$angler_type_col)) {
    cli::cli_abort(c(
      "No angler_type column found in design.",
      "x" = "Did you provide {.arg angler_type} in {.fn add_interviews}?"
    ))
  }

  # Guard 3b: species_sought column
  if (is.null(design$species_sought_col)) {
    cli::cli_abort(c(
      "No species_sought column found in design.",
      "x" = "Did you provide {.arg species_sought} in {.fn add_interviews}?"
    ))
  }

  # Guard 3c: catch data (double-bracket exact match — avoids partial match onto catch_col)
  if (is.null(design[["catch"]])) {
    cli::cli_abort(c(
      "No catch data found in design.",
      "i" = "Attach species catch data with {.fn add_catch} before calling this function."
    ))
  }

  interviews <- design$interviews
  catch_data <- design[["catch"]]
  uid_col <- design$catch_interview_uid_col
  species_col <- design$catch_species_col
  count_col <- design$catch_count_col
  type_col <- design$catch_type_col
  at_col <- design$angler_type_col
  ss_col <- design$species_sought_col
  iuid_col <- uid_col

  sought_map <- interviews[, c(iuid_col, ss_col, at_col), drop = FALSE]
  catch_merged <- merge(
    catch_data, sought_map,
    by.x = uid_col, by.y = iuid_col, all.x = FALSE
  )
  caught_rows <- catch_merged[
    catch_merged[[type_col]] == "caught" &
      catch_merged[[count_col]] > 0 &
      catch_merged[[species_col]] == catch_merged[[ss_col]],
  ]
  successful_ids <- unique(caught_rows[[uid_col]])
  interviews$is_successful <- interviews[[iuid_col]] %in% successful_ids

  totals <- stats::aggregate(
    interviews[[iuid_col]],
    by = list(
      angler_type    = interviews[[at_col]],
      species_sought = interviews[[ss_col]]
    ),
    FUN = length
  )
  names(totals)[3] <- "N_total"

  success_sub <- interviews[interviews$is_successful, ]
  if (nrow(success_sub) > 0) {
    successes <- stats::aggregate(
      success_sub[[iuid_col]],
      by = list(
        angler_type    = success_sub[[at_col]],
        species_sought = success_sub[[ss_col]]
      ),
      FUN = length
    )
    names(successes)[3] <- "N_successful"
    result <- merge(totals, successes,
      by = c("angler_type", "species_sought"), all.x = TRUE
    )
  } else {
    result <- totals
    result$N_successful <- 0L
  }
  result$N_successful[is.na(result$N_successful)] <- 0L
  result$percent <- round(100 * result$N_successful / result$N_total, 1)
  result$N_successful <- as.integer(result$N_successful)
  result$N_total <- as.integer(result$N_total)
  result <- result[order(result$angler_type, result$species_sought), ]
  row.names(result) <- NULL

  class(result) <- c("creel_summary_successful_parties", "data.frame")
  result
}


#' Tabulate interviews by trip length bin
#'
#' Bins trip durations (in hours) into 1-hour intervals from 0 to 10 hours,
#' with a final bin for trips 10+ hours. Returns counts and percentages for
#' each bin.
#'
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' tabulates raw interview records without applying survey weighting by sampling
#' effort or effort stratum. For pressure-weighted extrapolated estimates, use
#' \code{\link{estimate_cpue}} or \code{\link{estimate_harvest}}.
#'
#' @param design A \code{creel_design} object with interviews attached and
#'   \code{trip_duration} column set via
#'   \code{add_interviews(trip_duration = ...)}.
#'
#' @return A \code{data.frame} with class \code{c("creel_summary_trip_length",
#'   "data.frame")} and columns: \code{trip_length_bin} (ordered factor),
#'   \code{N} (integer), \code{percent} (numeric, 1 decimal).
#'   Bins: "[0,1)", "[1,2)", ..., "[9,10)", "10+".
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, trip_duration = trip_duration
#' )
#' summarize_by_trip_length(d)
#' }
#'
#' @export
summarize_by_trip_length <- function(design) {
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

  # Guard 3: trip_duration column
  if (is.null(design$trip_duration_col)) {
    cli::cli_abort(c(
      "No trip_duration column found in design.",
      "x" = "Did you provide {.arg trip_duration} in {.fn add_interviews}?"
    ))
  }

  breaks <- c(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, Inf)
  labels <- c(
    "[0,1)", "[1,2)", "[2,3)", "[3,4)", "[4,5)",
    "[5,6)", "[6,7)", "[7,8)", "[8,9)", "[9,10)", "10+"
  )

  durations <- design$interviews[[design$trip_duration_col]]
  bins <- cut(durations,
    breaks = breaks, labels = labels,
    right = FALSE, include.lowest = TRUE
  )

  counts <- as.data.frame(table(trip_length_bin = bins), stringsAsFactors = FALSE)
  names(counts)[names(counts) == "Freq"] <- "N"
  counts$N <- as.integer(counts$N)
  counts$percent <- round(100 * counts$N / sum(counts$N), 1)
  counts$trip_length_bin <- factor(counts$trip_length_bin, levels = labels, ordered = TRUE)

  class(counts) <- c("creel_summary_trip_length", "data.frame")
  counts
}

#' Compute caught-while-sought (CWS) rates by group
#'
#' @description
#' Computes mean caught-while-sought rates (fish per angler-hour) for anglers
#' targeting each species. For each interview, the rate is:
#' \code{caught_count / angler_effort} where \code{caught_count} is the total
#' number of fish caught of the species the angler was seeking, and
#' \code{angler_effort} is angler-hours (effort x n_anglers, standardized at
#' design time by \code{\link{add_interviews}}).
#'
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' computes a simple arithmetic mean over sampled interviews. It does NOT apply
#' survey weighting by sampling effort or effort stratum. For pressure-weighted
#' extrapolated estimates use \code{\link{estimate_cpue}}.
#'
#' The catch filter ensures only species the angler was targeting are counted
#' (i.e., rows in \code{design$catch} where \code{catch_type == "caught"} and
#' \code{species == species_sought}).
#'
#' @param design A \code{creel_design} object with interviews attached via
#'   \code{\link{add_interviews}} (with \code{species_sought}) and species
#'   catch data attached via \code{\link{add_catch}}.
#' @param by Optional tidy selector for grouping columns from
#'   \code{design$interviews}. Common choices:
#'   \code{by = species_sought} (CWS-03),
#'   \code{by = c(month, species_sought)} (CWS-02),
#'   \code{by = c(month, angler_type, species_sought)} (CWS-01).
#'   When \code{NULL}, returns a single overall rate across all interviews.
#' @param conf_level Numeric confidence level for the t-interval.
#'   Default 0.95.
#'
#' @return A \code{data.frame} with class
#'   \code{c("creel_summary_cws_rates", "data.frame")} and columns:
#'   grouping columns (if any), \code{N} (integer, interviews per group),
#'   \code{mean_rate} (numeric, mean fish/angler-hour),
#'   \code{se} (numeric, standard error), \code{ci_lower}, \code{ci_upper}.
#'
#' @seealso [summarize_hws_rates()], [estimate_cpue()]
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' data(example_catch)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, species_sought = species_sought
#' )
#' d <- add_catch(d, example_catch,
#'   catch_uid = interview_id, interview_uid = interview_id,
#'   species = species, count = count, catch_type = catch_type
#' )
#' summarize_cws_rates(d, by = species_sought)
#' }
#'
#' @export
summarize_cws_rates <- function(design, by = NULL, conf_level = 0.95) {
  # Capture by before validation
  by_quo <- rlang::enquo(by)

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

  # Guard 3a: angler_effort_col
  if (is.null(design$angler_effort_col)) {
    cli::cli_abort(c(
      "No angler_effort column found in design.",
      "x" = "This should be set automatically by {.fn add_interviews}.",
      "i" = "Re-attach interviews with {.fn add_interviews}."
    ))
  }

  # Guard 3b: species_sought_col
  if (is.null(design$species_sought_col)) {
    cli::cli_abort(c(
      "No species_sought column found in design.",
      "x" = "Did you provide {.arg species_sought} in {.fn add_interviews}?"
    ))
  }

  # Guard 3c: catch data (double-bracket, exact match)
  if (is.null(design[["catch"]])) {
    cli::cli_abort(c(
      "No catch data found in design.",
      "i" = "Attach species catch data with {.fn add_catch} before calling this function."
    ))
  }

  # Extract field names from design
  interviews <- design$interviews
  catch_data <- design[["catch"]]
  uid_col <- design$catch_interview_uid_col
  species_col <- design$catch_species_col
  count_col <- design$catch_count_col
  type_col <- design$catch_type_col
  ss_col <- design$species_sought_col
  ae_col <- design$angler_effort_col

  # Step 1: Resolve by columns from interviews
  if (!rlang::quo_is_null(by_quo)) {
    by_cols <- tidyselect::eval_select( # nolint: object_usage_linter
      by_quo,
      data = interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
  } else {
    by_vars <- character(0)
  }

  # Step 2: Filter catch to target type (caught for CWS)
  target_catch <- catch_data[catch_data[[type_col]] == "caught", ]

  # Merge to get species_sought on each catch row
  sought_map <- interviews[, c(uid_col, ss_col), drop = FALSE]
  catch_merged <- merge(
    target_catch, sought_map,
    by.x = uid_col, by.y = uid_col, all.x = FALSE
  )

  # Filter to rows where catch species == species_sought
  target_rows <- catch_merged[
    !is.na(catch_merged[[species_col]]) &
      catch_merged[[species_col]] == catch_merged[[ss_col]], ,
    drop = FALSE
  ]

  # Aggregate: sum catch per interview UID
  if (nrow(target_rows) > 0) {
    agg <- stats::aggregate(
      target_rows[[count_col]],
      by = list(.uid = target_rows[[uid_col]]),
      FUN = sum
    )
    names(agg)[2] <- ".target_count"
  } else {
    agg <- data.frame(.uid = character(0), .target_count = numeric(0))
  }

  # Step 3: Join back to ALL interviews to preserve zeros
  interview_base <- interviews[, unique(c(uid_col, ss_col, ae_col, by_vars)), drop = FALSE]
  interview_base <- merge(
    interview_base, agg,
    by.x = uid_col, by.y = ".uid", all.x = TRUE
  )
  interview_base$.target_count[is.na(interview_base$.target_count)] <- 0

  # Step 4: Exclude zero-effort interviews
  zero_eff <- !is.na(interview_base[[ae_col]]) & interview_base[[ae_col]] <= 0
  if (any(zero_eff)) {
    interview_base <- interview_base[!zero_eff, , drop = FALSE]
  }

  # Step 5: Compute per-interview rate
  interview_base$.rate <- interview_base$.target_count / interview_base[[ae_col]]

  # Step 6: Group and compute summary statistics
  group_cols <- if (length(by_vars) > 0) {
    lapply(by_vars, function(v) interview_base[[v]])
  } else {
    list(rep("all", nrow(interview_base)))
  }
  names(group_cols) <- if (length(by_vars) > 0) by_vars else ".group"

  n_agg <- stats::aggregate(interview_base$.rate, by = group_cols, FUN = length)
  mean_agg <- stats::aggregate(interview_base$.rate, by = group_cols, FUN = mean)
  sd_agg <- stats::aggregate(interview_base$.rate, by = group_cols, FUN = stats::sd)

  names(n_agg)[ncol(n_agg)] <- "N"
  names(mean_agg)[ncol(mean_agg)] <- "mean_rate"
  names(sd_agg)[ncol(sd_agg)] <- "sd_rate"

  merge_by <- if (length(by_vars) > 0) by_vars else ".group"
  result <- merge(n_agg, mean_agg, by = merge_by)
  result <- merge(result, sd_agg, by = merge_by)

  # Step 7: SE and CI via t-distribution
  result$se <- result$sd_rate / sqrt(result$N)
  t_crit <- stats::qt((1 + conf_level) / 2, df = pmax(result$N - 1, 1))
  result$ci_lower <- result$mean_rate - t_crit * result$se
  result$ci_upper <- result$mean_rate + t_crit * result$se
  result$sd_rate <- NULL

  # Drop .group column when no by variables
  if (length(by_vars) == 0) result$.group <- NULL

  result$N <- as.integer(result$N)
  row.names(result) <- NULL

  class(result) <- c("creel_summary_cws_rates", "data.frame")
  result
}

#' Compute harvested-while-sought (HWS) rates by group
#'
#' @description
#' Computes mean harvested-while-sought rates (fish per angler-hour) for
#' anglers targeting each species. For each interview, the rate is:
#' \code{harvested_count / angler_effort} where \code{harvested_count} is the
#' total number of fish harvested (kept) of the species the angler was seeking,
#' and \code{angler_effort} is angler-hours (effort x n_anglers, standardized
#' at design time by \code{\link{add_interviews}}).
#'
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' computes a simple arithmetic mean over sampled interviews. It does NOT apply
#' survey weighting by sampling effort or effort stratum. For pressure-weighted
#' extrapolated estimates use \code{\link{estimate_harvest}}.
#'
#' The catch filter ensures only species the angler was targeting are counted
#' (i.e., rows in \code{design$catch} where \code{catch_type == "harvested"}
#' and \code{species == species_sought}).
#'
#' @param design A \code{creel_design} object with interviews attached via
#'   \code{\link{add_interviews}} (with \code{species_sought}) and species
#'   catch data attached via \code{\link{add_catch}}.
#' @param by Optional tidy selector for grouping columns from
#'   \code{design$interviews}. Common choices:
#'   \code{by = species_sought} (HWS-03),
#'   \code{by = c(month, species_sought)} (HWS-02),
#'   \code{by = c(month, angler_type, species_sought)} (HWS-01).
#'   When \code{NULL}, returns a single overall rate across all interviews.
#' @param conf_level Numeric confidence level for the t-interval.
#'   Default 0.95.
#'
#' @return A \code{data.frame} with class
#'   \code{c("creel_summary_hws_rates", "data.frame")} and columns:
#'   grouping columns (if any), \code{N} (integer, interviews per group),
#'   \code{mean_rate} (numeric, mean fish/angler-hour),
#'   \code{se} (numeric, standard error), \code{ci_lower}, \code{ci_upper}.
#'
#' @seealso [summarize_cws_rates()], [estimate_harvest()]
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' data(example_catch)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, species_sought = species_sought
#' )
#' d <- add_catch(d, example_catch,
#'   catch_uid = interview_id, interview_uid = interview_id,
#'   species = species, count = count, catch_type = catch_type
#' )
#' summarize_hws_rates(d, by = species_sought)
#' }
#'
#' @export
summarize_hws_rates <- function(design, by = NULL, conf_level = 0.95) {
  # Capture by before validation
  by_quo <- rlang::enquo(by)

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

  # Guard 3a: angler_effort_col
  if (is.null(design$angler_effort_col)) {
    cli::cli_abort(c(
      "No angler_effort column found in design.",
      "x" = "This should be set automatically by {.fn add_interviews}.",
      "i" = "Re-attach interviews with {.fn add_interviews}."
    ))
  }

  # Guard 3b: species_sought_col
  if (is.null(design$species_sought_col)) {
    cli::cli_abort(c(
      "No species_sought column found in design.",
      "x" = "Did you provide {.arg species_sought} in {.fn add_interviews}?"
    ))
  }

  # Guard 3c: catch data (double-bracket, exact match)
  if (is.null(design[["catch"]])) {
    cli::cli_abort(c(
      "No catch data found in design.",
      "i" = "Attach species catch data with {.fn add_catch} before calling this function."
    ))
  }

  # Extract field names from design
  interviews <- design$interviews
  catch_data <- design[["catch"]]
  uid_col <- design$catch_interview_uid_col
  species_col <- design$catch_species_col
  count_col <- design$catch_count_col
  type_col <- design$catch_type_col
  ss_col <- design$species_sought_col
  ae_col <- design$angler_effort_col

  # Step 1: Resolve by columns from interviews
  if (!rlang::quo_is_null(by_quo)) {
    by_cols <- tidyselect::eval_select( # nolint: object_usage_linter
      by_quo,
      data = interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
  } else {
    by_vars <- character(0)
  }

  # Step 2: Filter catch to target type (harvested for HWS)
  target_catch <- catch_data[catch_data[[type_col]] == "harvested", ]

  # Merge to get species_sought on each catch row
  sought_map <- interviews[, c(uid_col, ss_col), drop = FALSE]
  catch_merged <- merge(
    target_catch, sought_map,
    by.x = uid_col, by.y = uid_col, all.x = FALSE
  )

  # Filter to rows where catch species == species_sought
  target_rows <- catch_merged[
    !is.na(catch_merged[[species_col]]) &
      catch_merged[[species_col]] == catch_merged[[ss_col]], ,
    drop = FALSE
  ]

  # Aggregate: sum catch per interview UID
  if (nrow(target_rows) > 0) {
    agg <- stats::aggregate(
      target_rows[[count_col]],
      by = list(.uid = target_rows[[uid_col]]),
      FUN = sum
    )
    names(agg)[2] <- ".target_count"
  } else {
    agg <- data.frame(.uid = character(0), .target_count = numeric(0))
  }

  # Step 3: Join back to ALL interviews to preserve zeros
  interview_base <- interviews[, unique(c(uid_col, ss_col, ae_col, by_vars)), drop = FALSE]
  interview_base <- merge(
    interview_base, agg,
    by.x = uid_col, by.y = ".uid", all.x = TRUE
  )
  interview_base$.target_count[is.na(interview_base$.target_count)] <- 0

  # Step 4: Exclude zero-effort interviews
  zero_eff <- !is.na(interview_base[[ae_col]]) & interview_base[[ae_col]] <= 0
  if (any(zero_eff)) {
    interview_base <- interview_base[!zero_eff, , drop = FALSE]
  }

  # Step 5: Compute per-interview rate
  interview_base$.rate <- interview_base$.target_count / interview_base[[ae_col]]

  # Step 6: Group and compute summary statistics
  group_cols <- if (length(by_vars) > 0) {
    lapply(by_vars, function(v) interview_base[[v]])
  } else {
    list(rep("all", nrow(interview_base)))
  }
  names(group_cols) <- if (length(by_vars) > 0) by_vars else ".group"

  n_agg <- stats::aggregate(interview_base$.rate, by = group_cols, FUN = length)
  mean_agg <- stats::aggregate(interview_base$.rate, by = group_cols, FUN = mean)
  sd_agg <- stats::aggregate(interview_base$.rate, by = group_cols, FUN = stats::sd)

  names(n_agg)[ncol(n_agg)] <- "N"
  names(mean_agg)[ncol(mean_agg)] <- "mean_rate"
  names(sd_agg)[ncol(sd_agg)] <- "sd_rate"

  merge_by <- if (length(by_vars) > 0) by_vars else ".group"
  result <- merge(n_agg, mean_agg, by = merge_by)
  result <- merge(result, sd_agg, by = merge_by)

  # Step 7: SE and CI via t-distribution
  result$se <- result$sd_rate / sqrt(result$N)
  t_crit <- stats::qt((1 + conf_level) / 2, df = pmax(result$N - 1, 1))
  result$ci_lower <- result$mean_rate - t_crit * result$se
  result$ci_upper <- result$mean_rate + t_crit * result$se
  result$sd_rate <- NULL

  # Drop .group column when no by variables
  if (length(by_vars) == 0) result$.group <- NULL

  result$N <- as.integer(result$N)
  row.names(result) <- NULL

  class(result) <- c("creel_summary_hws_rates", "data.frame")
  result
}


#' Compute length frequency distribution from creel interview data
#'
#' @description
#' Computes length frequency distributions (count, percent, cumulative percent)
#' from fish length data attached via \code{\link{add_lengths}}.
#' Supports all fish (\code{type = "catch"}), harvested fish
#' (\code{type = "harvest"}), and released fish (\code{type = "release"}).
#'
#' @details
#' \strong{Interview-based summary, not pressure-weighted.} This function
#' tabulates raw length measurements from sampled interviews without applying
#' survey weighting by sampling effort or effort stratum. For pressure-weighted
#' extrapolated estimates use \code{\link{estimate_cpue}} or
#' \code{\link{estimate_harvest}}.
#'
#' \strong{Pre-binned release format:} When length data was attached with
#' \code{release_format = "binned"}, release rows have character bin labels
#' (e.g., \code{"350-400"}) and a count column. This function parses each bin
#' label into a numeric midpoint and expands by count before applying
#' \code{bin_width} binning. This allows a consistent \code{bin_width} to be
#' applied to both individual and pre-binned data.
#'
#' @param design A \code{creel_design} object with length data attached via
#'   \code{\link{add_lengths}}.
#' @param type Character string specifying which fish to include. One of
#'   \code{"catch"} (all fish, harvest + release combined), \code{"harvest"}
#'   (kept fish only), or \code{"release"} (released fish only).
#'   Default \code{"catch"}.
#' @param by Optional tidy selector for grouping columns from
#'   \code{design$lengths}. Common choice: \code{by = species}.
#'   When \code{NULL}, returns a single overall distribution.
#' @param bin_width Positive numeric specifying the width of each length bin
#'   in the same units as the length data (typically mm). Default \code{1}.
#'
#' @return A \code{data.frame} with class
#'   \code{c("creel_summary_length_freq", "data.frame")} and columns:
#'   grouping columns (if any), \code{length_bin} (ordered factor),
#'   \code{N} (integer, fish count per bin), \code{percent} (numeric,
#'   percent of group total), \code{cumulative_percent} (numeric, within group).
#'   Only bins with N > 0 are returned. Percent values are rounded to 1
#'   decimal place.
#'
#' @seealso [add_lengths()], [summarize_cws_rates()], [summarize_hws_rates()]
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' data(example_lengths)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_interviews(d, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' d <- add_lengths(d, example_lengths,
#'   length_uid = interview_id, interview_uid = interview_id,
#'   species = species, length = length,
#'   length_type = length_type, count = count,
#'   release_format = "binned"
#' )
#' summarize_length_freq(d, type = "harvest", by = species, bin_width = 25)
#' summarize_length_freq(d, type = "release", by = species)
#' summarize_length_freq(d, type = "catch")
#' }
#'
#' @export
summarize_length_freq <- function(design, type = "catch", by = NULL, bin_width = 1) {
  by_quo <- rlang::enquo(by)

  # Guard 1: type check
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Guard 2: lengths attached (double-bracket avoids partial match against lengths_*)
  if (is.null(design[["lengths"]])) {
    cli::cli_abort(c(
      "No length data found in design.",
      "x" = "The design object has no length data.",
      "i" = "Attach length data with {.fn add_lengths}."
    ))
  }

  # Guard 3: bin_width validation
  if (!is.numeric(bin_width) || length(bin_width) != 1L || bin_width <= 0) {
    cli::cli_abort(c(
      "{.arg bin_width} must be a single positive number.",
      "x" = "{.arg bin_width} is {.val {bin_width}}."
    ))
  }

  # Validate type argument
  type <- match.arg(type, choices = c("catch", "harvest", "release"))

  # Extract design fields
  lengths_data <- design$lengths
  length_col <- design$lengths_length_col
  type_col <- design$lengths_type_col
  count_col <- design$lengths_count_col
  rel_format <- design$lengths_release_format

  # Resolve by columns from lengths data
  if (!rlang::quo_is_null(by_quo)) {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = lengths_data,
      allow_rename = FALSE, allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
  } else {
    by_vars <- character(0)
  }

  # Filter to requested type
  if (type == "harvest") {
    lengths_data <- lengths_data[lengths_data[[type_col]] == "harvest", , drop = FALSE]
  } else if (type == "release") {
    lengths_data <- lengths_data[lengths_data[[type_col]] == "release", , drop = FALSE]
  }
  # type == "catch": use all rows

  if (nrow(lengths_data) == 0) {
    cli::cli_abort(c(
      "No length data found for {.arg type} = {.val {type}}.",
      "i" = "Check that {.fn add_lengths} included rows of this type."
    ))
  }

  # Build numeric lengths + weights (accounting for binned release format)
  harvest_rows <- lengths_data[lengths_data[[type_col]] == "harvest", , drop = FALSE]
  release_rows <- lengths_data[lengths_data[[type_col]] == "release", , drop = FALSE]

  # Helper: build numeric_lengths and weights vectors plus corresponding by-group values
  build_records <- function(rows, is_binned_release) {
    if (nrow(rows) == 0) {
      out <- list(
        lengths = numeric(0),
        weights = integer(0)
      )
      for (v in by_vars) out[[v]] <- character(0)
      return(out)
    }

    if (is_binned_release) {
      # Parse bin labels to midpoints; weight = count
      raw_labels <- as.character(rows[[length_col]])
      parts <- strsplit(raw_labels, "-")
      lower_bounds <- suppressWarnings(
        as.numeric(vapply(parts, function(p) p[[1]], character(1)))
      )
      upper_bounds <- suppressWarnings(
        as.numeric(vapply(parts, function(p) p[[2]], character(1)))
      )
      if (any(is.na(lower_bounds)) || any(is.na(upper_bounds))) {
        cli::cli_abort(c(
          "Could not parse bin labels in release length data.",
          "i" = "Expected format: {.val \"350-400\"} (lower-upper separated by {.code -}).",
          "x" = "Check the {.arg length} column in your lengths data."
        ))
      }
      midpoints <- (lower_bounds + upper_bounds) / 2
      counts <- as.integer(rows[[count_col]])
      # Expand: rep each midpoint by its count; repeat by-group values similarly
      lengths <- rep(midpoints, times = counts)
      weights <- rep(1L, times = length(lengths))
      out <- list(lengths = lengths, weights = weights)
      for (v in by_vars) out[[v]] <- rep(rows[[v]], times = counts)
    } else {
      # Individual format: one fish per row, weight = 1
      lengths <- as.numeric(rows[[length_col]])
      weights <- rep(1L, times = length(lengths))
      out <- list(lengths = lengths, weights = weights)
      for (v in by_vars) out[[v]] <- rows[[v]]
    }
    out
  }

  harvest_records <- build_records(harvest_rows, is_binned_release = FALSE)
  release_records <- build_records(
    release_rows,
    is_binned_release = (rel_format == "binned" && nrow(release_rows) > 0)
  )

  # Combine harvest and release record lists
  all_lengths <- c(harvest_records$lengths, release_records$lengths)
  all_weights <- c(harvest_records$weights, release_records$weights)
  group_lists <- list()
  for (v in by_vars) {
    group_lists[[v]] <- c(harvest_records[[v]], release_records[[v]])
  }

  # Validate all_lengths after parsing
  if (any(is.na(all_lengths))) {
    cli::cli_abort(c(
      "Non-numeric length values found after parsing.",
      "i" = "Check that harvest lengths are numeric and bin labels are parseable."
    ))
  }

  # Apply cut() binning
  max_len <- ceiling(max(all_lengths) / bin_width) * bin_width
  breaks <- seq(0, max_len + bin_width, by = bin_width)
  labels <- paste0("[", breaks[-length(breaks)], ",", breaks[-1], ")")
  bins <- cut(all_lengths,
    breaks = breaks, labels = labels,
    right = FALSE, include.lowest = TRUE
  )

  # Build a data frame of all records
  records_df <- data.frame(
    .length_bin = as.character(bins),
    .lower = breaks[as.integer(bins)],
    .weight = all_weights,
    stringsAsFactors = FALSE
  )
  for (v in by_vars) records_df[[v]] <- group_lists[[v]]

  # Aggregate: N = sum(weight) per (by_vars + .length_bin)
  agg_by <- c(by_vars, ".length_bin", ".lower")
  agg_groups <- lapply(agg_by, function(v) records_df[[v]])
  names(agg_groups) <- agg_by

  n_agg <- stats::aggregate(records_df$.weight, by = agg_groups, FUN = sum)
  names(n_agg)[ncol(n_agg)] <- "N"

  # Sort ascending within each group: by lower bound then by-vars
  sort_cols <- c(by_vars, ".lower")
  n_agg <- n_agg[do.call(order, lapply(sort_cols, function(v) n_agg[[v]])), , drop = FALSE]

  # Keep only non-zero bins
  n_agg <- n_agg[n_agg$N > 0, , drop = FALSE]

  # Restore ordered factor for length_bin
  occupied_labels <- unique(n_agg$.length_bin)
  # Order occupied labels by .lower bound
  lower_map <- unique(n_agg[, c(".length_bin", ".lower"), drop = FALSE])
  lower_map <- lower_map[order(lower_map$.lower), ]
  ordered_labs <- lower_map$.length_bin[lower_map$.length_bin %in% occupied_labels]
  n_agg$.length_bin <- factor(n_agg$.length_bin,
    levels = ordered_labs,
    ordered = TRUE
  )

  # Compute percent and cumulative_percent within each group
  if (length(by_vars) > 0) {
    group_key <- do.call(paste, c(lapply(by_vars, function(v) n_agg[[v]]), sep = "\x1f"))
  } else {
    group_key <- rep("all", nrow(n_agg))
  }
  group_totals <- tapply(n_agg$N, group_key, sum)
  n_agg$percent <- round(n_agg$N / group_totals[group_key] * 100, 1)

  # cumulative_percent: cumsum within each group key (for-loop avoids ordering subtlety)
  n_agg$cumulative_percent <- NA_real_
  for (gk in unique(group_key)) {
    idx <- which(group_key == gk)
    n_agg$cumulative_percent[idx] <- cumsum(n_agg$percent[idx])
  }

  # Rename .length_bin -> length_bin and drop internal columns
  n_agg$length_bin <- n_agg$.length_bin
  n_agg$.length_bin <- NULL
  n_agg$.lower <- NULL

  # Final column order: by_vars, length_bin, N, percent, cumulative_percent
  result <- n_agg[, c(by_vars, "length_bin", "N", "percent", "cumulative_percent"),
    drop = FALSE
  ]
  result$N <- as.integer(result$N)
  row.names(result) <- NULL

  class(result) <- c("creel_summary_length_freq", "data.frame")
  result
}
