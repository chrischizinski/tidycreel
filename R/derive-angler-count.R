#' Mean anglers per boat party from interviews
#'
#' @description
#' Returns the mean number of anglers per boat party, taken from an interviews
#' table. This is the multiplier used to expand a count of boats into a count of
#' anglers when the clerk counted boats rather than the people aboard them.
#'
#' Boats move, so a count of anglers aboard is often less reliable than a count
#' of hulls. Counting boats and expanding by the interviewed party size trades an
#' unreliable field count for a measured one, at the cost of assuming the
#' interviewed parties are representative of the boats that were counted.
#'
#' @details
#' Each row of `interviews` is assumed to be one party. A table carrying several
#' rows per party — one per species, say — will weight larger parties more than
#' once; reduce it to one row per party first.
#'
#' Supply `by` when party size differs across the survey. Weekend parties are
#' commonly larger than weekday parties, and a single season-wide mean applied to
#' both then moves effort in opposite directions in the two strata.
#'
#' @param interviews A data frame of interviews, one row per party.
#' @param n_anglers Tidy selector for the numeric party-size column.
#' @param angler_type Optional tidy selector for the column recording whether a
#'   party fished from a boat or the bank. When supplied, only boat parties are
#'   used.
#' @param boat_value Value of `angler_type` marking a boat party. Defaults to
#'   `"boat"`. Ignored when `angler_type` is `NULL`.
#' @param by Optional tidy selector for one or more grouping columns. When
#'   supplied, a mean is returned for each group rather than one overall value.
#'
#' @return When `by` is `NULL`, a single numeric value. Otherwise a tibble with
#'   the grouping columns and a `mean_party_size` column.
#'
#' @seealso [derive_angler_count()], [prep_counts_boat_party()]
#' @family "Survey Design"
#' @export
#'
#' @examples
#' interviews <- data.frame(
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   type = c("boat", "bank", "boat", "boat"),
#'   n_anglers = c(2, 1, 3, 4)
#' )
#'
#' # Overall, boat parties only
#' mean_party_size(interviews, n_anglers, angler_type = type)
#'
#' # By stratum
#' mean_party_size(interviews, n_anglers, angler_type = type, by = day_type)
mean_party_size <- function(
  interviews,
  n_anglers,
  angler_type = NULL,
  boat_value = "boat",
  by = NULL
) {
  if (!is.data.frame(interviews)) {
    cli::cli_abort("{.arg interviews} must be a data frame, not {.cls {class(interviews)[1]}}.")
  }

  n_col <- resolve_single_col(rlang::enquo(n_anglers), interviews, "n_anglers")
  if (!is.numeric(interviews[[n_col]])) {
    cli::cli_abort(c(
      "{.arg n_anglers} must select a numeric column.",
      "x" = "{.field {n_col}} is {.cls {class(interviews[[n_col]])[1]}}."
    ))
  }

  type_quo <- rlang::enquo(angler_type)
  rows <- interviews
  if (!rlang::quo_is_null(type_quo)) {
    type_col <- resolve_single_col(type_quo, interviews, "angler_type")
    keep <- !is.na(rows[[type_col]]) & rows[[type_col]] == boat_value
    if (!any(keep)) {
      cli::cli_abort(c(
        "No boat parties found in {.arg interviews}.",
        "x" = "No row has {.field {type_col}} equal to {.val {boat_value}}.",
        "i" = "Observed values: {.val {unique(rows[[type_col]])}}.",
        "i" = "Set {.arg boat_value} to the value your data uses."
      ))
    }
    rows <- rows[keep, , drop = FALSE]
  }

  by_quo <- rlang::enquo(by)
  if (rlang::quo_is_null(by_quo)) {
    return(mean(rows[[n_col]], na.rm = TRUE))
  }

  by_cols <- resolve_multi_cols(by_quo, interviews, "by")
  agg <- stats::aggregate(
    rows[[n_col]],
    by = lapply(rows[by_cols], identity),
    FUN = function(x) mean(x, na.rm = TRUE)
  )
  names(agg) <- c(by_cols, "mean_party_size")
  tibble::as_tibble(agg)
}


#' Derive an angler count from its components
#'
#' @description
#' Builds the single angler-count column that `add_counts()` needs from the
#' columns a creel clerk actually records. Counts are commonly split across bank
#' anglers and boats, and the estimators need one number per count.
#'
#' Two forms are supported, matching the two ways a boat's anglers get onto the
#' form:
#'
#' - **Direct counts** — supply `boat_anglers`, the counted number of anglers
#'   aboard. Appropriate when the clerk could see and count them.
#' - **Boat-party expansion** — supply `boat_count` and `party_size`, and the
#'   boats are expanded by the mean anglers per boat party. Appropriate when
#'   boats were counted but the people aboard could not be counted reliably.
#'
#' @details
#' The two boat forms are separate arguments on purpose. `boat_count` is a count
#' of **hulls**, not people, and adding it to an angler total is a units error
#' that produces a plausible-looking number. Requiring `party_size` alongside it
#' makes that mistake impossible to commit by accident.
#'
#' Components are added with `na.rm = FALSE`. If bank anglers are missing for a
#' count and boat anglers are 5, the total is unknown, not 5 — a missing count
#' and a count of zero are different observations and are kept different here.
#'
#' Pooling bank and boat anglers into one count assumes both are detected the
#' same way and are being reported as one quantity. Where detection
#' probabilities or catch rates differ between them, estimate the two as
#' separate domains instead of adding them.
#'
#' @param counts A data frame of count observations.
#' @param bank Optional tidy selector for the bank (shore) angler count column.
#' @param boat_anglers Optional tidy selector for a directly counted boat-angler
#'   column. Mutually exclusive with `boat_count`.
#' @param boat_count Optional tidy selector for the counted number of boats.
#'   Requires `party_size`. Mutually exclusive with `boat_anglers`.
#' @param party_size Mean anglers per boat party, used to expand `boat_count`.
#'   One of: a single number; a tidy selector for a numeric column of `counts`;
#'   or a data frame of the kind [mean_party_size()] returns with `by`, which is
#'   joined onto `counts` by its non-numeric columns.
#' @param to Name of the column to write. Defaults to `"angler_count"`.
#'
#' @return `counts` with the derived column appended.
#'
#' @seealso [mean_party_size()], [add_counts()], [prep_counts_boat_party()]
#' @family "Survey Design"
#' @export
#'
#' @examples
#' counts <- data.frame(
#'   date = as.Date("2024-06-01") + 0:1,
#'   day_type = c("weekday", "weekend"),
#'   bank_anglers = c(4L, 9L),
#'   angler_boats = c(3L, 7L),
#'   boat_anglers = c(7L, 16L)
#' )
#'
#' # Direct counts
#' derive_angler_count(counts, bank = bank_anglers, boat_anglers = boat_anglers)
#'
#' # Boat-party expansion with a single mean
#' derive_angler_count(
#'   counts,
#'   bank = bank_anglers,
#'   boat_count = angler_boats,
#'   party_size = 2.4
#' )
#'
#' # Expansion with a stratum-specific mean
#' mps <- data.frame(day_type = c("weekday", "weekend"), mean_party_size = c(2.1, 2.8))
#' derive_angler_count(
#'   counts,
#'   bank = bank_anglers,
#'   boat_count = angler_boats,
#'   party_size = mps
#' )
derive_angler_count <- function(
  counts,
  bank = NULL,
  boat_anglers = NULL,
  boat_count = NULL,
  party_size = NULL,
  to = "angler_count"
) {
  if (!is.data.frame(counts)) {
    cli::cli_abort("{.arg counts} must be a data frame, not {.cls {class(counts)[1]}}.")
  }
  if (!is.character(to) || length(to) != 1L || is.na(to)) {
    cli::cli_abort("{.arg to} must be a single column name.")
  }
  if (to %in% names(counts)) {
    cli::cli_abort(c(
      "{.field {to}} already exists in {.arg counts}.",
      "i" = "Choose another name with {.arg to}, or drop the existing column first."
    ))
  }

  bank_quo <- rlang::enquo(bank)
  boat_anglers_quo <- rlang::enquo(boat_anglers)
  boat_count_quo <- rlang::enquo(boat_count)
  party_size_quo <- rlang::enquo(party_size)

  has_bank <- !rlang::quo_is_null(bank_quo)
  has_boat_anglers <- !rlang::quo_is_null(boat_anglers_quo)
  has_boat_count <- !rlang::quo_is_null(boat_count_quo)
  has_party_size <- !rlang::quo_is_null(party_size_quo)

  if (has_boat_anglers && has_boat_count) {
    cli::cli_abort(c(
      "Give either {.arg boat_anglers} or {.arg boat_count}, not both.",
      "i" = "{.arg boat_anglers} is a count of people; {.arg boat_count} is a count of boats.",
      "i" = "They are two ways to reach the same quantity, so supplying both would double it."
    ))
  }
  if (!has_bank && !has_boat_anglers && !has_boat_count) {
    cli::cli_abort(c(
      "No count components supplied.",
      "i" = "Give at least one of {.arg bank}, {.arg boat_anglers}, or {.arg boat_count}."
    ))
  }
  if (has_boat_count && !has_party_size) {
    cli::cli_abort(c(
      "{.arg boat_count} requires {.arg party_size}.",
      "x" = "{.arg boat_count} counts boats, not anglers, so it cannot enter an angler total on its own.",
      "i" = "Supply the mean anglers per boat party, e.g. from {.fn mean_party_size}.",
      "i" = "If the column already holds counted anglers, pass it as {.arg boat_anglers} instead."
    ))
  }
  if (!has_boat_count && has_party_size) {
    cli::cli_abort(c(
      "{.arg party_size} was supplied without {.arg boat_count}.",
      "i" = "A party size expands a count of boats; there is nothing here to expand."
    ))
  }

  numeric_component <- function(quo, arg_name) {
    col <- resolve_single_col(quo, counts, arg_name)
    if (!is.numeric(counts[[col]])) {
      cli::cli_abort(c(
        "{.arg {arg_name}} must select a numeric column.",
        "x" = "{.field {col}} is {.cls {class(counts[[col]])[1]}}."
      ))
    }
    as.numeric(counts[[col]])
  }

  total <- rep(0, nrow(counts))
  if (has_bank) {
    total <- total + numeric_component(bank_quo, "bank")
  }
  if (has_boat_anglers) {
    total <- total + numeric_component(boat_anglers_quo, "boat_anglers")
  }
  if (has_boat_count) {
    boats <- numeric_component(boat_count_quo, "boat_count")
    total <- total + boats * resolve_party_size(party_size_quo, counts)
  }

  counts[[to]] <- total
  counts
}


#' Resolve the party-size multiplier to one value per count row
#'
#' Internal helper. Accepts a scalar, a column of `counts`, or a lookup table of
#' the kind `mean_party_size(by = )` returns, and returns a numeric vector with
#' one value per row of `counts`.
#'
#' The lookup form is joined on the columns the lookup shares with `counts`,
#' which are its non-numeric columns. An unmatched row is an error rather than an
#' `NA`: a count with no party size has no defensible expansion, and silently
#' dropping it would understate effort.
#'
#' Whether the argument names a column is decided from the expression itself,
#' before evaluating it. Evaluating first would fail on a bare column name, and
#' resolving by evaluation would let a same-named object in the caller's
#' environment quietly win over the column the user meant.
#'
#' @param party_size_quo Quosure holding the `party_size` argument
#' @param counts The counts table
#' @param error_call Calling environment for error reporting
#'
#' @return Numeric vector, length `nrow(counts)`
#'
#' @keywords internal
#' @noRd
resolve_party_size <- function(party_size_quo, counts, error_call = rlang::caller_env()) {
  expr <- rlang::quo_get_expr(party_size_quo)
  names_match <- (rlang::is_symbol(expr) || (is.character(expr) && length(expr) == 1L)) &&
    rlang::as_name(expr) %in% names(counts)

  if (names_match) {
    col <- rlang::as_name(expr)
    if (!is.numeric(counts[[col]])) {
      cli::cli_abort(
        c(
          "{.arg party_size} must select a numeric column.",
          "x" = "{.field {col}} is {.cls {class(counts[[col]])[1]}}."
        ),
        call = error_call
      )
    }
    validate_party_size_values(counts[[col]], error_call)
    return(as.numeric(counts[[col]]))
  }

  party_size <- rlang::eval_tidy(party_size_quo)

  if (is.data.frame(party_size)) {
    value_cols <- names(party_size)[vapply(party_size, is.numeric, logical(1L))]
    if (length(value_cols) != 1L) {
      cli::cli_abort(
        c(
          "A {.arg party_size} lookup must have exactly one numeric column.",
          "x" = "Found {length(value_cols)}: {.field {value_cols}}.",
          "i" = "The other columns are the keys it is joined on."
        ),
        call = error_call
      )
    }
    key_cols <- setdiff(names(party_size), value_cols)
    missing_keys <- setdiff(key_cols, names(counts))
    if (length(missing_keys) > 0L) {
      cli::cli_abort(
        c(
          "{.arg party_size} lookup keys are not in {.arg counts}.",
          "x" = "Missing: {.field {missing_keys}}."
        ),
        call = error_call
      )
    }
    idx <- match(
      do.call(paste, c(counts[key_cols], sep = "\r")),
      do.call(paste, c(party_size[key_cols], sep = "\r"))
    )
    if (anyNA(idx)) {
      cli::cli_abort(
        c(
          "{.arg party_size} lookup has no row for {sum(is.na(idx))} count{?s}.",
          "i" = "Every count needs a party size; an unmatched count cannot be expanded.",
          "i" = "Check that the lookup covers every level of {.field {key_cols}}."
        ),
        call = error_call
      )
    }
    return(as.numeric(party_size[[value_cols]][idx]))
  }

  if (is.numeric(party_size)) {
    if (length(party_size) == 1L) {
      validate_party_size_values(party_size, error_call)
      return(rep(as.numeric(party_size), nrow(counts)))
    }
    if (length(party_size) == nrow(counts)) {
      validate_party_size_values(party_size, error_call)
      return(as.numeric(party_size))
    }
    cli::cli_abort(
      c(
        "{.arg party_size} must be length 1 or {nrow(counts)}, not {length(party_size)}.",
        "i" = "{nrow(counts)} is the number of rows in {.arg counts}."
      ),
      call = error_call
    )
  }

  cli::cli_abort(
    c(
      "{.arg party_size} must be a number, a column of {.arg counts}, or a lookup table.",
      "x" = "Got {.cls {class(party_size)[1]}}.",
      "i" = "A lookup table is what {.fn mean_party_size} returns when given {.arg by}."
    ),
    call = error_call
  )
}


#' Check that party sizes are usable multipliers
#'
#' Internal helper. A party size of zero or less cannot be a mean over parties
#' that each contain at least one angler, and would silently erase the boat
#' component of the count.
#'
#' @param x Numeric party sizes
#' @param error_call Calling environment for error reporting
#'
#' @return `NULL`, invisibly. Called for its side effect.
#'
#' @keywords internal
#' @noRd
validate_party_size_values <- function(x, error_call = rlang::caller_env()) {
  bad <- !is.na(x) & (!is.finite(x) | x <= 0)
  if (any(bad)) {
    cli::cli_abort(
      c(
        "{.arg party_size} must be finite and greater than zero.",
        "x" = "Found {sum(bad)} value{?s} that {?is/are} not: {.val {unique(x[bad])}}.",
        "i" = "A boat party contains at least one angler, so its mean cannot be zero or negative."
      ),
      call = error_call
    )
  }
  invisible(NULL)
}
