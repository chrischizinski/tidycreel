#' Create a creel survey design
#'
#' @description
#' Constructs a `creel_design` object from calendar data with tidy column
#' selection. This is the entry point for all creel survey analysis workflows.
#' The design object stores the survey structure (date, strata, optional site),
#' validates input data (Tier 1 validation), and serves as the foundation for
#' adding count data and estimating effort.
#'
#' For bus-route surveys with nonuniform site selection probabilities, use
#' `survey_type = "bus_route"` and supply a `sampling_frame` data frame
#' specifying sites, circuits, and their sampling probabilities.
#'
#' @param calendar A data frame containing calendar data with date and strata
#'   columns. Must have at least one Date column and one character/factor column
#'   (validated via internal schema check).
#' @param date Tidy selector for the date column. Must select exactly one
#'   column of class Date. Accepts bare column names or tidyselect helpers
#'   (e.g., `starts_with("date")`).
#' @param strata Tidy selector for strata columns. Can select one or more
#'   columns of class character or factor. Accepts bare column names or
#'   tidyselect helpers (e.g., `c(day_type, season)` or `starts_with("day")`).
#' @param site Optional tidy selector for a site column. For instantaneous
#'   designs, selects from `calendar`. For bus-route designs
#'   (`survey_type = "bus_route"`), selects the site ID column from
#'   `sampling_frame`. Must select exactly one column of class character or
#'   factor. Default is `NULL` (single-site survey for instantaneous designs;
#'   required for bus-route designs).
#' @param design_type Character string specifying the survey design type.
#'   Default is `"instantaneous"`. Kept for backward compatibility; use
#'   `survey_type` for new code.
#' @param survey_type Character string specifying the survey type. Default
#'   inherits from `design_type` (`"instantaneous"`). Use `"bus_route"` for
#'   nonuniform probability bus-route surveys (BUSRT-06, BUSRT-07). Both
#'   `survey_type` and `design_type` refer to the same concept; `survey_type`
#'   is the canonical parameter for new designs.
#' @param sampling_frame Data frame with site, circuit, and probability columns.
#'   Required when `survey_type = "bus_route"`. Each row represents one
#'   site-circuit sampling unit with its inclusion probability components
#'   (`p_site` and `p_period`).
#' @param p_site Tidy selector for the site sampling probability column in
#'   `sampling_frame`. Required when `survey_type = "bus_route"`. Values must
#'   be in `(0, 1]` and must sum to `1.0` within each circuit (tolerance 1e-6).
#' @param p_period Tidy selector for the period sampling probability column in
#'   `sampling_frame`, OR a scalar numeric value in `(0, 1]` that applies
#'   globally to all rows. Required when `survey_type = "bus_route"`.
#' @param circuit Optional tidy selector for the circuit ID column in
#'   `sampling_frame`. A circuit is a route x period combination. If omitted,
#'   all rows are treated as belonging to a single unnamed circuit
#'   (`".default"`). Required only for multi-circuit designs.
#'
#' @return A `creel_design` S3 object (list) with components:
#'   \item{calendar}{The original calendar data frame}
#'   \item{date_col}{Character name of the date column}
#'   \item{strata_cols}{Character vector of strata column names}
#'   \item{site_col}{Character name of site column, or NULL}
#'   \item{design_type}{Character design type}
#'   \item{counts}{NULL (populated by `add_counts()` in future)}
#'   \item{survey}{NULL (populated internally during estimation)}
#'   \item{bus_route}{List with resolved sampling frame data and column
#'     mappings, or NULL for non-bus-route designs. Contains:
#'     `$data` (sampling frame with `.pi_i` column added),
#'     `$site_col`, `$circuit_col`, `$p_site_col`, `$p_period_col`,
#'     `$pi_i_col` (always `".pi_i"`).}
#'
#' @section Tier 1 Validation:
#' The constructor performs fail-fast validation:
#' - Date column is class Date (not character, numeric, POSIXct)
#' - Date column contains no NA values
#' - Strata columns are character or factor (not numeric, logical)
#' - Site column (if provided) is character or factor
#' - (bus_route only) All `p_site` and `p_period` values are in `(0, 1]`
#' - (bus_route only) `p_site` values sum to 1.0 within each circuit
#'   (tolerance 1e-6)
#' - (bus_route only) `p_period` values are constant within each circuit
#'   (tolerance 1e-10)
#'
#' @references
#' Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
#' estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
#' & T. M. Sutton (Eds.), *Fisheries Techniques* (3rd ed., pp. 883--919).
#' American Fisheries Society. Eq. 19.4 and 19.5 define the bus-route
#' estimators; pp. 883--884 define the inclusion probability
#' \eqn{\pi_i = p_{\text{site}} \times p_{\text{period}}}.
#'
#' @examples
#' # Basic design with single stratum
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
#'   day_type = c("weekday", "weekend", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' # Multiple strata
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   season = c("summer", "summer")
#' )
#' design <- creel_design(calendar, date = date, strata = c(day_type, season))
#'
#' # With site column for multi-site survey
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   lake = c("lake_a", "lake_b")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type, site = lake)
#'
#' # Using tidyselect helpers
#' calendar <- data.frame(
#'   survey_date = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   day_period = c("morning", "evening")
#' )
#' design <- creel_design(
#'   calendar,
#'   date = starts_with("survey"),
#'   strata = starts_with("day")
#' )
#'
#' # Bus-route design with scalar p_period
#' calendar_br <- data.frame(
#'   date = as.Date("2024-06-01"),
#'   day_type = "weekday"
#' )
#' sf <- data.frame(
#'   site = c("A", "B", "C"),
#'   p_site = c(0.3, 0.4, 0.3),
#'   p_period = 0.5
#' )
#' design_br <- creel_design(
#'   calendar_br,
#'   date = date,
#'   strata = day_type,
#'   survey_type = "bus_route",
#'   sampling_frame = sf,
#'   site = site,
#'   p_site = p_site,
#'   p_period = p_period
#' )
#'
#' @export
creel_design <- function(calendar,
                         date,
                         strata,
                         site = NULL,
                         design_type = "instantaneous",
                         survey_type = design_type,
                         sampling_frame = NULL,
                         p_site = NULL,
                         p_period = NULL,
                         circuit = NULL) {
  # 1. Structural validation (Phase 1 validator)
  validate_calendar_schema(calendar) # nolint: object_usage_linter

  # 2. Resolve tidy selectors to column names
  date_col <- resolve_single_col(
    rlang::enquo(date),
    calendar,
    "date",
    rlang::caller_env()
  )

  strata_cols <- resolve_multi_cols(
    rlang::enquo(strata),
    calendar,
    "strata",
    rlang::caller_env()
  )

  site_col <- NULL
  site_quo <- rlang::enquo(site)
  if (!identical(survey_type, "bus_route") && !rlang::quo_is_null(site_quo)) {
    site_col <- resolve_single_col(
      site_quo,
      calendar,
      "site",
      rlang::caller_env()
    )
  }

  # --- Bus-Route branch ---
  bus_route <- NULL
  if (identical(survey_type, "bus_route")) {
    if (is.null(sampling_frame) || !is.data.frame(sampling_frame)) {
      cli::cli_abort(c(
        "{.arg sampling_frame} must be a data frame when {.arg survey_type} is {.val bus_route}.",
        "i" = "Provide a data frame with site, probability, and optional circuit columns."
      ))
    }

    # Resolve p_site column (tidy selector, required)
    p_site_quo <- rlang::enquo(p_site)
    if (rlang::quo_is_null(p_site_quo)) {
      cli::cli_abort(c(
        "{.arg p_site} is required when {.arg survey_type} is {.val bus_route}.",
        "i" = "Specify the column in {.arg sampling_frame} that holds site sampling probabilities."
      ))
    }
    p_site_col <- resolve_single_col(p_site_quo, sampling_frame, "p_site", rlang::caller_env())

    # Resolve site column in sampling_frame (tidy selector, required for bus_route)
    site_frame_col <- NULL
    if (!rlang::quo_is_null(site_quo)) {
      site_frame_col <- resolve_single_col(site_quo, sampling_frame, "site", rlang::caller_env())
    } else {
      cli::cli_abort(c(
        "{.arg site} is required when {.arg survey_type} is {.val bus_route}.",
        "i" = "Specify the column in {.arg sampling_frame} that identifies sites."
      ))
    }

    # Resolve circuit column (optional; if omitted, default to single circuit ".circuit")
    circuit_col <- NULL
    circuit_quo <- rlang::enquo(circuit)
    if (!rlang::quo_is_null(circuit_quo)) {
      circuit_col <- resolve_single_col(circuit_quo, sampling_frame, "circuit", rlang::caller_env())
    }

    # Resolve p_period: either a column in sampling_frame OR a scalar numeric argument
    p_period_col <- NULL
    p_period_scalar <- NULL
    p_period_quo <- rlang::enquo(p_period)
    if (!rlang::quo_is_null(p_period_quo)) {
      # Try as column selector first; if it fails, evaluate as expression (scalar numeric)
      tryCatch(
        {
          p_period_col <- resolve_single_col(p_period_quo, sampling_frame, "p_period", rlang::caller_env())
        },
        error = function(e) {
          val <- rlang::eval_tidy(p_period_quo)
          if (!is.numeric(val) || length(val) != 1) {
            cli::cli_abort(c(
              "{.arg p_period} must be a column name in {.arg sampling_frame} or a single numeric value.",
              "x" = "Got {.cls {class(val)[1]}} of length {length(val)}."
            ))
          }
          p_period_scalar <<- val
        }
      )
    } else {
      cli::cli_abort(c(
        "{.arg p_period} is required when {.arg survey_type} is {.val bus_route}.",
        "i" = "Supply a column name from {.arg sampling_frame} or a scalar numeric in (0, 1]."
      ))
    }

    # Build internal bus_route data frame with standardized column names
    br_df <- sampling_frame

    # Add default circuit column if omitted
    if (is.null(circuit_col)) {
      br_df[[".circuit"]] <- ".default"
      circuit_col <- ".circuit"
    }

    # Add p_period column if scalar was provided
    if (!is.null(p_period_scalar)) {
      br_df[[".p_period"]] <- p_period_scalar
      p_period_col <- ".p_period"
    }

    # Compute pi_i = p_site * p_period
    br_df[[".pi_i"]] <- br_df[[p_site_col]] * br_df[[p_period_col]]

    # Store resolved column mappings alongside the data
    bus_route <- list(
      data         = br_df,
      site_col     = site_frame_col,
      circuit_col  = circuit_col,
      p_site_col   = p_site_col,
      p_period_col = p_period_col,
      pi_i_col     = ".pi_i"
    )
  }

  # 3. Construct and validate
  design <- new_creel_design(
    calendar    = calendar,
    date_col    = date_col,
    strata_cols = strata_cols,
    site_col    = site_col,
    design_type = survey_type,
    bus_route   = bus_route
  )
  validate_creel_design(design)
}

#' Low-level creel_design constructor
#'
#' Internal constructor that creates the creel_design structure with type
#' checking only. Does not perform semantic validation. Use [creel_design()]
#' for user-facing construction.
#'
#' @param calendar Data frame with calendar data
#' @param date_col Character name of date column
#' @param strata_cols Character vector of strata column names
#' @param site_col Character name of site column, or NULL
#' @param design_type Character design type
#' @param bus_route Named list with resolved sampling frame and column mappings
#'   for bus-route designs. NULL for non-bus-route designs.
#'
#' @return A creel_design object (list with class attribute)
#'
#' @keywords internal
#' @noRd
new_creel_design <- function(calendar,
                             date_col,
                             strata_cols,
                             site_col = NULL,
                             design_type = "instantaneous",
                             bus_route = NULL) {
  stopifnot(is.data.frame(calendar))
  stopifnot(is.character(date_col), length(date_col) == 1)
  stopifnot(is.character(strata_cols), length(strata_cols) >= 1)
  stopifnot(is.null(site_col) || (is.character(site_col) && length(site_col) == 1))
  stopifnot(is.character(design_type), length(design_type) == 1)
  stopifnot(is.null(bus_route) || is.list(bus_route))

  structure(
    list(
      calendar    = calendar,
      date_col    = date_col,
      strata_cols = strata_cols,
      site_col    = site_col,
      design_type = design_type,
      counts      = NULL,
      survey      = NULL,
      bus_route   = bus_route # NULL for non-bus_route designs
    ),
    class = "creel_design"
  )
}

#' Validate creel_design object (Tier 1)
#'
#' Performs semantic validation on a creel_design object. Checks that the
#' user-specified columns have appropriate types and values for creel survey
#' analysis.
#'
#' @param x A creel_design object
#'
#' @return Invisibly returns the input object on success. Aborts with
#'   informative cli error message on validation failure.
#'
#' @keywords internal
#' @noRd
validate_creel_design <- function(x) {
  cal <- x$calendar

  # Tier 1: Date column is actually Date class
  if (!inherits(cal[[x$date_col]], "Date")) {
    cli::cli_abort(c(
      "Column {.var {x$date_col}} must be of class {.cls Date}.",
      "x" = "Column {.var {x$date_col}} is {.cls {class(cal[[x$date_col]])[1]}}.",
      "i" = "Convert with {.code as.Date()}."
    ))
  }

  # Tier 1: Date column has no NA values
  if (anyNA(cal[[x$date_col]])) {
    cli::cli_abort(c(
      "Column {.var {x$date_col}} must not contain {.val NA} values.",
      "i" = "Remove or impute missing dates before creating a design."
    ))
  }

  # Tier 1: Strata columns exist and are character/factor
  for (col in x$strata_cols) {
    if (!is.character(cal[[col]]) && !is.factor(cal[[col]])) {
      cli::cli_abort(c(
        "Strata column {.var {col}} must be character or factor.",
        "x" = "Column {.var {col}} is {.cls {class(cal[[col]])[1]}}."
      ))
    }
  }

  # Tier 1: Site column (if provided) is character/factor
  if (!is.null(x$site_col)) {
    if (!is.character(cal[[x$site_col]]) && !is.factor(cal[[x$site_col]])) {
      cli::cli_abort(c(
        "Site column {.var {x$site_col}} must be character or factor.",
        "x" = "Column {.var {x$site_col}} is {.cls {class(cal[[x$site_col]])[1]}}."
      ))
    }
  }

  # Tier 1: Bus-Route probability validation
  if (!is.null(x$bus_route)) {
    br <- x$bus_route$data
    p_site_col <- x$bus_route$p_site_col
    p_period_col <- x$bus_route$p_period_col
    circuit_col <- x$bus_route$circuit_col

    # All p_site values must be in (0, 1]
    p_site_vals <- br[[p_site_col]]
    if (any(is.na(p_site_vals)) || any(p_site_vals <= 0) || any(p_site_vals > 1)) {
      bad <- which(is.na(p_site_vals) | p_site_vals <= 0 | p_site_vals > 1) # nolint: object_usage_linter
      cli::cli_abort(c(
        "All {.field p_site} values must be in the range (0, 1].",
        "x" = "{length(bad)} value{?s} out of range at row{?s} {bad}.",
        "i" = "Sampling probabilities must be positive and at most 1.0."
      ))
    }

    # All p_period values must be in (0, 1]
    p_period_vals <- br[[p_period_col]]
    if (any(is.na(p_period_vals)) || any(p_period_vals <= 0) || any(p_period_vals > 1)) {
      bad <- which(is.na(p_period_vals) | p_period_vals <= 0 | p_period_vals > 1) # nolint: object_usage_linter
      cli::cli_abort(c(
        "All {.field p_period} values must be in the range (0, 1].",
        "x" = "{length(bad)} value{?s} out of range at row{?s} {bad}.",
        "i" = "Sampling probabilities must be positive and at most 1.0."
      ))
    }

    # p_site values must sum to 1.0 per circuit (tolerance 1e-6)
    circuits <- unique(br[[circuit_col]])
    for (circ in circuits) {
      circ_rows <- br[[circuit_col]] == circ
      circ_sum <- sum(br[[p_site_col]][circ_rows])
      if (abs(circ_sum - 1.0) > 1e-6) {
        cli::cli_abort(c(
          "{.field p_site} values must sum to 1.0 within each circuit.",
          "x" = "Circuit {.val {circ}}: sum = {round(circ_sum, 8)} (tolerance 1e-6).",
          "i" = "Adjust {.field p_site} values so they sum to exactly 1.0 per circuit."
        ))
      }
    }

    # p_period must be uniform within each circuit
    for (circ in circuits) {
      circ_rows <- br[[circuit_col]] == circ
      circ_p_period <- br[[p_period_col]][circ_rows]
      circ_range <- max(circ_p_period) - min(circ_p_period) # nolint: object_usage_linter
      if (circ_range > 1e-10) {
        p_min <- round(min(circ_p_period), 8) # nolint: object_usage_linter
        p_max <- round(max(circ_p_period), 8) # nolint: object_usage_linter
        cli::cli_abort(c(
          "p_period must be constant within each circuit.",
          "x" = "Circuit {.val {circ}} has differing {.field p_period} values (min={p_min}, max={p_max}).",
          "i" = "p_period is the probability of selecting the circuit's sampling period; it should not vary by site."
        ))
      }
    }

    # Defensive: pi_i values must be in (0, 1] after computation
    pi_i_col <- x$bus_route$pi_i_col
    pi_i_vals <- br[[pi_i_col]]
    if (any(is.na(pi_i_vals)) || any(pi_i_vals <= 0) || any(pi_i_vals > 1)) {
      bad <- which(is.na(pi_i_vals) | pi_i_vals <= 0 | pi_i_vals > 1) # nolint: object_usage_linter
      cli::cli_abort(c(
        "Computed inclusion probabilities ({.field .pi_i}) must be in the range (0, 1].",
        "x" = "{length(bad)} value{?s} out of range at row{?s} {bad}.",
        "i" = "pi_i = p_site * p_period must be a valid probability."
      ))
    }
  }

  invisible(x)
}

#' Resolve single column from tidy selector
#'
#' Internal helper to resolve a tidy selector expression to exactly one column
#' name. Used for date and site parameters.
#'
#' @param expr Quosure containing the tidy selector expression
#' @param data Data frame to select from
#' @param arg_name Name of the argument (for error messages)
#' @param error_call Calling environment for error reporting
#'
#' @return Character scalar with the selected column name
#'
#' @keywords internal
#' @noRd
resolve_single_col <- function(expr, data, arg_name, error_call = rlang::caller_env()) {
  loc <- tidyselect::eval_select(
    expr,
    data = data,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = error_call
  )
  if (length(loc) != 1) {
    cli::cli_abort(
      "{.arg {arg_name}} must select exactly one column, not {length(loc)}.",
      call = error_call
    )
  }
  names(loc)
}

#' Resolve multiple columns from tidy selector
#'
#' Internal helper to resolve a tidy selector expression to one or more column
#' names. Used for strata parameter.
#'
#' @param expr Quosure containing the tidy selector expression
#' @param data Data frame to select from
#' @param arg_name Name of the argument (for error messages)
#' @param error_call Calling environment for error reporting
#'
#' @return Character vector with selected column names
#'
#' @keywords internal
#' @noRd
resolve_multi_cols <- function(expr, data, arg_name, error_call = rlang::caller_env()) {
  loc <- tidyselect::eval_select(
    expr,
    data = data,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = error_call
  )
  names(loc)
}

#' Attach count data to a creel design
#'
#' @description
#' Attaches instantaneous count data to a creel_design object and constructs
#' the internal survey design object eagerly. This is the core of the survey
#' bridge layer - translating domain vocabulary (creel counts) into statistical
#' machinery (survey::svydesign). Eager construction catches design errors at
#' add_counts() time when users have context about what data they are adding.
#'
#' @param design A creel_design object (created with [creel_design()])
#' @param counts Data frame containing count data. Must have:
#'   - A Date column matching the design's date_col
#'   - All strata columns from the design's strata_cols
#'   - At least one numeric column (the count variable)
#'   - A PSU column (specified via psu argument, defaults to date_col)
#' @param psu Character string naming the PSU (Primary Sampling Unit) column
#'   in the count data. Defaults to NULL, which uses the design's date_col as
#'   the PSU (day-as-PSU is the most common creel design). For other designs,
#'   specify the PSU column explicitly (e.g., "site_day" for day-site PSUs).
#' @param allow_invalid Logical flag for validation behavior. If FALSE (default),
#'   validation failures abort with detailed error messages. If TRUE, validation
#'   failures generate warnings and attach counts anyway (use with caution).
#'
#' @return A new creel_design object (list) with components:
#'   \item{calendar}{Original calendar data frame}
#'   \item{date_col}{Character name of date column}
#'   \item{strata_cols}{Character vector of strata column names}
#'   \item{site_col}{Character name of site column, or NULL}
#'   \item{design_type}{Character design type}
#'   \item{counts}{The count data frame (newly attached)}
#'   \item{psu_col}{Character name of PSU column}
#'   \item{survey}{Internal survey.design2 object (newly constructed)}
#'   \item{validation}{creel_validation object with Tier 1 results}
#'
#' @section Immutability:
#' add_counts() follows functional programming patterns and returns a new
#' creel_design object. The original design object is not modified. This
#' prevents accidental data loss and makes the workflow explicit:
#' `design2 <- add_counts(design, counts)` not `add_counts(design, counts)`
#'
#' @section Validation:
#' add_counts() performs Tier 1 validation:
#' - Count data schema (Date column, numeric column) via validate_count_schema()
#' - Design column presence (date_col, strata_cols, PSU in count data)
#' - No NA values in design-critical columns (date, strata, PSU)
#' - Survey construction (catches lonely PSU errors, stratification issues)
#'
#' @section PSU Specification:
#' Per user decision (clarified 2026-02-08), PSU is specified only in add_counts(),
#' not in creel_design() constructor. PSU is only meaningful when count data is
#' present, making add_counts() the correct abstraction boundary. This design
#' allows the same creel_design calendar to be used with different PSU structures.
#'
#' @examples
#' # Basic usage - day as PSU (default)
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' counts <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   count = c(15, 23, 45, 52)
#' )
#'
#' design_with_counts <- add_counts(design, counts)
#' print(design_with_counts)
#'
#' # Custom PSU column
#' counts_with_site_psu <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   site_day = paste0("site_", 1:4),
#'   count = c(15, 23, 45, 52)
#' )
#'
#' design2 <- add_counts(design, counts_with_site_psu, psu = "site_day")
#'
#' @export
add_counts <- function(design, counts, psu = NULL, allow_invalid = FALSE) {
  # Validate design is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Check counts not already attached
  if (!is.null(design$counts)) {
    cli::cli_abort(c(
      "Counts already attached to design.",
      "x" = "The design object already has count data in the {.field $counts} slot.",
      "i" = "Create a new design with {.fn creel_design} to attach different counts.",
      "i" = "Use immutable workflow: {.code design2 <- add_counts(design, counts)}"
    ))
  }

  # Validate count data schema (Date column, numeric column)
  validate_count_schema(counts) # nolint: object_usage_linter

  # Set PSU column (default to date_col for day-as-PSU)
  if (is.null(psu)) {
    psu <- design$date_col
  }

  # Validate counts structure (Tier 1)
  validation <- validate_counts_tier1(counts, design, psu, allow_invalid) # nolint: object_usage_linter

  # Copy design and add counts + PSU
  new_design <- design
  new_design$counts <- counts
  new_design$psu_col <- psu

  # Construct survey design eagerly
  new_design$survey <- construct_survey_design(new_design) # nolint: object_usage_linter

  # Store validation results
  new_design$validation <- validation

  # Preserve class
  class(new_design) <- "creel_design"

  new_design
}

#' Attach interview data to a creel design
#'
#' @description
#' Attaches interview data (catch, effort, and optionally harvest per completed
#' fishing trip) to a creel_design object and constructs the internal interview
#' survey design object eagerly. This enables catch rate and harvest rate
#' estimation from angler interviews. Follows the same tidy selector API pattern
#' as [add_counts()].
#'
#' @param design A creel_design object (created with [creel_design()])
#' @param interviews Data frame containing interview data. Must have:
#'   - A Date column matching the design's date_col
#'   - Numeric catch column (total fish caught per trip)
#'   - Numeric effort column (fishing time per trip, e.g., hours)
#'   - Character trip status column ("complete" or "incomplete")
#'   - Optional numeric harvest column (fish kept per trip)
#'   - Optional numeric trip duration column (hours) OR trip_start + interview_time columns (POSIXct)
#' @param catch Tidy selector for total catch column (required). Use bare column
#'   names (e.g., `catch = catch_total`) or tidyselect helpers.
#' @param effort Tidy selector for fishing effort column (required, e.g.,
#'   `effort = hours_fished`). Should represent time spent fishing per trip.
#' @param harvest Tidy selector for harvest (kept fish) column (optional,
#'   default NULL). If provided, will be validated for consistency (harvest <= catch).
#' @param trip_status Tidy selector for trip completion status column (required).
#'   Must contain "complete" or "incomplete" (case-insensitive). This is essential
#'   for downstream incomplete trip estimators.
#' @param trip_duration Tidy selector for trip duration column in hours (optional,
#'   default NULL). Provide either trip_duration OR trip_start + interview_time,
#'   not both. Duration values must be positive and >= 1/60 hours (1 minute).
#' @param trip_start Tidy selector for trip start time column (optional, default NULL).
#'   Must be POSIXct or POSIXlt. Requires interview_time to calculate duration.
#'   Use when duration needs to be calculated from timestamps.
#' @param interview_time Tidy selector for interview time column (optional, default NULL).
#'   Must be POSIXct or POSIXlt. Requires trip_start to calculate duration.
#'   Duration is calculated as interview_time - trip_start in hours.
#' @param n_counted Tidy selector for the count of all anglers observed at the
#'   site during the sampling period (required for bus-route designs, ignored
#'   for other designs). Values must be non-negative integers. Must satisfy
#'   n_counted >= n_interviewed.
#' @param n_interviewed Tidy selector for the count of anglers actually
#'   interviewed at the site (required for bus-route designs, ignored for
#'   other designs). Values of 0 are valid (no anglers came off the water).
#' @param angler_type Tidy selector for angler type column (optional, default
#'   NULL). Use bare column names (e.g., `angler_type = angler_type`). Common
#'   values are "bank" and "boat". Not validated in Phase 28; downstream summary
#'   functions use this field.
#' @param angler_method Tidy selector for angler method column (optional, default
#'   NULL). Use bare column names (e.g., `angler_method = method_code`). Records
#'   the fishing technique employed (e.g., "fly", "spin", "bait").
#' @param species_sought Tidy selector for species sought column (optional, default
#'   NULL). Use bare column names (e.g., `species_sought = target_species`).
#'   Records the species the angler was targeting during the interview.
#' @param n_anglers Tidy selector for the number of anglers in the party (optional,
#'   default NULL). Use bare column names (e.g., `n_anglers = party_size`).
#'   Values should be positive integers.
#' @param refused Tidy selector for the refused interview flag column (optional,
#'   default NULL). Use bare column names (e.g., `refused = refused_flag`).
#'   Values should be logical (TRUE/FALSE) or coercible to logical.
#' @param date_col Character name of date column in interviews (default NULL,
#'   which uses the design's date_col). Specify explicitly if interview data
#'   uses a different date column name than the design calendar.
#' @param interview_type Character: "access" (complete trips at access point)
#'   or "roving" (incomplete trips during fishing). Default is "access". This
#'   affects how catch rates are calculated in estimation functions.
#' @param allow_invalid Logical flag for validation behavior. If FALSE (default),
#'   validation failures abort with detailed error messages. If TRUE, validation
#'   failures generate warnings and attach interviews anyway (use with caution).
#'
#' @return A new creel_design object (list) with components:
#'   \item{calendar}{Original calendar data frame}
#'   \item{date_col}{Character name of date column}
#'   \item{strata_cols}{Character vector of strata column names}
#'   \item{site_col}{Character name of site column, or NULL}
#'   \item{design_type}{Character design type}
#'   \item{counts}{Count data frame (if previously attached, or NULL)}
#'   \item{interviews}{The interview data frame (newly attached)}
#'   \item{catch_col}{Character name of catch column}
#'   \item{effort_col}{Character name of effort column}
#'   \item{harvest_col}{Character name of harvest column, or NULL}
#'   \item{trip_status_col}{Character name of trip status column}
#'   \item{trip_duration_col}{Character name of trip duration column, or NULL}
#'   \item{trip_start_col}{Character name of trip start time column, or NULL}
#'   \item{interview_time_col}{Character name of interview time column, or NULL}
#'   \item{interview_type}{Character interview type}
#'   \item{interview_survey}{Internal survey.design2 object (newly constructed)}
#'   \item{validation}{creel_validation object with Tier 1 results}
#'
#' @section Immutability:
#' add_interviews() follows functional programming patterns and returns a new
#' creel_design object. The original design object is not modified. This
#' prevents accidental data loss and makes the workflow explicit:
#' `design2 <- add_interviews(design, interviews, ...)` not `add_interviews(design, interviews, ...)`
#'
#' @section Validation:
#' add_interviews() performs Tier 1 validation:
#' - Interview data schema (Date column, numeric columns) via validate_interview_schema()
#' - Design column presence (date_col exists in interview data)
#' - No NA values in date column
#' - Interview dates exist in design calendar
#' - Catch and effort columns exist and are numeric
#' - Harvest column exists and is numeric (if provided)
#' - Harvest <= catch consistency (if harvest provided)
#' - Trip status valid ("complete" or "incomplete", case-insensitive)
#' - Trip status has no NA values
#' - Trip duration/time inputs are mutually exclusive (error if both provided)
#' - Trip duration is positive, >= 1 minute, warns if > 48 hours
#' - Trip start + interview_time are POSIXct/POSIXlt, calculate valid duration
#' - Interview survey construction (catches stratification issues)
#'
#' @section Calendar Integration:
#' Interview dates are automatically linked to the design calendar via date
#' matching. Strata from the calendar are inherited by the interview data,
#' enabling stratified estimation of catch rates.
#'
#' @examples
#' # Basic usage - with trip status and duration
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' interviews <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   catch_total = c(5, 3, 7, 2),
#'   hours_fished = c(2.0, 2.5, 3.0, 1.5),
#'   trip_status = c("complete", "complete", "incomplete", "complete"),
#'   trip_duration = c(2.0, 2.5, 1.5, 1.5)
#' )
#'
#' design_with_interviews <- add_interviews(
#'   design, interviews,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   trip_status = trip_status,
#'   trip_duration = trip_duration
#' )
#' print(design_with_interviews)
#'
#' # With harvest column and calculated duration from timestamps
#' interviews2 <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   catch_total = c(5, 3, 7, 2),
#'   catch_kept = c(2, 1, 5, 2),
#'   hours_fished = c(2.0, 2.5, 3.0, 1.5),
#'   trip_status = c("complete", "incomplete", "complete", "complete"),
#'   trip_start = as.POSIXct(c(
#'     "2024-06-01 08:00", "2024-06-02 09:00",
#'     "2024-06-03 07:00", "2024-06-04 10:00"
#'   )),
#'   interview_time = as.POSIXct(c(
#'     "2024-06-01 10:00", "2024-06-02 11:30",
#'     "2024-06-03 10:00", "2024-06-04 11:30"
#'   ))
#' )
#'
#' design2 <- add_interviews(
#'   design, interviews2,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   harvest = catch_kept,
#'   trip_status = trip_status,
#'   trip_start = trip_start,
#'   interview_time = interview_time
#' )
#'
#' @export
add_interviews <- function(design, interviews,
                           catch, effort, harvest = NULL,
                           trip_status,
                           trip_duration = NULL,
                           trip_start = NULL,
                           interview_time = NULL,
                           n_counted = NULL,
                           n_interviewed = NULL,
                           angler_type = NULL,
                           angler_method = NULL,
                           species_sought = NULL,
                           n_anglers = NULL,
                           refused = NULL,
                           date_col = NULL,
                           interview_type = c("access", "roving"),
                           allow_invalid = FALSE) {
  # Validate design is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Check interviews not already attached
  if (!is.null(design$interviews)) {
    cli::cli_abort(c(
      "Interviews already attached to design.",
      "x" = "The design object already has interview data in the {.field $interviews} slot.",
      "i" = "Create a new design with {.fn creel_design} to attach different interviews.",
      "i" = "Use immutable workflow: {.code design2 <- add_interviews(design, interviews, ...)}"
    ))
  }

  # Validate interview data schema (Date column, numeric column)
  validate_interview_schema(interviews) # nolint: object_usage_linter

  # Resolve tidy selectors
  catch_col <- resolve_single_col(
    rlang::enquo(catch),
    interviews,
    "catch",
    rlang::caller_env()
  )

  effort_col <- resolve_single_col(
    rlang::enquo(effort),
    interviews,
    "effort",
    rlang::caller_env()
  )

  # Resolve harvest column (optional)
  harvest_col <- NULL
  harvest_quo <- rlang::enquo(harvest)
  if (!rlang::quo_is_null(harvest_quo)) {
    harvest_col <- resolve_single_col(
      harvest_quo,
      interviews,
      "harvest",
      rlang::caller_env()
    )
  }

  # Resolve trip_status column (required)
  trip_status_col <- resolve_single_col(
    rlang::enquo(trip_status),
    interviews,
    "trip_status",
    rlang::caller_env()
  )

  # Resolve trip duration input method
  trip_duration_col <- NULL
  trip_start_col <- NULL
  interview_time_col <- NULL

  trip_duration_quo <- rlang::enquo(trip_duration)
  trip_start_quo <- rlang::enquo(trip_start)
  interview_time_quo <- rlang::enquo(interview_time)

  if (!rlang::quo_is_null(trip_duration_quo)) {
    trip_duration_col <- resolve_single_col(
      trip_duration_quo,
      interviews,
      "trip_duration",
      rlang::caller_env()
    )
  }

  if (!rlang::quo_is_null(trip_start_quo)) {
    trip_start_col <- resolve_single_col(
      trip_start_quo,
      interviews,
      "trip_start",
      rlang::caller_env()
    )
  }

  if (!rlang::quo_is_null(interview_time_quo)) {
    interview_time_col <- resolve_single_col(
      interview_time_quo,
      interviews,
      "interview_time",
      rlang::caller_env()
    )
  }

  # Resolve n_counted column (optional; required for bus_route)
  n_counted_col <- NULL
  n_counted_quo <- rlang::enquo(n_counted)
  if (!rlang::quo_is_null(n_counted_quo)) {
    n_counted_col <- resolve_single_col(
      n_counted_quo, interviews, "n_counted", rlang::caller_env()
    )
  }

  # Resolve n_interviewed column (optional; required for bus_route)
  n_interviewed_col <- NULL
  n_interviewed_quo <- rlang::enquo(n_interviewed)
  if (!rlang::quo_is_null(n_interviewed_quo)) {
    n_interviewed_col <- resolve_single_col(
      n_interviewed_quo, interviews, "n_interviewed", rlang::caller_env()
    )
  }

  # Resolve angler_type column (optional)
  angler_type_col <- NULL
  angler_type_quo <- rlang::enquo(angler_type)
  if (!rlang::quo_is_null(angler_type_quo)) {
    angler_type_col <- resolve_single_col(
      angler_type_quo, interviews, "angler_type", rlang::caller_env()
    )
  }

  # Resolve angler_method column (optional)
  angler_method_col <- NULL
  angler_method_quo <- rlang::enquo(angler_method)
  if (!rlang::quo_is_null(angler_method_quo)) {
    angler_method_col <- resolve_single_col(
      angler_method_quo, interviews, "angler_method", rlang::caller_env()
    )
  }

  # Resolve species_sought column (optional)
  species_sought_col <- NULL
  species_sought_quo <- rlang::enquo(species_sought)
  if (!rlang::quo_is_null(species_sought_quo)) {
    species_sought_col <- resolve_single_col(
      species_sought_quo, interviews, "species_sought", rlang::caller_env()
    )
  }

  # Resolve n_anglers column (optional)
  n_anglers_col <- NULL
  n_anglers_quo <- rlang::enquo(n_anglers)
  if (!rlang::quo_is_null(n_anglers_quo)) {
    n_anglers_col <- resolve_single_col(
      n_anglers_quo, interviews, "n_anglers", rlang::caller_env()
    )
  }

  # Resolve refused column (optional)
  refused_col <- NULL
  refused_quo <- rlang::enquo(refused)
  if (!rlang::quo_is_null(refused_quo)) {
    refused_col <- resolve_single_col(
      refused_quo, interviews, "refused", rlang::caller_env()
    )
  }

  # Set date_col (default to design$date_col)
  if (is.null(date_col)) {
    date_col <- design$date_col
  }

  # Match interview_type
  interview_type <- match.arg(interview_type)

  # Validate interviews structure (Tier 1)
  validation <- validate_interviews_tier1(interviews, design, catch_col, effort_col, harvest_col, date_col, allow_invalid) # nolint: object_usage_linter

  # Validate trip metadata
  validate_trip_metadata(interviews, trip_status_col, trip_duration_col, trip_start_col, interview_time_col) # nolint: object_usage_linter

  # Tier 3: Bus-route specific validation
  if (!is.null(design$bus_route)) {
    validate_br_interviews_tier3(
      interviews         = interviews,
      design             = design,
      n_counted_col      = n_counted_col,
      n_interviewed_col  = n_interviewed_col
    )
  }

  # Calculate duration if needed (from trip_start + interview_time)
  if (!is.null(trip_start_col) && !is.null(interview_time_col) && is.null(trip_duration_col)) {
    interviews[[".trip_duration_hrs"]] <- as.numeric(
      difftime(interviews[[interview_time_col]], interviews[[trip_start_col]], units = "hours")
    )
    trip_duration_col <- ".trip_duration_hrs"
  }

  # Normalize trip_status to lowercase
  interviews[[trip_status_col]] <- tolower(interviews[[trip_status_col]])

  # Join interviews with calendar
  interviews_joined <- dplyr::left_join(
    interviews,
    design$calendar,
    by = stats::setNames(design$date_col, date_col),
    suffix = c("", "_cal")
  )

  # Bus-route: join pi_i from sampling frame and compute expansion factor
  if (!is.null(design$bus_route)) {
    br <- design$bus_route
    site_col <- br$site_col
    circuit_col <- br$circuit_col
    pi_i_col <- br$pi_i_col

    # Extract site/circuit/pi_i lookup from sampling frame
    sf_lookup <- br$data[, c(site_col, circuit_col, pi_i_col)]

    # Join pi_i to interview rows; unmatched rows will have NA in .pi_i
    interviews_joined <- dplyr::left_join(
      interviews_joined,
      sf_lookup,
      by = stats::setNames(
        c(site_col, circuit_col),
        c(site_col, circuit_col)
      )
    )

    # Error if any interview row could not be matched (NA in .pi_i after join)
    unmatched <- is.na(interviews_joined[[pi_i_col]])
    if (any(unmatched)) {
      bad_rows <- interviews_joined[unmatched, c(site_col, circuit_col), drop = FALSE]
      bad_combos <- unique(paste0(bad_rows[[site_col]], " / ", bad_rows[[circuit_col]])) # nolint: object_usage_linter
      cli::cli_abort(c(
        "Interview site+circuit combinations not found in sampling frame:",
        stats::setNames(paste0("{.val ", bad_combos, "}"), rep("x", length(bad_combos))),
        "i" = "Check that interview site and circuit values match the sampling frame exactly.",
        "i" = "Sampling frame has {.val {nrow(br$data)}} site-circuit row{?s}."
      ))
    }

    # Compute expansion factor: n_counted / n_interviewed
    # n_interviewed = 0 treated as NA expansion (zero-interview observation; no expansion defined)
    if (!is.null(n_counted_col) && !is.null(n_interviewed_col)) {
      nc <- interviews_joined[[n_counted_col]]
      ni <- interviews_joined[[n_interviewed_col]]
      interviews_joined[[".expansion"]] <- ifelse(ni == 0L, NA_real_, nc / ni)

      # Warn when n_counted > 0 and n_interviewed = 0 (anglers seen but none interviewed)
      partial_zero <- nc > 0 & ni == 0
      if (any(partial_zero, na.rm = TRUE)) {
        n_partial <- sum(partial_zero, na.rm = TRUE) # nolint: object_usage_linter
        cli::cli_warn(c(
          "!" = "{n_partial} observation{?s} ha{?s/ve} n_counted > 0 but n_interviewed = 0.",
          "i" = "Anglers were counted but none interviewed. These rows contribute no catch data.",
          "i" = "Expansion factor (.expansion) is NA for these rows."
        ))
      }
    }
  }

  # Copy design and add interview fields
  new_design <- design
  new_design$interviews <- interviews_joined
  new_design$catch_col <- catch_col
  new_design$effort_col <- effort_col
  new_design$harvest_col <- harvest_col
  new_design$interview_type <- interview_type
  new_design$trip_status_col <- trip_status_col
  new_design$trip_duration_col <- trip_duration_col
  new_design$trip_start_col <- trip_start_col
  new_design$interview_time_col <- interview_time_col

  # Construct interview survey eagerly
  new_design$interview_survey <- construct_interview_survey(new_design) # nolint: object_usage_linter

  # Store validation results
  new_design$validation <- validation

  # Warn for Tier 2 data quality issues
  warn_tier2_interview_issues(new_design) # nolint: object_usage_linter

  # Trip status summary
  status_table <- table(tolower(new_design$interviews[[trip_status_col]]))
  n_complete <- as.integer(status_table["complete"])
  n_incomplete <- as.integer(status_table["incomplete"])
  if (is.na(n_complete)) n_complete <- 0L
  if (is.na(n_incomplete)) n_incomplete <- 0L
  n_total <- n_complete + n_incomplete
  pct_complete <- round(100 * n_complete / n_total, 0) # nolint: object_usage_linter
  pct_incomplete <- round(100 * n_incomplete / n_total, 0) # nolint: object_usage_linter
  cli::cli_inform(c( # nolint: line_length_linter
    "i" = "Added {n_total} interview{?s}: {n_complete} complete ({pct_complete}%), {n_incomplete} incomplete ({pct_incomplete}%)" # nolint: line_length_linter
  ))

  # Store bus-route enumeration column names
  new_design$n_counted_col <- n_counted_col
  new_design$n_interviewed_col <- n_interviewed_col

  # Store extended interview fields
  new_design$angler_type_col <- angler_type_col
  new_design$angler_method_col <- angler_method_col
  new_design$species_sought_col <- species_sought_col
  new_design$n_anglers_col <- n_anglers_col
  new_design$refused_col <- refused_col

  # Preserve class
  class(new_design) <- "creel_design"

  new_design
}

#' Format a creel_design object
#'
#' @param x A creel_design object
#' @param ... Additional arguments (ignored)
#'
#' @return A character vector with the formatted output
#'
#' @export
format.creel_design <- function(x, ...) {
  cli::cli_format_method({
    cli::cli_h1("Creel Survey Design")
    cli::cli_text("Type: {.val {x$design_type}}")
    cli::cli_text("Date column: {.field {x$date_col}}")
    cli::cli_text("Strata: {.field {paste(x$strata_cols, collapse = ', ')}}")
    if (!is.null(x$site_col)) {
      cli::cli_text("Site column: {.field {x$site_col}}")
    }

    n_days <- nrow(x$calendar) # nolint: object_usage_linter
    date_range <- range(x$calendar[[x$date_col]]) # nolint: object_usage_linter
    cli::cli_text("Calendar: {.val {n_days}} day{?s} ({date_range[1]} to {date_range[2]})")

    # Strata summary
    for (col in x$strata_cols) {
      levels <- unique(x$calendar[[col]]) # nolint: object_usage_linter
      cli::cli_text("  {.field {col}}: {.val {length(levels)}} level{?s}")
    }

    has_counts <- !is.null(x$counts) # nolint: object_usage_linter
    has_survey <- !is.null(x$survey) # nolint: object_usage_linter
    if (has_counts) {
      n_counts <- nrow(x$counts) # nolint: object_usage_linter
      psu_col <- x$psu_col # nolint: object_usage_linter
      cli::cli_text("Counts: {.val {n_counts}} observation{?s}")
      cli::cli_text("  PSU column: {.field {psu_col}}")
      if (has_survey) {
        survey_class <- class(x$survey)[1] # nolint: object_usage_linter
        cli::cli_text("  Survey: {.cls {survey_class}} (constructed)")
      }
    } else {
      cli::cli_text("Counts: {.val none}")
    }

    has_interviews <- !is.null(x$interviews) # nolint: object_usage_linter
    if (has_interviews) {
      n_interviews <- nrow(x$interviews) # nolint: object_usage_linter
      interview_type <- x$interview_type # nolint: object_usage_linter
      catch_col <- x$catch_col # nolint: object_usage_linter
      effort_col <- x$effort_col # nolint: object_usage_linter
      cli::cli_text("Interviews: {.val {n_interviews}} observation{?s}")
      cli::cli_text("  Type: {.val {interview_type}}")
      cli::cli_text("  Catch: {.field {catch_col}}")
      cli::cli_text("  Effort: {.field {effort_col}}")
      if (!is.null(x$harvest_col)) {
        harvest_col <- x$harvest_col # nolint: object_usage_linter
        cli::cli_text("  Harvest: {.field {harvest_col}}")
      }
      if (!is.null(x$trip_status_col)) {
        trip_status_col <- x$trip_status_col # nolint: object_usage_linter
        status_table <- table(tolower(x$interviews[[trip_status_col]])) # nolint: object_usage_linter
        n_complete <- as.integer(status_table["complete"]) # nolint: object_usage_linter
        n_incomplete <- as.integer(status_table["incomplete"]) # nolint: object_usage_linter
        if (is.na(n_complete)) n_complete <- 0L
        if (is.na(n_incomplete)) n_incomplete <- 0L
        cli::cli_text("  Trip status: {n_complete} complete, {n_incomplete} incomplete")
      }
      if (!is.null(x$angler_type_col)) {
        angler_type_col <- x$angler_type_col # nolint: object_usage_linter
        cli::cli_text("  Angler type: {.field {angler_type_col}}")
      }
      if (!is.null(x$angler_method_col)) {
        angler_method_col <- x$angler_method_col # nolint: object_usage_linter
        cli::cli_text("  Angler method: {.field {angler_method_col}}")
      }
      if (!is.null(x$species_sought_col)) {
        species_sought_col <- x$species_sought_col # nolint: object_usage_linter
        cli::cli_text("  Species sought: {.field {species_sought_col}}")
      }
      if (!is.null(x$n_anglers_col)) {
        n_anglers_col <- x$n_anglers_col # nolint: object_usage_linter
        cli::cli_text("  Party size: {.field {n_anglers_col}}")
      }
      if (!is.null(x$refused_col)) {
        refused_col <- x$refused_col # nolint: object_usage_linter
        cli::cli_text("  Refused: {.field {refused_col}}")
      }
      if (!is.null(x$interview_survey)) {
        interview_survey_class <- class(x$interview_survey)[1] # nolint: object_usage_linter
        cli::cli_text("  Survey: {.cls {interview_survey_class}} (constructed)")
      }
    } else {
      cli::cli_text("Interviews: {.val none}")
    }

    # Bus-Route section
    if (!is.null(x$bus_route)) {
      br <- x$bus_route$data
      site_col <- x$bus_route$site_col # nolint: object_usage_linter
      circ_col <- x$bus_route$circuit_col # nolint: object_usage_linter
      ps_col <- x$bus_route$p_site_col # nolint: object_usage_linter
      pp_col <- x$bus_route$p_period_col # nolint: object_usage_linter
      pi_col <- x$bus_route$pi_i_col # nolint: object_usage_linter
      n_sites <- length(unique(br[[site_col]])) # nolint: object_usage_linter
      n_circs <- length(unique(br[[circ_col]])) # nolint: object_usage_linter
      cli::cli_h2("Bus-Route Design")
      cli::cli_text("Sites: {.val {n_sites}}, Circuits: {.val {n_circs}}")
      cli::cli_text("Sampling probabilities (pi_i = p_site * p_period):")
      # Display table rows — site | circuit | p_site | p_period | pi_i
      # Show at most 10 rows to avoid overwhelming output; indicate truncation
      max_rows <- min(nrow(br), 10L)
      for (i in seq_len(max_rows)) {
        site_val <- br[[site_col]][i] # nolint: object_usage_linter
        circ_val <- br[[circ_col]][i] # nolint: object_usage_linter
        ps_val <- round(br[[ps_col]][i], 4) # nolint: object_usage_linter
        pp_val <- round(br[[pp_col]][i], 4) # nolint: object_usage_linter
        pi_val <- round(br[[pi_col]][i], 4) # nolint: object_usage_linter
        cli::cli_text(
          "  {.field {site_val}} [{circ_val}]: p_site={ps_val}, p_period={pp_val}, pi_i={pi_val}"
        )
      }
      if (nrow(br) > 10L) {
        remaining <- nrow(br) - 10L # nolint: object_usage_linter
        cli::cli_text("  ... and {remaining} more row{?s}")
      }

      # Enumeration Counts section (only if interviews are attached with counts)
      if (!is.null(x$interviews) && !is.null(x$n_counted_col) && !is.null(x$n_interviewed_col)) {
        nc_col <- x$n_counted_col
        ni_col <- x$n_interviewed_col
        site_col_br <- x$bus_route$site_col
        circ_col_br <- x$bus_route$circuit_col
        ivw <- x$interviews

        cli::cli_h2("Enumeration Counts")
        cli::cli_text("(n_counted observed, n_interviewed interviewed, expansion = n_counted/n_interviewed)")

        # Summarize by site + circuit: sum n_counted, sum n_interviewed
        grp_keys <- c(site_col_br, circ_col_br)
        agg_nc <- stats::aggregate(
          ivw[[nc_col]],
          by = ivw[grp_keys],
          FUN = sum, na.rm = TRUE
        )
        agg_ni <- stats::aggregate(
          ivw[[ni_col]],
          by = ivw[grp_keys],
          FUN = sum, na.rm = TRUE
        )
        names(agg_nc)[length(agg_nc)] <- "nc_sum"
        names(agg_ni)[length(agg_ni)] <- "ni_sum"
        enum_summary <- merge(agg_nc, agg_ni, by = grp_keys)
        enum_summary$expansion <- ifelse(
          enum_summary$ni_sum == 0,
          NA_real_,
          enum_summary$nc_sum / enum_summary$ni_sum
        )

        max_rows_enum <- min(nrow(enum_summary), 10L)
        for (i in seq_len(max_rows_enum)) {
          sv <- enum_summary[[site_col_br]][i] # nolint: object_usage_linter
          cv <- enum_summary[[circ_col_br]][i] # nolint: object_usage_linter
          nc <- enum_summary$nc_sum[i] # nolint: object_usage_linter
          ni <- enum_summary$ni_sum[i] # nolint: object_usage_linter
          exp_val <- if (is.na(enum_summary$expansion[i])) { # nolint: object_usage_linter
            "NA (0 interviewed)"
          } else {
            round(enum_summary$expansion[i], 2)
          }
          cli::cli_text(
            "  {.field {sv}} [{cv}]: counted={nc}, interviewed={ni}, expansion={exp_val}"
          )
        }
        if (nrow(enum_summary) > 10L) {
          remaining_enum <- nrow(enum_summary) - 10L # nolint: object_usage_linter
          cli::cli_text("  ... and {remaining_enum} more row{?s}")
        }
      }
    }
  })
}

#' Print a creel_design object
#'
#' @param x A creel_design object
#' @param ... Additional arguments passed to [format.creel_design()]
#'
#' @return Invisibly returns the input object
#'
#' @export
print.creel_design <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' Extract the sampling frame from a bus-route creel design
#'
#' @description
#' Returns the sampling frame data frame stored in a bus-route `creel_design`
#' object. The data frame contains the user's original columns plus a
#' precomputed `.pi_i` column (pi_i = p_site * p_period). Aborts with an
#' informative error for non-bus-route designs.
#'
#' @param design A `creel_design` object with `design_type = "bus_route"`.
#'
#' @return A data frame: the `sampling_frame` as stored in the design, with
#'   the addition of a `.pi_i` column and (if circuit was omitted) a
#'   `.circuit` column.
#'
#' @examples
#' sf <- data.frame(
#'   site     = c("A", "B", "C"),
#'   p_site   = c(0.3, 0.4, 0.3),
#'   p_period = 0.5
#' )
#' calendar <- data.frame(
#'   date     = as.Date("2024-06-01"),
#'   day_type = "weekday"
#' )
#' design <- creel_design(calendar,
#'   date = date,
#'   strata = day_type,
#'   survey_type = "bus_route",
#'   sampling_frame = sf,
#'   site = site,
#'   p_site = p_site,
#'   p_period = p_period
#' )
#' get_sampling_frame(design)
#'
#' @export
get_sampling_frame <- function(design) {
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }
  if (is.null(design$bus_route)) {
    cli::cli_abort(c(
      "{.fn get_sampling_frame} is only available for bus-route designs.",
      "x" = "This design has {.field design_type} = {.val {design$design_type}}.",
      "i" = "Create a bus-route design with {.code creel_design(..., survey_type = 'bus_route')}."
    ))
  }
  design$bus_route$data
}

#' Get inclusion probabilities from a bus-route design
#'
#' Returns the computed inclusion probabilities
#' (\eqn{\pi_i = p_{\text{site}} \times p_{\text{period}}}) for each
#' site-circuit combination in a bus-route creel design. The inclusion
#' probability represents the two-stage sampling probability: the probability
#' that a particular site is visited during a particular sampling period,
#' combining both the site selection probability within the circuit and the
#' circuit (period) selection probability.
#'
#' @param design A [creel_design()] object created with
#'   `survey_type = "bus_route"`.
#'
#' @return A data frame with three columns: the site identifier column, the
#'   circuit identifier column, and `.pi_i` (the computed inclusion
#'   probability \eqn{\pi_i = p_{\text{site}} \times p_{\text{period}}} for
#'   each site-circuit unit). Column names for site and circuit match the
#'   resolved column names from the original sampling frame (or `.circuit`
#'   for designs without an explicit circuit column).
#'
#' @references
#' Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
#' estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
#' & T. M. Sutton (Eds.), *Fisheries Techniques* (3rd ed., pp. 883--919).
#' American Fisheries Society. Definition of \eqn{\pi_i} for two-stage
#' bus-route sampling, used in Eq. 19.4 and 19.5.
#'
#' @seealso [creel_design()], [get_sampling_frame()]
#'
#' @examples
#' sf <- data.frame(
#'   site = c("A", "B", "C"),
#'   p_site = c(0.3, 0.4, 0.3),
#'   p_period = rep(0.5, 3),
#'   stringsAsFactors = FALSE
#' )
#' cal <- data.frame(
#'   date = as.Date("2024-06-01"),
#'   day_type = "weekday",
#'   stringsAsFactors = FALSE
#' )
#' design <- creel_design(cal,
#'   date = date, strata = day_type,
#'   survey_type = "bus_route", sampling_frame = sf,
#'   site = site, p_site = p_site, p_period = p_period
#' )
#' get_inclusion_probs(design)
#'
#' @export
get_inclusion_probs <- function(design) {
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }
  if (is.null(design$bus_route)) {
    cli::cli_abort(c(
      "{.fn get_inclusion_probs} is only available for bus-route designs.",
      "x" = "This design has {.field design_type} = {.val {design$design_type}}.",
      "i" = "Create a bus-route design with {.code creel_design(..., survey_type = 'bus_route')}."
    ))
  }
  br <- design$bus_route
  br$data[, c(br$site_col, br$circuit_col, br$pi_i_col)]
}

#' Get enumeration counts from a bus-route creel design with interviews
#'
#' @description
#' Returns the enumeration count data (observed and interviewed angler counts,
#' and the expansion factor) for each interview record in a bus-route
#' \code{creel_design} with interviews attached via \code{\link{add_interviews}}.
#'
#' The expansion factor \eqn{n\_counted / n\_interviewed} accounts for anglers
#' present at a site who were not interviewed. It is used during bus-route
#' effort and harvest estimation (Jones & Pollock (2012) Eq. 19.4 and 19.5).
#'
#' @param design A \code{creel_design} object with \code{design_type = "bus_route"}
#'   and interview data attached via \code{\link{add_interviews}}.
#'
#' @return A data frame with the site identifier column, the circuit identifier
#'   column, \code{n_counted} (resolved column name), \code{n_interviewed}
#'   (resolved column name), and \code{.expansion} (n_counted / n_interviewed,
#'   NA when n_interviewed = 0).
#'
#' @references
#' Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
#' estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
#' & T. M. Sutton (Eds.), \emph{Fisheries Techniques} (3rd ed., pp. 883--919).
#' American Fisheries Society. Enumeration expansion factor used in Eq. 19.4
#' and 19.5 for bus-route effort and harvest estimation.
#'
#' @seealso [creel_design()], [add_interviews()], [get_sampling_frame()],
#'   [get_inclusion_probs()]
#'
#' @examples
#' cal <- data.frame(
#'   date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06")),
#'   day_type = "weekday"
#' )
#' sf <- data.frame(
#'   site = c("A", "B"),
#'   circuit = c("am", "am"),
#'   p_site = c(0.6, 0.4),
#'   p_period = rep(0.5, 2)
#' )
#' design_br <- creel_design(
#'   cal,
#'   date = date, strata = day_type,
#'   survey_type = "bus_route", sampling_frame = sf,
#'   site = site, circuit = circuit,
#'   p_site = p_site, p_period = p_period
#' )
#' interviews <- data.frame(
#'   date = as.Date(c("2024-06-03", "2024-06-04")),
#'   site = c("A", "B"), circuit = c("am", "am"),
#'   catch_total = c(3L, 2L), hours_fished = c(2.0, 1.5),
#'   trip_status = c("complete", "complete"),
#'   trip_duration = c(2.0, 1.5),
#'   n_counted = c(5L, 4L), n_interviewed = c(3L, 2L)
#' )
#' design2 <- add_interviews(
#'   design_br, interviews,
#'   catch = catch_total, effort = hours_fished,
#'   trip_status = trip_status, trip_duration = trip_duration,
#'   n_counted = n_counted, n_interviewed = n_interviewed
#' )
#' get_enumeration_counts(design2)
#'
#' @export
get_enumeration_counts <- function(design) {
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }
  if (is.null(design$bus_route)) {
    cli::cli_abort(c(
      "{.fn get_enumeration_counts} is only available for bus-route designs.",
      "x" = "This design has {.field design_type} = {.val {design$design_type}}.",
      "i" = "Create a bus-route design with {.code creel_design(..., survey_type = 'bus_route')}."
    ))
  }
  if (is.null(design$interviews)) {
    hint_msg <- "Call {.fn add_interviews} with {.arg n_counted}" # nolint: object_usage_linter
    cli::cli_abort(c(
      "{.fn get_enumeration_counts} requires interview data.",
      "x" = "No interviews found in design.",
      "i" = "{hint_msg} and {.arg n_interviewed} before accessing enumeration counts."
    ))
  }
  if (is.null(design$n_counted_col) || is.null(design$n_interviewed_col)) {
    cli::cli_abort(c(
      "{.fn get_enumeration_counts} requires enumeration columns.",
      "x" = "Interviews were attached without {.arg n_counted} or {.arg n_interviewed}.",
      "i" = "Re-attach interviews using {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} specified."
    ))
  }

  br <- design$bus_route
  site_col <- br$site_col
  circuit_col <- br$circuit_col
  nc_col <- design$n_counted_col
  ni_col <- design$n_interviewed_col

  design$interviews[, c(site_col, circuit_col, nc_col, ni_col, ".expansion")]
}

#' Extract per-site effort contributions from a bus-route estimate
#'
#' Returns the per-site calculation table (eᵢ, πᵢ, eᵢ/πᵢ) stored as an
#' attribute on effort estimate objects returned by [estimate_effort()] for
#' bus-route survey designs. This table enables traceability of the
#' Horvitz-Thompson estimator (Jones & Pollock 2012, Eq. 19.4) and supports
#' validation against published examples (Malvestuto 1996, Box 20.6).
#'
#' @param x A creel_estimates object returned by [estimate_effort()] for a
#'   bus-route design.
#'
#' @return A tibble with columns:
#'   \item{site}{Site identifier (from sampling frame)}
#'   \item{circuit}{Circuit identifier (from sampling frame)}
#'   \item{e_i}{Enumeration-expanded effort at site i (effort * expansion)}
#'   \item{pi_i}{Inclusion probability for site i (p_site * p_period)}
#'   \item{e_i_over_pi_i}{Site contribution to Horvitz-Thompson estimate}
#'
#' @references
#' Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
#' estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
#' & T. M. Sutton (Eds.), *Fisheries Techniques* (3rd ed., pp. 883-919).
#' American Fisheries Society.
#'
#' @seealso [estimate_effort()], [get_sampling_frame()], [get_inclusion_probs()],
#'   [get_enumeration_counts()]
#'
#' @examples
#' # (Bus-route design + add_interviews() required — see estimate_effort() docs)
#' # After: result <- estimate_effort(design_with_br_interviews)
#' # site_table <- get_site_contributions(result)
#'
#' @export
get_site_contributions <- function(x) {
  # Guard 1: must be creel_estimates
  if (!inherits(x, "creel_estimates")) {
    cls <- class(x)[1] # nolint: object_usage_linter
    cli::cli_abort(c(
      "{.arg x} must be a {.cls creel_estimates} object.",
      "x" = "{.arg x} is {.cls {cls}}.",
      "i" = "Pass the result of {.fn estimate_effort} for a bus-route design."
    ))
  }

  # Guard 2: site_contributions attribute must be present
  site_tbl <- attr(x, "site_contributions")
  if (is.null(site_tbl)) {
    cli::cli_abort(c(
      "No site contributions found in this estimate.",
      "x" = "The {.field site_contributions} attribute is absent.",
      "i" = paste(
        "Site contributions are only stored for bus-route designs.",
        "Ensure {.fn estimate_effort} was called on a bus-route {.cls creel_design}."
      )
    ))
  }

  tibble::as_tibble(site_tbl)
}

#' Summarize a creel_design object
#'
#' @param object A creel_design object
#' @param ... Additional arguments passed to [print.creel_design()]
#'
#' @return Invisibly returns the input object
#'
#' @export
summary.creel_design <- function(object, ...) {
  print(object, ...)
  invisible(object)
}

#' Summarize trip metadata for interview data
#'
#' Provides a diagnostic summary of trip completion status and duration
#' statistics for interview data attached to a creel design. Useful for
#' inspecting data quality before estimation.
#'
#' @param design A creel_design object with interviews attached via
#'   [add_interviews()].
#'
#' @return A list (class "creel_trip_summary") with components:
#'   \describe{
#'     \item{n_total}{Total number of interviews}
#'     \item{n_complete}{Number of complete trip interviews}
#'     \item{n_incomplete}{Number of incomplete trip interviews}
#'     \item{pct_complete}{Percentage of complete trips}
#'     \item{pct_incomplete}{Percentage of incomplete trips}
#'     \item{duration_stats}{Data frame with duration statistics by trip status}
#'   }
#'
#' @examples
#' data(example_calendar)
#' data(example_interviews)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   harvest = catch_kept,
#'   trip_status = trip_status,
#'   trip_duration = trip_duration
#' )
#' summary <- summarize_trips(design)
#' print(summary)
#'
#' @export
summarize_trips <- function(design) {
  # Validate design is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Validate interviews are attached
  if (is.null(design$interviews)) {
    cli::cli_abort(c(
      "No interviews found in design.",
      "x" = "The design object has no interview data.",
      "i" = "Attach interviews with {.fn add_interviews}."
    ))
  }

  # Validate trip metadata exists
  if (is.null(design$trip_status_col)) {
    cli::cli_abort(c(
      "No trip metadata found.",
      "x" = "Did you provide {.arg trip_status} in {.fn add_interviews}?"
    ))
  }

  # Extract trip metadata
  trip_status <- design$interviews[[design$trip_status_col]]
  trip_duration <- design$interviews[[design$trip_duration_col]]

  # Compute counts
  status_table <- table(trip_status)
  n_complete <- as.integer(status_table["complete"])
  n_incomplete <- as.integer(status_table["incomplete"])
  if (is.na(n_complete)) n_complete <- 0L
  if (is.na(n_incomplete)) n_incomplete <- 0L
  n_total <- n_complete + n_incomplete

  # Compute percentages
  pct_complete <- round(100 * n_complete / n_total, 1)
  pct_incomplete <- round(100 * n_incomplete / n_total, 1)

  # Compute duration statistics by trip status
  duration_stats <- data.frame(
    status = character(),
    n = integer(),
    min = numeric(),
    median = numeric(),
    mean = numeric(),
    max = numeric(),
    sd = numeric(),
    stringsAsFactors = FALSE
  )

  for (status_val in c("complete", "incomplete")) {
    status_mask <- trip_status == status_val
    if (sum(status_mask) > 0) {
      durations <- trip_duration[status_mask]
      duration_stats <- rbind(
        duration_stats,
        data.frame(
          status = status_val,
          n = sum(status_mask),
          min = round(min(durations, na.rm = TRUE), 2),
          median = round(stats::median(durations, na.rm = TRUE), 2),
          mean = round(mean(durations, na.rm = TRUE), 2),
          max = round(max(durations, na.rm = TRUE), 2),
          sd = round(stats::sd(durations, na.rm = TRUE), 2),
          stringsAsFactors = FALSE
        )
      )
    }
  }

  # Return list with class
  result <- list(
    n_total = n_total,
    n_complete = n_complete,
    n_incomplete = n_incomplete,
    pct_complete = pct_complete,
    pct_incomplete = pct_incomplete,
    duration_stats = duration_stats
  )
  class(result) <- "creel_trip_summary"
  result
}

#' @export
format.creel_trip_summary <- function(x, ...) {
  lines <- character()
  lines <- c(lines, cli::format_inline("Trip Status Summary"))
  lines <- c(lines, cli::format_inline(""))
  lines <- c(lines, cli::format_inline("Total interviews: {x$n_total}"))
  lines <- c(lines, cli::format_inline("  Complete:   {x$n_complete} ({x$pct_complete}%)"))
  lines <- c(lines, cli::format_inline("  Incomplete: {x$n_incomplete} ({x$pct_incomplete}%)"))
  lines <- c(lines, cli::format_inline(""))
  lines <- c(lines, cli::format_inline("Duration (hours) by status:"))
  # Format duration_stats table
  for (i in seq_len(nrow(x$duration_stats))) {
    row <- x$duration_stats[i, ] # nolint: object_usage_linter
    lines <- c(lines, cli::format_inline(
      "  {row$status}: min={row$min}, median={row$median}, mean={row$mean}, max={row$max}"
    ))
  }
  lines
}

#' @export
print.creel_trip_summary <- function(x, ...) {
  writeLines(format(x, ...))
  invisible(x)
}

#' Validate bus-route interview data structure (Tier 3)
#'
#' Internal validator for bus-route-specific requirements in interview data.
#' Checks that enumeration columns are provided, that interview data has the
#' join key columns (site and circuit), and that n_counted >= n_interviewed
#' for all rows. These are Tier 3 checks - bus-route specific, fire
#' immediately at add_interviews() time.
#'
#' @param interviews Data frame containing interview data
#' @param design A creel_design object with bus_route slot populated
#' @param n_counted_col Character name of n_counted column, or NULL
#' @param n_interviewed_col Character name of n_interviewed column, or NULL
#'
#' @return invisible(NULL) on success; aborts on validation failure
#'
#' @keywords internal
#' @noRd
validate_br_interviews_tier3 <- function(interviews, design,
                                         n_counted_col,
                                         n_interviewed_col) {
  collection <- checkmate::makeAssertCollection()
  br <- design$bus_route
  site_col <- br$site_col
  circuit_col <- br$circuit_col

  # Check 1: n_counted and n_interviewed must both be provided for bus-route
  if (is.null(n_counted_col)) {
    collection$push(
      paste0(
        "n_counted is required for bus-route designs. ",
        "Specify the column containing the count of all observed anglers."
      )
    )
  }
  if (is.null(n_interviewed_col)) {
    collection$push(
      paste0(
        "n_interviewed is required for bus-route designs. ",
        "Specify the column containing the count of anglers interviewed."
      )
    )
  }

  # Check 2: site join key must exist in interview data
  if (!site_col %in% names(interviews)) {
    collection$push(sprintf(
      "Interview data missing site column '%s' required for probability join.",
      site_col
    ))
  }

  # Check 3: circuit join key must exist in interview data
  if (!circuit_col %in% names(interviews)) {
    collection$push(sprintf(
      "Interview data missing circuit column '%s' required for probability join.",
      circuit_col
    ))
  }

  if (!collection$isEmpty()) {
    msgs <- collection$getMessages() # nolint: object_usage_linter
    cli::cli_abort(c(
      "Bus-route interview validation failed (Tier 3):",
      stats::setNames(paste0("{.var ", msgs, "}"), rep("x", length(msgs))),
      "i" = "Bus-route designs require enumeration counts and join key columns."
    ))
  }

  # Check 4: n_counted >= n_interviewed for all rows (only if both cols exist)
  if (!is.null(n_counted_col) && !is.null(n_interviewed_col)) {
    nc <- interviews[[n_counted_col]]
    ni <- interviews[[n_interviewed_col]]

    # Check both are numeric/integer
    if (!is.numeric(nc)) {
      cli::cli_abort(c(
        "n_counted column must be numeric.",
        "x" = "Column {.field {n_counted_col}} is {.cls {class(nc)[1]}}."
      ))
    }
    if (!is.numeric(ni)) {
      cli::cli_abort(c(
        "n_interviewed column must be numeric.",
        "x" = "Column {.field {n_interviewed_col}} is {.cls {class(ni)[1]}}."
      ))
    }

    # Check no negative values
    n_neg_counted <- sum(nc < 0, na.rm = TRUE)
    if (n_neg_counted > 0) {
      cli::cli_abort(c(
        "n_counted contains negative values.",
        "x" = "{n_neg_counted} row{?s} ha{?s/ve} n_counted < 0.",
        "i" = "Count of observed anglers must be non-negative."
      ))
    }
    n_neg_interviewed <- sum(ni < 0, na.rm = TRUE)
    if (n_neg_interviewed > 0) {
      cli::cli_abort(c(
        "n_interviewed contains negative values.",
        "x" = "{n_neg_interviewed} row{?s} ha{?s/ve} n_interviewed < 0.",
        "i" = "Count of interviewed anglers must be non-negative."
      ))
    }

    # Check n_counted >= n_interviewed (ignore NA rows)
    valid_rows <- !is.na(nc) & !is.na(ni)
    violations <- sum(nc[valid_rows] < ni[valid_rows])
    if (violations > 0) {
      cli::cli_abort(c(
        "n_counted must be >= n_interviewed for all rows.",
        "x" = "{violations} row{?s} ha{?s/ve} n_counted < n_interviewed.",
        "i" = "Cannot interview more anglers than were counted at the site.",
        "i" = "The expansion factor (n_counted / n_interviewed) must be >= 1."
      ))
    }
  }

  invisible(NULL)
}


#' Attach species-level catch data to a creel design
#'
#' Attaches a long-format data frame of species-level catch data to a
#' \code{creel_design} object. Each row in \code{data} represents a
#' species-catch-type combination for a single interview. Data is
#' validated at attach time and stored on the design for use by downstream
#' summary and estimation functions.
#'
#' @param design A \code{creel_design} object created by \code{\link{creel_design}}.
#' @param data A data frame in long format: one row per species per catch type per interview.
#' @param catch_uid <\link[tidyselect]{tidyselect}> Column in \code{data} containing
#'   interview IDs (the catch-side join key).
#' @param interview_uid <\link[tidyselect]{tidyselect}> Column in
#'   \code{design$interviews} containing the matching interview IDs.
#' @param species <\link[tidyselect]{tidyselect}> Column in \code{data} containing
#'   species names or codes.
#' @param count <\link[tidyselect]{tidyselect}> Column in \code{data} containing
#'   fish counts (non-negative integer or numeric).
#' @param catch_type <\link[tidyselect]{tidyselect}> Column in \code{data} containing
#'   catch fate: one of \code{"caught"}, \code{"harvested"}, or \code{"released"}.
#'   Values are normalized to lowercase before validation.
#'
#' @details
#' \strong{Catch type model:} Each species-interview row carries one of three
#' catch types. \code{"caught"} is the total; \code{"harvested"} and
#' \code{"released"} are subsets. A \code{"caught"} row is optional — when
#' absent, total catch is inferred as \code{harvested + released}. When a
#' \code{"caught"} row is present, \code{caught >= harvested + released} is
#' enforced (CATCH-04).
#'
#' \strong{Interview ID validation:} Every interview ID appearing in \code{data}
#' must appear in \code{design$interviews[[interview_uid]]}. Interviews with no
#' catch rows are valid (anglers who caught nothing need not appear in catch
#' data).
#'
#' \strong{Immutability:} Returns a new \code{creel_design} — the input is not
#' modified. Calling \code{add_catch()} on a design that already has
#' \code{$catch} is an error.
#'
#' @return A new \code{creel_design} object with \code{$catch} and associated
#'   \code{$catch_*_col} fields attached.
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' data(example_catch)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, trip_duration = trip_duration
#' )
#' design <- add_catch(design, example_catch,
#'   catch_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   count = count,
#'   catch_type = catch_type
#' )
#' print(design)
#' }
#'
#' @export
add_catch <- function(design, data,
                      catch_uid,
                      interview_uid,
                      species,
                      count,
                      catch_type) {
  # Guard: must be a creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(
      "{.arg design} must be a {.cls creel_design} object."
    )
  }

  # Guard: immutability — catch already attached
  # Use [[ for exact matching (avoids partial match of $catch against $catch_col etc.)
  if (!is.null(design[["catch"]])) {
    cli::cli_abort(c(
      "This design already has catch data attached.",
      "i" = "Use immutable workflow: {.code design2 <- add_catch(design, data, ...)}"
    ))
  }

  # Guard: interviews must exist before catch
  if (is.null(design$interviews)) {
    cli::cli_abort(c(
      "Interviews must be attached before catch data.",
      "i" = "Call {.fn add_interviews} first, then {.fn add_catch}."
    ))
  }

  # Resolve tidy selectors
  catch_uid_col <- resolve_single_col(
    rlang::enquo(catch_uid), data, "catch_uid", rlang::caller_env()
  )
  interview_uid_col <- resolve_single_col(
    rlang::enquo(interview_uid), design$interviews, "interview_uid", rlang::caller_env()
  )
  species_col <- resolve_single_col(
    rlang::enquo(species), data, "species", rlang::caller_env()
  )
  count_col <- resolve_single_col(
    rlang::enquo(count), data, "count", rlang::caller_env()
  )
  catch_type_col <- resolve_single_col(
    rlang::enquo(catch_type), data, "catch_type", rlang::caller_env()
  )

  # Normalize catch_type to lowercase
  data[[catch_type_col]] <- tolower(data[[catch_type_col]])

  # Validate catch_type values
  valid_types <- c("caught", "harvested", "released")
  bad_types <- setdiff(unique(data[[catch_type_col]]), valid_types)
  if (length(bad_types) > 0) {
    cli::cli_abort(c(
      "Invalid {.field catch_type} value{?s}: {.val {bad_types}}",
      "i" = "Accepted values: {.val {valid_types}}"
    ))
  }

  # Validate interview ID join (CATCH-02)
  catch_ids <- unique(data[[catch_uid_col]])
  interview_ids <- design$interviews[[interview_uid_col]]
  unmatched <- setdiff(catch_ids, interview_ids)
  if (length(unmatched) > 0) {
    cli::cli_abort(c(
      "{length(unmatched)} interview ID{?s} in catch data not found in design interviews:",
      stats::setNames(
        paste0("{.val ", unmatched, "}"),
        rep("x", length(unmatched))
      ),
      "i" = "Every catch row must reference an interview in the design."
    ))
  }

  # Validate caught >= harvested + released per species-interview (CATCH-04)
  caught_rows <- data[data[[catch_type_col]] == "caught", ]
  if (nrow(caught_rows) > 0) {
    sub_rows <- data[data[[catch_type_col]] %in% c("harvested", "released"), ]
    if (nrow(sub_rows) > 0) {
      sub_agg <- stats::aggregate(
        sub_rows[[count_col]],
        by = list(uid = sub_rows[[catch_uid_col]], species = sub_rows[[species_col]]),
        FUN = sum
      )
      names(sub_agg)[3] <- "sub_total"
    } else {
      sub_agg <- data.frame(uid = character(0), species = character(0), sub_total = numeric(0))
    }
    caught_agg <- stats::aggregate(
      caught_rows[[count_col]],
      by = list(uid = caught_rows[[catch_uid_col]], species = caught_rows[[species_col]]),
      FUN = sum
    )
    names(caught_agg)[3] <- "caught_total"
    combined <- merge(caught_agg, sub_agg, by = c("uid", "species"), all.x = TRUE)
    combined$sub_total[is.na(combined$sub_total)] <- 0L
    violations <- combined[combined$caught_total < combined$sub_total, ]
    if (nrow(violations) > 0) {
      bad_pairs <- paste0(violations$uid, "/", violations$species) # nolint: object_usage_linter
      cli::cli_abort(c(
        "Harvest + release exceeds catch for {nrow(violations)} species-interview pair{?s}:",
        stats::setNames(
          paste0("{.val ", bad_pairs, "}"),
          rep("x", length(bad_pairs))
        ),
        "i" = paste0(
          "caught must be >= harvested + released for each species-interview combination."
        )
      ))
    }
  }

  # Consistency check against interview-level catch_col (warning only)
  if (!is.null(design$catch_col) && design$catch_col %in% names(design$interviews)) {
    caught_only <- data[data[[catch_type_col]] == "caught", ]
    if (nrow(caught_only) > 0) {
      totals_from_catch <- stats::aggregate(
        caught_only[[count_col]],
        by = list(uid = caught_only[[catch_uid_col]]),
        FUN = sum
      )
    } else {
      sub_data <- data[data[[catch_type_col]] %in% c("harvested", "released"), ]
      totals_from_catch <- stats::aggregate(
        sub_data[[count_col]],
        by = list(uid = sub_data[[catch_uid_col]]),
        FUN = sum
      )
    }
    names(totals_from_catch)[2] <- "catch_implied"
    intv_totals <- design$interviews[, c(interview_uid_col, design$catch_col), drop = FALSE]
    names(intv_totals) <- c("uid", "catch_intv")
    check <- merge(totals_from_catch, intv_totals, by = "uid", all.x = TRUE)
    diverged <- check[!is.na(check$catch_intv) & check$catch_implied != check$catch_intv, ]
    if (nrow(diverged) > 0) {
      n_div <- nrow(diverged) # nolint: object_usage_linter
      cli::cli_warn(c(
        "!" = paste0(
          "Catch totals in catch data diverge from interview-level ",
          "{.field {design$catch_col}} for {n_div} interview{?s}."
        ),
        "i" = paste0(
          "This is advisory. Real creel data may differ legitimately ",
          "(partial species recording)."
        )
      ))
    }
  }

  # Build new design and store (immutable copy)
  new_design <- design
  new_design$catch <- data
  new_design$catch_uid_col <- catch_uid_col
  new_design$catch_interview_uid_col <- interview_uid_col
  new_design$catch_species_col <- species_col
  new_design$catch_count_col <- count_col
  new_design$catch_type_col <- catch_type_col
  class(new_design) <- "creel_design"
  new_design
}
