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
#'   Either way the return carries a `"se"` attribute holding the standard error
#'   of the mean (`sd / sqrt(n)` over parties), one value per group for the `by`
#'   form. [derive_angler_count()] reads it, so the sampling error of the
#'   multiplier reaches the effort standard error without being passed by hand.
#'
#'   The standard error is an attribute rather than a column so that the scalar
#'   return stays usable directly as a multiplier, and so the `by` form keeps
#'   exactly one numeric column and remains valid as a `party_size` lookup.
#'
#'   For the `by` form the attribute is **named by the group key**, and
#'   [derive_angler_count()] addresses it by name. Attributes do not follow the
#'   rows they describe through a `dplyr` reordering, so a positional attribute
#'   would go stale the moment the lookup were sorted — attributing each
#'   stratum's standard error to a different stratum while the means, which join
#'   by key, stayed correct. A `by`-form lookup whose `"se"` attribute has no
#'   names is refused rather than matched by row order.
#'
#'   A group with a single party has no estimable standard error and gets
#'   `NA_real_`, which propagates to an `NA` effort standard error rather than
#'   being quietly treated as zero uncertainty.
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
    out <- mean(rows[[n_col]], na.rm = TRUE)
    attr(out, "se") <- se_of_mean(rows[[n_col]])
    return(out)
  }

  by_cols <- resolve_multi_cols(by_quo, interviews, "by")
  agg <- stats::aggregate(
    rows[[n_col]],
    by = lapply(rows[by_cols], identity),
    FUN = function(x) mean(x, na.rm = TRUE)
  )
  names(agg) <- c(by_cols, "mean_party_size")

  # Aggregated separately rather than returned as a second column: a party_size
  # lookup must have exactly one numeric column, so the standard errors ride
  # along as an attribute.
  agg_se <- stats::aggregate(
    rows[[n_col]],
    by = lapply(rows[by_cols], identity),
    FUN = se_of_mean
  )

  out <- tibble::as_tibble(agg)
  # Named by the group key rather than left in row order. dplyr row operations
  # reorder the tibble and leave attributes untouched, so a positional attribute
  # goes stale against the rows it describes and each stratum ends up with
  # another stratum's standard error -- silently, because the means join by key
  # and so stay right (GH #133).
  attr(out, "se") <- stats::setNames(
    as.numeric(agg_se[[ncol(agg_se)]]),
    do.call(paste, c(agg_se[by_cols], sep = "\r"))
  )
  out
}


#' Standard error of a mean, with the single-observation case made explicit
#'
#' Internal helper. One party gives a mean but no spread, so the standard error
#' is unknown rather than zero. Returning `NA_real_` keeps that distinction: a
#' zero here would enter the effort variance as "the multiplier is known
#' exactly", which is the precise error this component exists to remove.
#'
#' @param x Numeric vector of party sizes
#'
#' @return A single numeric value, `NA_real_` when fewer than two parties
#'
#' @keywords internal
#' @noRd
se_of_mean <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) < 2L) {
    return(NA_real_)
  }
  stats::sd(x) / sqrt(length(x))
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
#' @section The party size is an estimate:
#' A mean party size taken from interviews is itself estimated, and it
#' multiplies the boat component of **every** count. Its error is therefore
#' perfectly correlated across counts and does not shrink as counts are added --
#' averaging more counts will not reduce it. Left out, the reported effort
#' standard error is too small; the estimate itself is unaffected.
#'
#' Supply `party_size_se` to carry that term through to the effort standard
#' error. [mean_party_size()] returns it as a `"se"` attribute, which is picked
#' up automatically when its output is passed as `party_size`, so the usual
#' pipeline propagates the term without any extra argument.
#'
#' When no standard error is available the term is **omitted rather than set to
#' zero**. A zero would produce a standard error identical to an unpropagated
#' one while looking propagated, which is worse than a documented omission. The
#' returned table carries no expansion columns in that case, and
#' `attr(<estimates>, "se_expansion")` is `NULL` rather than `0`.
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
#' @param party_size_se Optional standard error of `party_size`, in the same
#'   three shapes. Defaults to the `"se"` attribute of `party_size` when it has
#'   one, so [mean_party_size()] output propagates on its own. There is
#'   deliberately no zero default; see the section above.
#' @param to Name of the column to write. Defaults to `"angler_count"`.
#'
#' @return `counts` with the derived column appended.
#'
#'   When a party-size standard error is available, four further columns are
#'   appended for the estimators to read: `expansion_basis` (the boat count,
#'   which is what the multiplier acts on), `expansion_se`,
#'   `expansion_group` (which rows share one estimated multiplier, and so carry
#'   perfectly correlated error), and `expansion_of` (the column the basis is
#'   the derivative of). [add_counts()] recognises all four and excludes them
#'   from count-column detection.
#'
#'   They must travel together and must reach [add_counts()] alongside the
#'   column named in `expansion_of`. Transforming that column in between --
#'   multiplying a count by a shift length, say -- scales the count but not its
#'   derivative, and [add_counts()] refuses rather than propagate a component
#'   that is understated by exactly the scale factor. Pass the per-day count and
#'   let `period_length_col` do the multiplication instead.
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
  party_size_se = NULL,
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
  party_size_se_quo <- rlang::enquo(party_size_se)

  has_bank <- !rlang::quo_is_null(bank_quo)
  has_boat_anglers <- !rlang::quo_is_null(boat_anglers_quo)
  has_boat_count <- !rlang::quo_is_null(boat_count_quo)
  has_party_size <- !rlang::quo_is_null(party_size_quo)
  has_party_size_se <- !rlang::quo_is_null(party_size_se_quo)

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
  if (!has_boat_count && has_party_size_se) {
    cli::cli_abort(c(
      "{.arg party_size_se} was supplied without {.arg boat_count}.",
      "i" = "It is the standard error of a multiplier that is not being applied here."
    ))
  }
  carrier_cols <- expansion_carrier_cols()
  clash <- intersect(carrier_cols, names(counts))
  if (has_boat_count && length(clash) > 0L) {
    cli::cli_abort(c(
      "{cli::qty(length(clash))}{.field {clash}} already exist{?s/} in {.arg counts}.",
      "i" = "{.fn derive_angler_count} writes {.field {carrier_cols}} to carry the \\
             party-size variance component.",
      "i" = "{cli::qty(length(clash))}Drop the existing column{?s} first, or {?it/they} \\
             would be silently overwritten."
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
  expansion <- NULL
  if (has_boat_count) {
    boats <- numeric_component(boat_count_quo, "boat_count")
    party <- resolve_party_size(party_size_quo, counts)
    # as.numeric() strips the "group" attribute before the arithmetic. R
    # propagates attributes from an operand that has them, so without this the
    # grouping key would ride into the derived count column itself.
    total <- total + boats * as.numeric(party)

    se_vals <- resolve_party_size_se(
      party_size_se_quo,
      party_size_quo,
      counts,
      has_party_size_se
    )
    if (!is.null(se_vals)) {
      # The basis is the boat count, not the expanded angler count: it is
      # d(angler_count)/d(party_size), which is what the multiplier's error acts
      # on. Rows sharing a group share one estimated multiplier, so their errors
      # are perfectly correlated and must be summed before squaring.
      expansion <- list(
        basis = boats,
        se = se_vals,
        group = attr(party, "group") %||% rep("1", nrow(counts)),
        # The column the basis is the derivative of. Recorded so add_counts()
        # can tell whether the count it is handed is still the one the basis
        # belongs to; a transformation applied in between scales the count and
        # leaves the basis in the old units (GH #131).
        of = to
      )
    }
  }

  counts[[to]] <- total
  if (!is.null(expansion)) {
    counts[["expansion_basis"]] <- expansion$basis
    counts[["expansion_se"]] <- expansion$se
    counts[["expansion_group"]] <- expansion$group
    counts[["expansion_of"]] <- expansion$of
  }
  counts
}


#' Resolve the party-size standard error to one value per count row
#'
#' Internal helper. Mirrors `resolve_party_size()`'s three shapes, and falls
#' back to the `"se"` attribute that `mean_party_size()` attaches so the usual
#' pipeline propagates without an extra argument.
#'
#' Returns `NULL` when no standard error is available anywhere. That `NULL` is
#' load-bearing: it is what keeps the component absent rather than zero, so a
#' skipped term is visible as a missing attribute downstream instead of masquerading
#' as a propagated one.
#'
#' @param se_quo Quosure holding the `party_size_se` argument
#' @param party_size_quo Quosure holding the `party_size` argument
#' @param counts The counts table
#' @param supplied Whether `party_size_se` was given explicitly
#' @param error_call Calling environment for error reporting
#'
#' @return Numeric vector of length `nrow(counts)`, or `NULL`
#'
#' @keywords internal
#' @noRd
resolve_party_size_se <- function(
  se_quo,
  party_size_quo,
  counts,
  supplied,
  error_call = rlang::caller_env()
) {
  if (supplied) {
    out <- resolve_party_size_se_values(se_quo, counts, error_call)
    validate_party_size_se_values(out, error_call)
    return(out)
  }

  # Not given explicitly: take it from the multiplier itself. A bare column name
  # cannot carry an attribute, so only the scalar and lookup forms can supply one.
  expr <- rlang::quo_get_expr(party_size_quo)
  names_match <- (rlang::is_symbol(expr) || (is.character(expr) && length(expr) == 1L)) &&
    rlang::as_name(expr) %in% names(counts)
  if (names_match) {
    return(NULL)
  }

  party_size <- rlang::eval_tidy(party_size_quo)
  se <- attr(party_size, "se")
  if (is.null(se)) {
    return(NULL)
  }

  if (is.data.frame(party_size)) {
    value_cols <- names(party_size)[vapply(party_size, is.numeric, logical(1L))]
    key_cols <- setdiff(names(party_size), value_cols)
    if (length(se) != nrow(party_size)) {
      cli::cli_abort(
        c(
          "The {.val se} attribute on {.arg party_size} does not match its rows.",
          "x" = "{length(se)} standard error{?s} for {nrow(party_size)} lookup row{?s}."
        ),
        call = error_call
      )
    }
    # Addressed by name, not by position. `idx` below matches counts rows to
    # lookup rows by key, so indexing the attribute by that index would pair a
    # key-correct mean with a row-order-correct standard error -- which are the
    # same thing only until somebody sorts the lookup (GH #133).
    # One lookup row cannot be reordered against itself, so there is nothing for
    # a positional attribute to go stale against.
    if (is.null(names(se)) && nrow(party_size) > 1L) {
      cli::cli_abort(
        c(
          "The {.val se} attribute on {.arg party_size} has no names.",
          "x" = paste(
            "Without names it can only be matched by row order, which goes",
            "stale as soon as the lookup is sorted or otherwise reordered --",
            "silently, since the means still join by key."
          ),
          "i" = "{.fn mean_party_size} names it by the group key.",
          "i" = paste(
            "For a hand-built lookup, pass the standard errors as a keyed",
            "table to {.arg party_size_se} instead."
          )
        ),
        call = error_call,
        class = "creel_error_unnamed_expansion_se"
      )
    }
    idx <- if (is.null(names(se))) {
      rep(1L, nrow(counts))
    } else {
      match(do.call(paste, c(counts[key_cols], sep = "\r")), names(se))
    }
    if (anyNA(idx)) {
      cli::cli_abort(
        c(
          "The {.val se} attribute on {.arg party_size} has no entry for \\
           {sum(is.na(idx))} count{?s}.",
          "i" = "Names present: {.val {names(se)}}.",
          "i" = "Every count needs the standard error of the multiplier applied to it."
        ),
        call = error_call,
        class = "creel_error_unnamed_expansion_se"
      )
    }
    out <- as.numeric(se)[idx]
  } else {
    if (length(se) != 1L) {
      cli::cli_abort(
        c(
          "The {.val se} attribute on a scalar {.arg party_size} must be a single value.",
          "x" = "Got {length(se)}."
        ),
        call = error_call
      )
    }
    out <- rep(as.numeric(se), nrow(counts))
  }

  validate_party_size_se_values(out, error_call)
  out
}


#' Resolve an explicitly supplied `party_size_se` to one value per row
#'
#' Internal helper. Accepts the same scalar / column / lookup shapes as
#' `resolve_party_size()`.
#'
#' @param se_quo Quosure holding the `party_size_se` argument
#' @param counts The counts table
#' @param error_call Calling environment for error reporting
#'
#' @return Numeric vector, length `nrow(counts)`
#'
#' @keywords internal
#' @noRd
resolve_party_size_se_values <- function(se_quo, counts, error_call = rlang::caller_env()) {
  expr <- rlang::quo_get_expr(se_quo)
  names_match <- (rlang::is_symbol(expr) || (is.character(expr) && length(expr) == 1L)) &&
    rlang::as_name(expr) %in% names(counts)

  if (names_match) {
    col <- rlang::as_name(expr)
    if (!is.numeric(counts[[col]])) {
      cli::cli_abort(
        c(
          "{.arg party_size_se} must select a numeric column.",
          "x" = "{.field {col}} is {.cls {class(counts[[col]])[1]}}."
        ),
        call = error_call
      )
    }
    return(as.numeric(counts[[col]]))
  }

  se <- rlang::eval_tidy(se_quo)

  if (is.data.frame(se)) {
    value_cols <- names(se)[vapply(se, is.numeric, logical(1L))]
    if (length(value_cols) != 1L) {
      cli::cli_abort(
        c(
          "A {.arg party_size_se} lookup must have exactly one numeric column.",
          "x" = "Found {length(value_cols)}: {.field {value_cols}}."
        ),
        call = error_call
      )
    }
    key_cols <- setdiff(names(se), value_cols)
    missing_keys <- setdiff(key_cols, names(counts))
    if (length(missing_keys) > 0L) {
      cli::cli_abort(
        c(
          "{.arg party_size_se} lookup keys are not in {.arg counts}.",
          "x" = "Missing: {.field {missing_keys}}."
        ),
        call = error_call
      )
    }
    idx <- match(
      do.call(paste, c(counts[key_cols], sep = "\r")),
      do.call(paste, c(se[key_cols], sep = "\r"))
    )
    if (anyNA(idx)) {
      cli::cli_abort(
        c(
          "{.arg party_size_se} lookup has no row for {sum(is.na(idx))} count{?s}.",
          "i" = "Check that the lookup covers every level of {.field {key_cols}}."
        ),
        call = error_call
      )
    }
    return(as.numeric(se[[value_cols]][idx]))
  }

  if (is.numeric(se)) {
    if (length(se) == 1L) {
      return(rep(as.numeric(se), nrow(counts)))
    }
    if (length(se) == nrow(counts)) {
      return(as.numeric(se))
    }
    cli::cli_abort(
      c(
        "{.arg party_size_se} must be length 1 or {nrow(counts)}, not {length(se)}.",
        "i" = "{nrow(counts)} is the number of rows in {.arg counts}."
      ),
      call = error_call
    )
  }

  cli::cli_abort(
    c(
      "{.arg party_size_se} must be a number, a column of {.arg counts}, or a lookup table.",
      "x" = "Got {.cls {class(se)[1]}}."
    ),
    call = error_call
  )
}


#' Check that party-size standard errors are usable
#'
#' Internal helper. A negative standard error is not a value this can recover
#' from. `NA` is allowed and deliberate: it marks a multiplier whose uncertainty
#' could not be estimated, and it propagates to an `NA` component rather than
#' being read as certainty.
#'
#' @param x Numeric standard errors
#' @param error_call Calling environment for error reporting
#'
#' @return `NULL`, invisibly. Called for its side effect.
#'
#' @keywords internal
#' @noRd
validate_party_size_se_values <- function(x, error_call = rlang::caller_env()) {
  bad <- !is.na(x) & (!is.finite(x) | x < 0)
  if (any(bad)) {
    cli::cli_abort(
      c(
        "{.arg party_size_se} must be finite and not negative.",
        "x" = "Found {sum(bad)} value{?s} that {?is/are} not: {.val {unique(x[bad])}}."
      ),
      call = error_call
    )
  }
  invisible(NULL)
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
    return(with_expansion_group(as.numeric(counts[[col]]), as.character(counts[[col]])))
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
    return(with_expansion_group(
      as.numeric(party_size[[value_cols]][idx]),
      do.call(paste, c(counts[key_cols], sep = "\r"))
    ))
  }

  if (is.numeric(party_size)) {
    if (length(party_size) == 1L) {
      validate_party_size_values(party_size, error_call)
      # One number for every count: one estimate, so one group.
      return(with_expansion_group(rep(as.numeric(party_size), nrow(counts)), rep("1", nrow(counts))))
    }
    if (length(party_size) == nrow(counts)) {
      validate_party_size_values(party_size, error_call)
      return(with_expansion_group(as.numeric(party_size), as.character(party_size)))
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


#' The columns that carry the party-size expansion
#'
#' Internal helper. `derive_angler_count()` writes all of these or none of them,
#' and `add_counts()` reads them back. They are columns rather than attributes
#' because `add_counts()` rebuilds the counts table with `rbind()`, which drops
#' attributes.
#'
#' Named in one place because the set is read at three seams -- the overwrite
#' check here, the count-column exclusion list, and the carrier read in
#' `add_counts()` -- and a name added to two of three is the partial set that
#' GH #132 exists to refuse.
#'
#' @return Character vector of column names
#'
#' @keywords internal
#' @noRd
expansion_carrier_cols <- function() {
  c("expansion_basis", "expansion_se", "expansion_group", "expansion_of")
}


#' Tag a resolved party size with the rows that share one estimate
#'
#' Internal helper. The grouping decides how the multiplier's error accumulates:
#' within a group the error is one number applied many times, so contributions
#' add before squaring; across groups the estimates come from disjoint interview
#' subsets, so their variances add instead.
#'
#' Where the group cannot be read from a join key it falls back to the
#' multiplier's own value. Two genuinely separate estimates that happen to be
#' numerically identical then merge into one group, which treats them as fully
#' correlated and so overstates rather than understates the variance.
#'
#' @param values Resolved party sizes, one per count row
#' @param group Character grouping key, one per count row
#'
#' @return `values` with a `"group"` attribute
#'
#' @keywords internal
#' @noRd
with_expansion_group <- function(values, group) {
  attr(values, "group") <- as.character(group)
  values
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
