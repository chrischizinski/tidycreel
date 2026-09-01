# Exported escape hatch ----

#' Extract internal survey design object for advanced use
#'
#' @description
#' Provides power users with direct access to the internal survey.design2 object
#' for advanced analysis using survey package functions. This is an escape hatch
#' for workflows not yet wrapped by tidycreel. Most users should use
#' [estimate_effort()] instead.
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
#' svy <- as_creel_svydesign(design2)
#'
#' # Use with survey package functions
#' survey::svytotal(~count, svy)
#' survey::svymean(~count, svy)
#'
#' @family "Survey Design"
#' @export
as_creel_svydesign <- function(design) {
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
  # cli_warn(), not rlang::warn(): the latter does not evaluate cli markup, so
  # the {.fn} field printed literally to the user.
  cli::cli_warn(
    c(
      "Accessing internal survey design object.",
      "i" = "This is an advanced feature. Most users should use {.fn estimate_effort} instead.",
      "!" = "Modifying the survey design may produce incorrect variance estimates."
    ),
    .frequency = "once",
    .frequency_id = "tidycreel_as_creel_svydesign"
  )

  # Return design$survey
  # R's copy-on-modify semantics ensure modifications don't affect original
  design$survey
}

#' Extract internal survey design object (deprecated)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `as_survey_design()` was renamed to [as_creel_svydesign()] in tidycreel
#' 5.0.0. The old name collided with `srvyr::as_survey_design()`, srvyr's
#' principal entry point: attaching both packages masked one with the other
#' depending on load order, and a user who loaded srvyr second got srvyr's
#' generic failing to dispatch on `creel_design` with an error that said
#' nothing about masking. The new name also matches the sibling
#' [as_hybrid_svydesign()] and is more accurate -- the function extracts the
#' internal `survey` object rather than constructing a design.
#'
#' @inheritParams as_creel_svydesign
#'
#' @return A survey.design2 object, identical to [as_creel_svydesign()].
#'
#' @keywords internal
#' @export
as_survey_design <- function(design) {
  lifecycle::deprecate_warn(
    when = "5.0.0",
    what = "as_survey_design()",
    with = "as_creel_svydesign()",
    details = c(
      i = "The old name collided with `srvyr::as_survey_design()`."
    )
  )
  as_creel_svydesign(design)
}

# Internal survey bridge functions ----

#' Get survey design for specified variance method
#'
#' Internal helper that converts a survey design to use replicate weights for
#' bootstrap or jackknife variance estimation. For Taylor linearization, returns
#' the design unchanged.
#'
#' @param design Survey design object (survey.design2 from survey::svydesign)
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#'
#' @return Survey design object: original for Taylor, svrepdesign for bootstrap/jackknife
#'
#' @keywords internal
#' @noRd
get_variance_design <- function(design, variance_method) {
  if (variance_method == "taylor") {
    design
  } else if (variance_method == "bootstrap") {
    suppressWarnings(
      survey::as.svrepdesign(design, type = "bootstrap", replicates = 500)
    )
  } else if (variance_method == "jackknife") {
    tryCatch(
      suppressWarnings(survey::as.svrepdesign(design, type = "auto")),
      error = function(e) {
        msg <- conditionMessage(e)
        if (grepl("has only one PSU", msg, fixed = TRUE)) {
          # survey encodes: "Stratum<name>has only one PSU" (no spaces)
          strat <- regmatches(
            msg,
            regexpr("(?<=Stratum)(.+?)(?=has only one PSU)", msg, perl = TRUE)
          )
          strat_label <- if (length(strat) > 0L && nzchar(strat)) {
            # nolint: object_usage_linter
            strat
          } else {
            "unknown"
          }
          cli::cli_abort(
            c(
              paste0(
                "Stratum {.val {strat_label}} has only 1 PSU \u2014 ",
                "jackknife variance cannot be estimated."
              ),
              "x" = paste0(
                "A stratum must have at least 2 PSUs for jackknife ",
                "resampling."
              ),
              "i" = paste0(
                "Increase the sampling rate for stratum ",
                "{.val {strat_label}}, or use {.code variance = 'taylor'}."
              )
            ),
            class = "creel_error_single_psu"
          )
        }
        stop(e)
      }
    )
  }
}

#' Build interview survey design with explicit equal-probability weights
#'
#' Internal helper that constructs a \code{survey.design2} object for interview
#' data. Creel interview designs assume equal probability of selection within
#' each stratum: interviewers contact all available anglers encountered during a
#' survey period. Passing \code{weights = rep(1, nrow(data))} makes this
#' assumption explicit and suppresses the survey package diagnostic
#' "No weights or probabilities supplied, assuming equal probability", which
#' would otherwise appear on every \code{add_interviews()} call.
#'
#' Equal-probability weights do not affect downstream means or ratios
#' (\code{svymean}, \code{svyratio}), nor variance estimates from Taylor
#' linearization, bootstrap, or jackknife when all weights are identical.
#'
#' @param data Data frame of interview records.
#' @param strata A one-sided formula (e.g. \code{~.strata}) or \code{NULL} for
#'   no stratification.
#' @param ids A one-sided formula naming the cluster (PSU) column, or
#'   \code{NULL} (default) for \code{~1}, one PSU per row. Supply it where the
#'   design declares a sampling unit above the interview -- the bus-route and
#'   ice estimators cluster on the fishing day, their primary sampling unit
#'   (GH #198). Access-point and roving designs keep the default: there the
#'   interview genuinely is the unit, and the equal-probability assumption
#'   described above holds.
#'
#' @return A \code{survey.design2} object.
#'
#' @keywords internal
#' @noRd
build_interview_survey <- function(data, strata = NULL, ids = NULL) {
  if (is.null(ids)) {
    return(survey::svydesign(
      ids = ~1,
      strata = strata,
      weights = rep(1, nrow(data)),
      data = data
    ))
  }
  # Clustered on a declared sampling unit. `nest = TRUE` because the unit is
  # nested inside the stratum -- a fishing day has one day type -- rather than
  # the same id recurring across strata.
  survey::svydesign(
    ids = ids,
    strata = strata,
    weights = rep(1, nrow(data)),
    data = data,
    nest = TRUE
  )
}


#' Label each interview with the primary sampling unit it was collected in
#'
#' Internal helper. Malvestuto (1996, section 20.2.3) defines the bus-route
#' design as stratified two-stage probability sampling: fishing days are the
#' primary sampling units, and within each chosen day one or more secondary
#' units -- time period by lake section -- are chosen. Interviews sit inside
#' those, so several anglers contacted on one day are not independent draws
#' from the frame.
#'
#' The variance is taken between PSU totals, the ultimate-cluster estimator.
#' That captures every stage of subsampling within the day without needing the
#' joint inclusion probabilities of the second stage, which the sampling frame
#' does not carry.
#'
#' Taking it over interview rows instead made the reported precision a function
#' of interview-recording convention. Splitting one interview into two
#' half-effort rows left the Horvitz-Thompson estimate exactly unchanged and
#' shrank the standard error by `1/sqrt(2)`, so an agency recording one row per
#' angler looked more precise than one recording one row per party for the same
#' survey (GH #198).
#'
#' Ice designs are degenerate bus routes with a single synthetic site, so the
#' day is both PSU and site visit and this keys them identically.
#'
#' @param interviews Interview data frame, after `.pi_i` has been attached
#' @param design A `creel_design` of bus-route or ice type
#'
#' @return `interviews` with a `.psu` column appended
#'
#' @keywords internal
#' @noRd
br_add_psu_key <- function(interviews, design) {
  psu_col <- design$date_col
  if (is.null(psu_col) || !psu_col %in% names(interviews)) {
    # Nothing identifies the sampling unit. Fall back to the row, which is the
    # pre-#198 behaviour, rather than inventing a unit that is not in the data.
    interviews$.psu <- seq_len(nrow(interviews))
    return(interviews)
  }
  interviews$.psu <- as.character(interviews[[psu_col]])
  interviews
}

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
        design$date_col,
        na_count_date
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
          col,
          na_count_strata
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
        psu,
        na_count_psu
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
  new_creel_validation(
    # nolint: object_usage_linter
    results = results,
    tier = 1L,
    context = "add_counts validation"
  )
}

#' Count repeated sampling units in count data
#'
#' Internal helper, and the single definition of what "repeated" means here:
#' rows sharing a whole sampling-unit key. Both `detect_duplicate_psus()` (the
#' attach-time warning) and `refuse_duplicate_psus()` (the estimation-time
#' abort) count through this, so the two signals cannot disagree about how many
#' repeats a table holds.
#'
#' Keyed on the whole sampling unit rather than the PSU column alone. Keying on
#' the date by itself reported every multi-section day as a duplicate -- two
#' sections counted once each is ordinary structure, not a repeat -- and a
#' signal that fires on correct input is one users learn to ignore, which
#' matters because this is the only signal for the case that is genuinely wrong
#' (GH #155).
#'
#' @param counts Data frame containing count data
#' @param key_cols Character vector identifying one sampling unit, from
#'   `psu_key_cols()`
#'
#' @return Integer count of rows repeating a sampling unit already seen; `0`
#'   when every row is a distinct unit.
#'
#' @keywords internal
#' @noRd
n_duplicate_psus <- function(counts, key_cols) {
  key <- do.call(paste, c(lapply(counts[key_cols], as.character), sep = "\u001f"))
  sum(duplicated(key))
}


#' Warn at attach time about repeated sampling units
#'
#' Internal helper. The abort lives at estimation time, where the summing
#' actually happens (`refuse_duplicate_psus()`); this fires earlier, when the
#' counts are attached, so the problem is reported next to the call that
#' introduced it rather than several steps later. Warning rather than aborting
#' here is deliberate: an estimator that never sums these rows -- the aerial
#' GLMM models them against `time_of_flight` -- is entitled to them.
#'
#' @inheritParams refuse_duplicate_psus
#'
#' @return `NULL`, invisibly. Called for its side effect.
#'
#' @keywords internal
#' @noRd
detect_duplicate_psus <- function(counts, key_cols, call = rlang::caller_env()) {
  n_dup <- n_duplicate_psus(counts, key_cols)
  if (n_dup == 0) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c(
      "{.arg counts} has {n_dup} repeated sampling {cli::qty(n_dup)}unit{?s}, \\
       with no count time to tell them apart.",
      "i" = paste(
        "{cli::qty(n_dup)}The repeated {?row is/rows are} keyed on",
        "{.field {key_cols}}."
      ),
      "i" = paste(
        "Estimators that sum these rows refuse them; supply",
        "{.arg count_time_col} if they are repeat counts, or {.arg unit_cols}",
        "if they are distinct units."
      )
    ),
    call = call
  )
}


#' Refuse repeated sampling units at estimation time
#'
#' Internal helper. See `detect_duplicate_psus()` for the attach-time warning
#' and `n_duplicate_psus()` for the shared definition of a repeat.
#'
#' Only reached when `count_time_col` is absent; with a count time the repeats
#' are sub-counts and `aggregate_within_day()` collapses them to a per-unit mean.
#'
#' Aborts rather than warns (GH #193). Without a count time these rows reach
#' `svytotal()` as separate sampling units and are **summed**, so the effort
#' estimate comes back multiplied by the number of counts per unit -- measured
#' at exactly k-fold for k = 1..4 -- and propagates undiminished into catch,
#' harvest and release totals. `se_within` is reported as `0` at the same time,
#' which is indistinguishable from a within-day component that was evaluated and
#' found to be nil.
#'
#' It warned until 5.2.0, which was the wrong strength for the failure. The
#' sibling check `detect_duplicate_rows()` already aborts on rows identical in
#' every column -- the case that is usually a harmless double entry -- so the
#' genuinely dangerous case was the one left recoverable. The information needed
#' to resolve it is not in the table: two rows on one unit are either two looks
#' at it (average them) or two undeclared units (sum them), and only the surveyor
#' knows which. Guessing either way is a silent error, so this refuses and asks.
#'
#' @param counts Data frame containing count data
#' @param key_cols Character vector identifying one sampling unit
#' @param call Caller environment for error reporting
#'
#' @return `NULL`, invisibly. Called for its side effect.
#'
#' @keywords internal
#' @noRd
refuse_duplicate_psus <- function(counts, key_cols, call = rlang::caller_env()) {
  n_dup <- n_duplicate_psus(counts, key_cols)
  if (n_dup == 0) {
    return(invisible(NULL))
  }
  cli::cli_abort(
    c(
      "{.arg counts} has {n_dup} repeated sampling {cli::qty(n_dup)}unit{?s}, \\
       with no count time to tell them apart.",
      "x" = paste(
        "{cli::qty(n_dup)}The repeated {?row is/rows are} keyed on",
        "{.field {key_cols}}."
      ),
      "x" = paste(
        "Two counts on one unit are two looks at that unit, not two sampled",
        "units. Without a count time they are summed rather than averaged, so",
        "the effort estimate is multiplied by the number of counts per unit,",
        "and the within-day variance component is never computed."
      ),
      "i" = paste(
        "If these are repeat counts, say when each was taken:",
        "{.code add_counts(design, counts, count_time_col = count_time)}."
      ),
      "i" = paste(
        "If they really are distinct sampling units, name what separates them",
        "-- the section, site, or effort type -- via {.arg unit_cols}."
      )
    ),
    class = "creel_error_repeated_psus",
    call = call
  )
}

#' Refuse count rows that are identical in every column
#'
#' Internal helper. `svytotal()` sums the rows of `design$counts`, so a row
#' present twice is counted twice and the estimate rises with no error and no
#' warning (GH #152).
#'
#' Keyed on the whole row rather than on the sampling unit, which is what makes
#' this checkable at all. Two rows sharing a unit key are ordinary structure --
#' two sections, two effort types, two counts in a day -- and differ somewhere.
#' Two rows differing in **no** column carry nothing that could distinguish one
#' sampling unit from another, so either the row was entered twice or the
#' dimension separating them was never recorded. Both are refusals: the second
#' is unrecoverable here, because the information needed to expand it correctly
#' is not in the table.
#'
#' Deliberately independent of the key, and so of `unit_cols`. A key can be
#' wrong or incomplete -- it has been twice (#155, #162) -- but a table with two
#' identical rows is malformed under every key.
#'
#' @param counts Data frame of count data
#' @param call Calling environment for conditions
#'
#' @return `NULL`, invisibly. Called for its side effect.
#'
#' @keywords internal
#' @noRd
detect_duplicate_rows <- function(counts, call = rlang::caller_env()) {
  dup <- duplicated(counts)
  if (!any(dup)) {
    return(invisible(NULL))
  }
  n_dup <- sum(dup)
  # Report the rows the user can find -- every member of each identical set,
  # not just the copies -- so the message points at something locatable.
  affected <- which(dup | duplicated(counts, fromLast = TRUE))
  shown <- utils::head(affected, 6L)
  rows_txt <- paste(shown, collapse = ", ")
  if (length(affected) > length(shown)) {
    rows_txt <- paste0(rows_txt, ", and ", length(affected) - length(shown), " more")
  }
  headline <- sprintf(
    "%s contains %d repeated %s.",
    "{.arg counts}", n_dup, if (n_dup == 1L) "row" else "rows"
  )
  it_them <- if (n_dup == 1L) "it" else "them"
  cli::cli_abort(
    c(
      headline,
      "x" = paste(
        "{cli::qty(n_dup)}The {?row is/rows are} identical to an earlier row in",
        "every column, and identical rows are summed by the expansion, so each",
        "repeat inflates the estimate."
      ),
      "i" = "Affected rows: {rows_txt}.",
      "i" = "If this is a duplicate entry, remove {it_them}.",
      "i" = paste(
        "If these are separate counts of the same unit, record what separates",
        "them -- the count time via {.arg count_time_col}, or the section, site,",
        "or effort type via {.arg unit_cols}."
      )
    ),
    class = "creel_error_duplicate_count_rows",
    call = call
  )
}

#' Aggregate within-day count observations to PSU-level means
#'
#' Groups multiple count rows per PSU into a single-row mean, storing the
#' within-day sum of squared deviations (SS_d) and count (K_d) needed for
#' Rasmussen two-stage variance estimation.
#'
#' @param counts Data frame of count data (multiple rows per PSU allowed)
#' @param psu_col Character name of PSU column (e.g. "date")
#' @param count_var Character name of the numeric count column
#' @param count_time_col Character name of the column identifying sub-PSU
#'   observations (used for grouping only -- not ordered or weighted)
#' @param key_cols Character vector of all grouping key columns
#'   (psu_col + strata_cols). These define a unique PSU.
#' @param mean_vars Character vector of further columns to collapse by their
#'   mean, the way `count_var` is. Every other column takes its first value.
#' @param any_vars Character vector of logical flag columns to collapse with
#'   `any()`. A flag marking how a sub-count was obtained describes the whole
#'   aggregated day if it holds for any sub-count; taking the first row's value
#'   would let an aggregated day claim to be entirely observed when part of it
#'   was not.
#'
#' @return A list with elements:
#'   \describe{
#'     \item{aggregated}{Data frame with one row per PSU; count_var replaced by C-bar_d}
#'     \item{within_day_var}{Data frame with columns: key_cols + ss_d + k_d}
#'   }
#'
#' @keywords internal
#' @noRd
aggregate_within_day <- function(
  counts,
  psu_col,
  count_var,
  count_time_col,
  key_cols,
  mean_vars = character(),
  any_vars = character(),
  call = rlang::caller_env()
) {
  # Create grouping key as character for split()
  if (length(key_cols) == 1) {
    group_key <- as.character(counts[[key_cols]])
  } else {
    group_key <- do.call(paste, c(counts[key_cols], sep = "\u001f"))
  }

  groups <- split(seq_len(nrow(counts)), group_key)

  # Every column not handled explicitly below is taken from the group's FIRST
  # row. That is only sound when the column is constant across the group. When
  # it is not, the surviving row carries one sub-count's label over a mean taken
  # across all of them: bank and boat counts averaged into a single row still
  # labelled "bank", halving the estimate with no error and no warning (GH #162).
  #
  # The design cannot infer which columns are structural -- it only knows the
  # dimensions it declares, and a counts table may carry others -- so the caller
  # is asked rather than guessed at.
  collapsed_ok <- unique(c(key_cols, count_var, count_time_col, mean_vars, any_vars))
  checkable <- setdiff(names(counts), collapsed_ok)
  if (length(checkable) > 0L) {
    varies_in_group <- function(nm) {
      any(vapply(
        groups,
        function(idx) length(unique(counts[[nm]][idx])) > 1L,
        logical(1)
      ))
    }
    varies <- vapply(checkable, varies_in_group, logical(1))
    if (any(varies)) {
      bad <- checkable[varies] # nolint: object_usage_linter
      n_bad <- length(bad) # nolint: object_usage_linter
      suggested <- paste0('"', c(key_cols, bad), '"', collapse = ", ") # nolint: object_usage_linter
      cli::cli_abort(
        c(
          "{cli::qty(n_bad)}{.field {bad}} var{?ies/y} within a single sampling unit.",
          "x" = "Aggregating would average across {cli::qty(n_bad)}{?it/them} and keep \\
                 only the first value as the label.",
          "i" = "If {cli::qty(n_bad)}{?it/they} distinguish{?es/} one sampling unit from \\
                 another, name {cli::qty(n_bad)}{?it/them} in {.arg unit_cols}: \\
                 {.code unit_cols = c({suggested})}.",
          "i" = "If {cli::qty(n_bad)}{?it is/they are} incidental to the count, drop \\
                 {cli::qty(n_bad)}{?it/them} from the counts table before attaching."
        ),
        class = "creel_error_undeclared_unit_column",
        call = call
      )
    }
  }

  agg_rows <- vector("list", length(groups))
  var_rows <- vector("list", length(groups))

  for (i in seq_along(groups)) {
    idx <- groups[[i]]
    g <- counts[idx, , drop = FALSE]
    vals <- g[[count_var]]

    c_mean <- mean(vals)
    ss_d <- sum((vals - c_mean)^2)
    k_d <- length(vals)

    # Build one aggregated row: take first row, replace count_var with mean
    row <- g[1L, , drop = FALSE]
    row[[count_var]] <- c_mean
    # Columns that must collapse the same way the count does. Taking the first
    # row's value instead -- the default for every other column here -- would
    # leave a per-day derivative that no longer matches the per-day count it is
    # the derivative of.
    for (mv in mean_vars) {
      row[[mv]] <- mean(g[[mv]])
    }
    # Provenance flags describe the aggregated day if they hold for any
    # sub-count. The first row's value would report a day as fully observed
    # whenever its first count happened to be.
    for (av in any_vars) {
      row[[av]] <- any(as.logical(g[[av]]), na.rm = TRUE)
    }
    # Drop the count_time_col column -- no longer meaningful after aggregation
    row[[count_time_col]] <- NULL

    # Build within-day stats row
    var_row <- g[1L, key_cols, drop = FALSE]
    var_row$ss_d <- ss_d
    var_row$k_d <- k_d

    agg_rows[[i]] <- row
    var_rows[[i]] <- var_row
  }

  list(
    aggregated = do.call(rbind, agg_rows),
    within_day_var = do.call(rbind, var_rows)
  )
}

#' Compute progressive daily effort estimates (Ê_d = C × τ × κ)
#'
#' Replaces raw count values with per-PSU daily effort estimates following the
#' progressive count formula from Hoenig et al. (1993) and Pope et al. Ch. 17:
#'
#'   Ê_d = C × τ × κ = C × τ × (T_d / τ) = C × T_d
#'
#' where C is the raw angler count, τ is circuit_time (hours), and T_d is the
#' period length (hours). The count column is replaced in-place with Ê_d values
#' and period_length_col is dropped (to prevent it being treated as a second
#' count variable by estimate_effort_total()).
#'
#' @param counts Data frame of count data (one row per PSU after aggregation)
#' @param count_var Character name of the raw count column (replaced with Ê_d)
#' @param period_length_col Character name of the T_d column (hours, dropped after)
#' @param circuit_time Numeric circuit duration τ (hours)
#'
#' @return Modified counts data frame with count_var replaced by Ê_d values
#'   and period_length_col removed
#'
#' @references Hoenig, Robson, Jones, Pollock (1993). Scheduling counts in the
#'   instantaneous and progressive count methods. NAJFM 13:723-736.
#'   Pope et al. (draft) Ch. 17 Creel Surveys, p. 39.
#'
#' @keywords internal
#' @noRd
compute_progressive_effort <- function(counts, count_var, period_length_col, circuit_time) {
  period_length <- counts[[period_length_col]]
  kappa <- period_length / circuit_time
  effort_d <- counts[[count_var]] * circuit_time * kappa
  counts[[count_var]] <- effort_d
  counts[[period_length_col]] <- NULL
  counts
}

#' Apply the period length T_d to instantaneous counts (Ê_d = C̄_d × T_d)
#'
#' An instantaneous count estimates the number of anglers present at one moment,
#' not effort. Effort is that count multiplied by the length of the period the
#' count was randomised within (Hoenig et al. 1993):
#'
#'   Ê_d = C̄_d × T_d
#'
#' Multiplication happens per PSU, before any aggregation across days. Collapsing
#' first and scaling by a stratum-mean T afterwards computes C̄ × T̄ where the
#' target is the mean of C × T; the two differ by Cov(C, T), which is positive in
#' practice because anglers fish more on long days, so the collapsed form biases
#' low. Doing it here makes that covariance term exactly zero at any stratum width.
#'
#' This is the same arithmetic [compute_progressive_effort()] performs — τ cancels
#' out of Ê_d = C × τ × (T_d / τ), which is Hoenig et al. (1993) eq. 3 — but the
#' progressive path keeps its own function because `circuit_time` still gates the
#' shift-shorter-than-a-circuit check that only applies to progressive counts.
#'
#' @param counts Data frame of count data (one row per PSU after aggregation)
#' @param count_var Character name of the count column (replaced with Ê_d)
#' @param period_length_col Character name of the T_d column (hours, dropped after)
#'
#' @return Modified counts data frame with count_var replaced by Ê_d values
#'   and period_length_col removed
#'
#' @references Hoenig, Robson, Jones, Pollock (1993). Scheduling counts in the
#'   instantaneous and progressive count methods. NAJFM 13:723-736.
#'
#' @keywords internal
#' @noRd
apply_period_length <- function(counts, count_var, period_length_col) {
  counts[[count_var]] <- counts[[count_var]] * counts[[period_length_col]]
  counts[[period_length_col]] <- NULL
  counts
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
        cli::cli_abort(
          c(
            "Survey design construction failed: lonely PSU detected.",
            "x" = paste(
              "At least one stratum has only one PSU (Primary Sampling Unit).",
              "Variance estimation requires 2+ PSUs per stratum."
            ),
            "i" = "Possible solutions:",
            "*" = "Combine small strata with similar characteristics",
            "*" = "Use a different stratification scheme",
            "*" = "Collect data from more PSUs (days) in sparse strata"
          ),
          class = "creel_error_single_psu"
        )
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

# Unit propagation ----
#
# The dimension a number carries is derived and propagated, never declared. A
# unit the caller types is exactly as trustworthy as the axis label on the
# poster -- a second place to write the wrong thing. So tidycreel asserts a unit
# only where it performed the arithmetic that produces it:
#
#   * angler-hours on the count side, when add_counts() multiplied a count by
#     the period length T_d
#   * angler-hours on the interview side, when add_interviews() multiplied trip
#     hours by a supplied party size
#   * party-hours on the interview side, when it did not
#
# Everywhere else the unit is NA, meaning unknown -- not "angler-days". A bare
# numeric count column may be an instantaneous head count or effort that the
# caller already expanded; `example_counts` is the latter. Guessing between them
# would put a confident label on a number that may be in either unit, which is
# the failure this machinery exists to prevent.

#' Mark a counts table as already holding sampled-day effort
#'
#' The `prep_counts_*()` seam resolves counts into sampled-day effort before
#' `add_counts()` sees them, so its output is not a raw instantaneous count even
#' though no `period_length_col` was supplied. The mark suppresses the
#' finding-13 warning for that workflow. It deliberately does **not** assert a
#' unit: the caller chose the input column, and it may be in any time base.
#'
#' Carried as an attribute rather than a column, since a column duplicates a
#' constant per row and is user-editable. An attribute dropped by intervening
#' dplyr verbs degrades to "unknown", which is the safe direction.
#'
#' @param x A data frame of sampled-day effort rows
#'
#' @return `x` with the marker attribute set
#'
#' @keywords internal
#' @noRd
mark_counts_as_effort <- function(x) {
  attr(x, "tidycreel_counts_are_effort") <- TRUE
  x
}

#' Read the sampled-day effort marker back off a counts table
#'
#' @param x A data frame of counts
#'
#' @return `TRUE` when the table came from a `prep_counts_*()` helper
#'
#' @keywords internal
#' @noRd
counts_are_effort <- function(x) {
  isTRUE(attr(x, "tidycreel_counts_are_effort", exact = TRUE))
}

#' Derive the unit of a rate's denominator from the interview side
#'
#' @param design A creel_design object
#'
#' @return `"angler-hours"`, `"party-hours"`, or `NA_character_` when no
#'   interviews are attached
#'
#' @keywords internal
#' @noRd
interview_effort_unit <- function(design) {
  if (is.null(design$angler_effort_col)) {
    return(NA_character_)
  }
  # add_interviews() records whether .angler_effort was actually normalised by a
  # party size. Without it the column is party-hours, which is the same seam
  # warn_party_hours_product() guards at the multiplication point.
  if (isTRUE(design$n_anglers_supplied)) "angler-hours" else "party-hours"
}

#' Build the unit string for a per-unit-effort rate
#'
#' @param design A creel_design object
#'
#' @return e.g. `"fish/angler-hour"`, or `NA_character_` when the denominator
#'   unit is unknown
#'
#' @keywords internal
#' @noRd
rate_unit <- function(design) {
  denom <- interview_effort_unit(design)
  if (is.na(denom)) {
    return(NA_character_)
  }
  paste0("fish/", sub("-hours$", "-hour", denom))
}

#' Derive the unit of a rate-times-effort product
#'
#' The three total estimators multiply a per-unit-effort rate by an effort
#' total. `fish/angler-hour * angler-hours` cancels to `fish`; nothing else
#' does. Before this existed each of them wrote `unit = "fish"` as a literal at
#' the `new_creel_estimates()` call, so a total built on an effort estimate of
#' unknown unit was still labelled `fish` (#213).
#'
#' Two ways to fail to cancel, both answered with `NA`:
#'
#' * either factor's unit is unknown -- `design$effort_unit` is `NA` whenever
#'   `add_counts()` received no `period_length_col`, because a bare count column
#'   may be an instantaneous head count or effort the caller already expanded
#'   and nothing can tell the two apart. Unknown times known is unknown.
#' * the denominators disagree -- `fish/party-hour * angler-hours` is not fish.
#'   `warn_party_hours_product()` already reports that seam; this stops the
#'   result from carrying a confident label through it.
#'
#' Derived rather than declared, the same rule `estimate_effort_per_acre()`
#' follows: composing the string from its inputs is what keeps an unknown
#' unknown.
#'
#' @param rate_unit The `unit` of the rate estimate, e.g. `"fish/angler-hour"`
#' @param effort_unit The effort unit, e.g. `"angler-hours"`
#'
#' @return `"fish"` when the units cancel, otherwise `NA_character_`
#'
#' @keywords internal
#' @noRd
product_total_unit <- function(rate_unit, effort_unit) {
  rate <- rate_unit %||% NA_character_
  effort <- effort_unit %||% NA_character_
  if (length(rate) != 1L || length(effort) != 1L) {
    return(NA_character_)
  }
  if (is.na(rate) || is.na(effort)) {
    return(NA_character_)
  }
  denominator <- sub("^fish/", "", rate)
  # "angler-hour" cancels "angler-hours"; the rate's singular is the effort's
  # plural. Compared rather than pattern-matched so an unrecognised pair falls
  # through to NA instead of being assumed to cancel.
  if (!identical(paste0(denominator, "s"), effort)) {
    return(NA_character_)
  }
  "fish"
}

#' Derive the unit of a trip count from the effort it was divided from
#'
#' Trips are effort / mean trip length, and the divisor is hours per trip, so
#' the count inherits whichever actor the effort was measured in: angler-hours
#' give angler-trips, party-hours give party-trips. Asserting "angler-trips"
#' unconditionally would put a confident label on a party-level number whenever
#' the effort it came from was party-hours.
#'
#' @param effort_unit The `unit` field of the effort estimates object
#'
#' @return `"angler-trips"`, `"party-trips"`, or `NA_character_` when the
#'   effort unit is unknown
#'
#' @keywords internal
#' @noRd
trips_unit <- function(effort_unit) {
  unit <- effort_unit %||% NA_character_
  if (length(unit) != 1L || is.na(unit)) {
    return(NA_character_)
  }
  switch(unit,
    "angler-hours" = "angler-trips",
    "party-hours" = "party-trips",
    NA_character_
  )
}

#' Check that a product of effort and a rate is dimensionally coherent
#'
#' Total catch is effort x rate, so the rate's denominator must be the same
#' quantity the effort is measured in. Two known units that disagree make the
#' product meaningless, and this aborts.
#'
#' It does not warn when the effort unit is merely *unknown*. That is the same
#' fact [warn_missing_period_length()] reports, and the totals call it directly
#' for exactly this reason — one defect should produce one diagnosis, not two
#' competing ones at adjacent call sites.
#'
#' The party-hours case is likewise excluded: [warn_party_hours_product()]
#' already names it with a better message at the same call sites, and escalating
#' it to an error would break every caller who omits `n_anglers`.
#'
#' @param design A creel_design object
#' @param call Calling environment for the condition
#'
#' @return NULL (invisible) - called for its side effect
#'
#' @keywords internal
#' @noRd
check_product_units <- function(design, call = rlang::caller_env()) {
  effort <- design$effort_unit %||% NA_character_
  denom <- interview_effort_unit(design)

  if (identical(denom, "party-hours")) {
    return(invisible(NULL))
  }

  if (is.na(effort)) {
    return(invisible(NULL))
  }

  if (!is.na(denom) && !identical(effort, denom)) {
    cli::cli_abort(
      c(
        "Effort and rate are in different units.",
        "x" = "Effort is {.val {effort}} but the rate is per {.val {denom}}.",
        "i" = "Their product is not a catch. Re-attach the counts or interviews in matching units."
      ),
      class = "creel_error_unit_mismatch",
      call = call
    )
  }

  invisible(NULL)
}

#' Warn that an instantaneous effort estimate never had T_d applied
#'
#' An instantaneous count is a snapshot of how many anglers were present at one
#' moment. Effort is that count multiplied by the length of the period the count
#' was randomised within, and with no `period_length_col` the estimator has no
#' \eqn{T_d} to apply — it expands the counts to the season and returns them.
#'
#' The warning does not claim the result is angler-days, because the package
#' cannot tell an instantaneous head count from a column that already holds
#' angler-hours; both arrive as a numeric column. It states the reading and lets
#' the caller decide which case they are in.
#'
#' Once per session, so a script that estimates repeatedly is told once. Tests
#' force it with `rlib_warning_verbosity = "verbose"`.
#'
#' @param design A creel_design object
#'
#' @return NULL (invisible) - called for its side effect
#'
#' @keywords internal
#' @noRd
warn_missing_period_length <- function(design) {
  if (!identical(design$count_type, "instantaneous")) {
    return(invisible(NULL))
  }
  if (!is.null(design$period_length_col)) {
    return(invisible(NULL))
  }
  # The prep_counts_*() seam resolves counts into sampled-day effort before
  # add_counts() sees them, so there is no instantaneous count left to expand
  # and no T_d to ask for. Warning there would fire on the documented preferred
  # workflow.
  if (isTRUE(design$counts_are_effort)) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c(
      "Instantaneous counts were expanded without a period length.",
      "i" = paste(
        "No {.arg period_length_col} was supplied to {.fn add_counts}, so the",
        "estimate is the count column summed over days."
      ),
      "!" = paste(
        "If that column holds an instantaneous angler count, the result is in",
        "angler-days, not angler-hours."
      ),
      "i" = paste(
        "Supply the period each count was randomised within:",
        "{.code add_counts(design, counts, period_length_col = <col>)}."
      )
    ),
    .frequency = "once",
    .frequency_id = "tidycreel_effort_without_period_length"
  )
  invisible(NULL)
}

#' Validate data quality (Tier 2)
#'
#' Internal function that checks for data quality issues in a creel_design with
#' attached counts. Issues warnings (not errors) for zero/negative count values
#' and sparse strata (< 3 observations). These are Tier 2 checks - data quality
#' issues that should be investigated but don't prevent estimation.
#'
#' @param design A creel_design object with counts attached
#'
#' @return NULL (invisible) - function called for side effects (warnings)
#'
#' @keywords internal
#' @noRd
warn_tier2_issues <- function(design) {
  counts_data <- design$counts
  date_col <- design$date_col
  strata_cols <- design$strata_cols
  psu_col <- design$psu_col

  # Identify count variable(s): numeric columns that are not design metadata
  excluded_cols <- c(date_col, strata_cols, psu_col)
  numeric_cols <- names(counts_data)[vapply(counts_data, is.numeric, logical(1L))]
  count_vars <- setdiff(numeric_cols, excluded_cols)

  # Check each count variable for zero/negative values
  for (count_var in count_vars) {
    values <- counts_data[[count_var]]

    # Check for zero values
    n_zero <- sum(values == 0, na.rm = TRUE)
    if (n_zero > 0) {
      cli::cli_warn(c(
        "Count variable {.field {count_var}} contains {n_zero} zero value{?s}.",
        "i" = "Zero values may indicate days with no fishing activity or data collection issues.",
        "i" = "Consider whether zeros are true zeros or missing data."
      ))
    }

    # Check for negative values
    n_negative <- sum(values < 0, na.rm = TRUE)
    if (n_negative > 0) {
      cli::cli_warn(c(
        "Count variable {.field {count_var}} contains {n_negative} negative value{?s}.",
        "!" = "Negative values indicate data entry errors or incorrect calculations.",
        "i" = "Review and correct negative values before estimation."
      ))
    }
  }

  # Check for sparse strata (< 3 observations per stratum)
  # Create the same strata variable used in survey design
  if (length(strata_cols) == 1) {
    strata_var <- counts_data[[strata_cols]]
  } else {
    strata_factors <- counts_data[strata_cols]
    strata_var <- interaction(strata_factors, drop = TRUE)
  }

  # Count observations per stratum
  strata_counts <- table(strata_var)
  sparse_strata <- strata_counts[strata_counts < 3]

  if (length(sparse_strata) > 0) {
    # Build bullet items for each sparse stratum
    bullet_items <- character(length(sparse_strata))
    for (i in seq_along(sparse_strata)) {
      stratum_name <- names(sparse_strata)[i]
      n_obs <- sparse_strata[i]
      bullet_items[i] <- sprintf(
        "Stratum %s: %d observation%s",
        stratum_name,
        n_obs,
        ifelse(n_obs == 1, "", "s")
      )
    }
    names(bullet_items) <- rep("*", length(sparse_strata))

    cli::cli_warn(c(
      "{length(sparse_strata)} strat{?um/a} ha{?s/ve} fewer than 3 observations:",
      bullet_items,
      "!" = "Sparse strata produce unstable variance estimates.",
      "i" = "Consider combining sparse strata or collecting more data."
    ))
  }

  invisible(NULL)
}

#' Validate data quality for groups (Tier 2)
#'
#' Internal function that checks for sparse groups (< 3 observations per group
#' level) in grouped estimation. Issues warnings (not errors) for data quality
#' issues. This is a Tier 2 check - data quality issue that should be
#' investigated but doesn't prevent estimation.
#'
#' @param design A creel_design object with counts attached
#' @param by_vars Character vector of grouping variable names
#'
#' @return NULL (invisible) - function called for side effects (warnings)
#'
#' @keywords internal
#' @noRd
warn_tier2_group_issues <- function(design, by_vars) {
  counts_data <- design$counts

  # Count observations per group combination
  group_data <- counts_data[by_vars]
  group_data$count <- 1
  group_counts <- stats::aggregate(
    count ~ .,
    data = group_data,
    FUN = sum
  )

  # Identify sparse groups (< 3 observations)
  sparse_groups <- group_counts[group_counts$count < 3, ]

  if (nrow(sparse_groups) > 0) {
    # Build bullet items for each sparse group
    bullet_items <- character(nrow(sparse_groups))
    for (i in seq_len(nrow(sparse_groups))) {
      group_vals <- sparse_groups[i, by_vars, drop = FALSE]
      group_label <- paste(
        paste0(by_vars, "=", group_vals),
        collapse = ", "
      )
      n_obs <- sparse_groups$count[i]
      bullet_items[i] <- sprintf(
        "Group %s: %d observation%s",
        group_label,
        n_obs,
        ifelse(n_obs == 1, "", "s")
      )
    }
    names(bullet_items) <- rep("*", length(bullet_items))

    cli::cli_warn(c(
      "{nrow(sparse_groups)} group{?s} ha{?s/ve} fewer than 3 observations:",
      bullet_items,
      "!" = "Sparse groups produce unstable variance estimates.",
      "i" = "Consider combining sparse groups or collecting more data."
    ))
  }

  invisible(NULL)
}

#' Validate interview data quality (Tier 2)
#'
#' Internal function that checks for data quality issues in interview data
#' attached to a creel_design. Issues warnings (not errors) for suspicious
#' values. These are Tier 2 checks - data quality issues that should be
#' investigated but don't prevent estimation.
#'
#' @param design A creel_design object with interviews attached
#'
#' @return NULL (invisible) - function called for side effects (warnings)
#'
#' @keywords internal
#' @noRd
# Warn where a party-hour rate meets angler-hour effort.
#
# When add_interviews() runs without `n_anglers`, .angler_effort is the raw
# effort column, so every rate estimator returns fish per *party*-hour. The
# product totals then multiply that rate by effort derived from angler counts,
# which is angler-hours. Both operands are individually correct; their product is
# correct only if every party is a single angler.
#
# add_interviews() already informs at construction, but the design records
# angler_effort_col = ".angler_effort" either way, so nothing downstream could
# tell the two apart -- and the inform is far from the call that actually
# multiplies them. This fires at that point instead.
#
# Bus-route and ice designs do not reach this: their totals are HT sums over
# interviews, with no rate multiplication.
warn_party_hours_product <- function(design, call = rlang::caller_env()) {
  if (isTRUE(design$n_anglers_supplied)) {
    return(invisible(FALSE))
  }

  cli::cli_warn(
    c(
      "Rate and effort may be in different units.",
      "x" = paste(
        "{.arg n_anglers} was not supplied, so the rate is per {.emph party}-hour",
        "while count-derived effort is per angler."
      ),
      "i" = paste(
        "The product is correct only if every party is one angler.",
        "Pass {.code add_interviews(n_anglers = <col>)} to normalise."
      )
    ),
    call = call
  )
  invisible(TRUE)
}

warn_tier2_interview_issues <- function(design) {
  interviews <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$effort_col
  strata_cols <- design$strata_cols

  # Check for very short trips (effort < 0.1 hours = 6 minutes)
  if (!is.null(effort_col)) {
    n_short <- sum(interviews[[effort_col]] < 0.1, na.rm = TRUE)
    if (n_short > 0) {
      cli::cli_warn(c(
        "{n_short} interview{?s} ha{?s/ve} effort < 0.1 hours (6 minutes).",
        "i" = "Very short trips may indicate data entry errors."
      ))
    }
  }

  # Check for zero catch values
  n_zero <- sum(interviews[[catch_col]] == 0, na.rm = TRUE)
  if (n_zero > 0) {
    cli::cli_warn(c(
      "{n_zero} interview{?s} ha{?s/ve} zero catch.",
      "i" = "Zero catch may be valid (skunked) or indicate missing data."
    ))
  }

  # Check for negative catch values
  n_neg_catch <- sum(interviews[[catch_col]] < 0, na.rm = TRUE)
  if (n_neg_catch > 0) {
    cli::cli_warn(c(
      "{n_neg_catch} interview{?s} ha{?s/ve} negative catch values.",
      "!" = "Negative catch indicates data entry errors.",
      "i" = "Review and correct before estimation."
    ))
  }

  # Check for negative effort values
  if (!is.null(effort_col)) {
    n_neg_effort <- sum(interviews[[effort_col]] < 0, na.rm = TRUE)
    if (n_neg_effort > 0) {
      cli::cli_warn(c(
        "{n_neg_effort} interview{?s} ha{?s/ve} negative effort values.",
        "!" = "Negative effort indicates data entry errors.",
        "i" = "Review and correct before estimation."
      ))
    }
  }

  # Check for missing effort values (NA)
  if (!is.null(effort_col)) {
    n_na_effort <- sum(is.na(interviews[[effort_col]]))
    if (n_na_effort > 0) {
      cli::cli_warn(c(
        "{n_na_effort} interview{?s} ha{?s/ve} missing effort values.",
        "i" = "Missing effort limits CPUE estimation."
      ))
    }
  }

  # Check for sparse interview coverage per stratum (< 3 interviews per stratum)
  # Create the same strata variable used in survey design
  if (length(strata_cols) == 1) {
    strata_var <- interviews[[strata_cols]]
  } else {
    strata_factors <- interviews[strata_cols]
    strata_var <- interaction(strata_factors, drop = TRUE)
  }

  # Count interviews per stratum
  strata_counts <- table(strata_var)
  sparse_strata <- strata_counts[strata_counts < 3]

  if (length(sparse_strata) > 0) {
    # Build bullet items for each sparse stratum
    bullet_items <- character(length(sparse_strata))
    for (i in seq_along(sparse_strata)) {
      stratum_name <- names(sparse_strata)[i]
      n_obs <- sparse_strata[i]
      bullet_items[i] <- sprintf(
        "Stratum %s: %d interview%s",
        stratum_name,
        n_obs,
        ifelse(n_obs == 1, "", "s")
      )
    }
    names(bullet_items) <- rep("*", length(bullet_items))

    cli::cli_warn(c(
      "{length(sparse_strata)} strat{?um/a} ha{?s/ve} fewer than 3 interviews:",
      bullet_items,
      "!" = "Sparse strata produce unstable variance estimates.",
      "i" = "Consider combining sparse strata or collecting more data."
    ))
  }

  invisible(NULL)
}

#' Validate ratio estimator sample size
#'
#' Internal function that checks sample size adequacy for ratio estimation (CPUE or
#' harvest HPUE). Errors if n < 10 (ungrouped or any group), warns if 10 <= n < 30.
#' These thresholds follow best practices for ratio estimation stability.
#'
#' @param design A creel_design object with interviews attached
#' @param by_vars NULL for ungrouped, or character vector of grouping variable names
#' @param type Character string: "cpue" (default) or "harvest" for error message context
#'
#' @return NULL (invisible) - function called for side effects (errors/warnings)
#'
#' @keywords internal
#' @noRd
validate_ratio_sample_size <- function(design, by_vars, type = "cpue") {
  interviews <- design$interviews

  # Set estimation type for messages
  estimation_type <- if (type == "harvest") "harvest" else "CPUE" # nolint: object_usage_linter

  if (is.null(by_vars)) {
    # Ungrouped validation
    n <- nrow(interviews)

    if (n < 10) {
      cli::cli_abort(c(
        "Insufficient sample size for {estimation_type} estimation.",
        "x" = "Sample size is {n}, but ratio estimation requires n >= 10.",
        "i" = "Collect more interview observations before estimating {estimation_type}."
      ))
    }

    if (n >= 10 && n < 30) {
      cli::cli_warn(c(
        "Small sample size for {estimation_type} estimation.",
        "!" = "Sample size is {n}. Ratio estimates are more stable with n >= 30.",
        "i" = "Variance estimates may be unstable with n < 30."
      ))
    }
  } else {
    # Grouped validation
    # Count interviews per group combination
    group_data <- interviews[by_vars]
    group_data$.count <- 1
    group_counts <- stats::aggregate(
      .count ~ .,
      data = group_data,
      FUN = sum
    )
    names(group_counts)[names(group_counts) == ".count"] <- "n"

    # Check for groups with n < 10 (error condition)
    small_groups <- group_counts[group_counts$n < 10, ]
    if (nrow(small_groups) > 0) {
      # Build bullet items for each small group
      bullet_items <- character(nrow(small_groups))
      for (i in seq_len(nrow(small_groups))) {
        group_vals <- small_groups[i, by_vars, drop = FALSE]
        group_label <- paste(
          paste0(by_vars, "=", group_vals),
          collapse = ", "
        )
        n_obs <- small_groups$n[i]
        bullet_items[i] <- sprintf(
          "Group %s: n=%d",
          group_label,
          n_obs
        )
      }
      names(bullet_items) <- rep("*", length(bullet_items))

      cli::cli_abort(c(
        "Insufficient sample size in {nrow(small_groups)} group{?s}:",
        bullet_items,
        "x" = "Ratio estimation requires n >= 10 per group.",
        "i" = "Combine small groups or collect more interview observations."
      ))
    }

    # Check for groups with 10 <= n < 30 (warning condition)
    medium_groups <- group_counts[group_counts$n >= 10 & group_counts$n < 30, ]
    if (nrow(medium_groups) > 0) {
      # Build bullet items for each medium group
      bullet_items <- character(nrow(medium_groups))
      for (i in seq_len(nrow(medium_groups))) {
        group_vals <- medium_groups[i, by_vars, drop = FALSE]
        group_label <- paste(
          paste0(by_vars, "=", group_vals),
          collapse = ", "
        )
        n_obs <- medium_groups$n[i]
        bullet_items[i] <- sprintf(
          "Group %s: n=%d",
          group_label,
          n_obs
        )
      }
      names(bullet_items) <- rep("*", length(bullet_items))

      cli::cli_warn(c(
        "Small sample size in {nrow(medium_groups)} group{?s}:",
        bullet_items,
        "!" = "Ratio estimates are more stable with n >= 30 per group.",
        "i" = "Variance estimates may be unstable with n < 30."
      ))
    }
  }

  invisible(NULL)
}

#' Validate MOR estimator availability
#'
#' Checks that trip_status field exists and incomplete trips are available
#' for mean-of-ratios estimation.
#'
#' @param design creel_design object
#'
#' @keywords internal
#' @noRd
validate_mor_availability <- function(design) {
  # Check trip_status_col exists
  if (is.null(design$trip_status_col)) {
    cli::cli_abort(c(
      "MOR estimator requires trip_status field.",
      "x" = "Design has no trip_status_col set.",
      "i" = "Call {.fn add_interviews} with {.arg trip_status} parameter.",
      "i" = "See {.code ?add_interviews} for trip status specification."
    ))
  }

  # Check trip_status column exists in data
  if (!design$trip_status_col %in% names(design$interviews)) {
    cli::cli_abort(c(
      "trip_status column missing from interview data.",
      "x" = "Expected column: {.val {design$trip_status_col}}",
      "i" = "This is an internal error - please report."
    ))
  }

  # Count incomplete trips
  trip_statuses <- design$interviews[[design$trip_status_col]]
  n_incomplete <- sum(trip_statuses == "incomplete", na.rm = TRUE)
  n_total <- length(trip_statuses) # nolint: object_usage_linter

  # Error if no incomplete trips
  if (n_incomplete == 0) {
    cli::cli_abort(c(
      "MOR estimator requires incomplete trips.",
      "x" = "All {n_total} interviews are complete trips.",
      "i" = "Use {.code estimator = 'ratio-of-means'} for complete trips.",
      "i" = "MOR is only appropriate for incomplete trip interviews."
    ))
  }

  invisible(TRUE)
}

#' Issue warning about MOR estimator assumptions
#'
#' Every MOR estimation call warns user about incomplete trip assumptions
#' and complete trip preference per CONTEXT.md locked decisions.
#'
#' @param n_incomplete Number of incomplete trips
#' @param n_total Total interviews
#'
#' @keywords internal
#' @noRd
mor_estimation_warning <- function(n_incomplete, n_total) {
  cli::cli_warn(c(
    "!" = "MOR estimator for incomplete trips. Complete trips preferred.",
    "i" = "Using MOR with n={n_incomplete} incomplete of {n_total} total interviews.",
    "i" = "Incomplete trips may have length-of-stay bias (Pollock et al.).",
    "i" = "Validate incomplete estimates with {.fn validate_incomplete_trips} (Phase 19)."
  ))
}

#' Validate interview data structure (Tier 1)
#'
#' Internal validator that checks interview data matches the creel_design structure.
#' Verifies that design-critical columns exist in the interview data and contain no
#' NA values. This is Tier 1 validation - structural checks that must pass before
#' constructing a survey design object.
#'
#' @param interviews Data frame containing interview data
#' @param design A creel_design object
#' @param catch_col Character name of catch column in interviews data
#' @param effort_col Character name of effort column in interviews data
#' @param harvest_col Character name of harvest column in interviews data, or NULL
#' @param date_col Character name of date column in interviews data
#' @param allow_invalid Logical flag. If FALSE (default), validation failures
#'   abort with cli error. If TRUE, failures generate warnings instead.
#'
#' @return A creel_validation object with tier = 1L
#'
#' @keywords internal
#' @noRd
validate_interviews_tier1 <- function(
  interviews,
  design,
  catch_col,
  effort_col,
  harvest_col,
  date_col,
  allow_invalid = FALSE
) {
  collection <- checkmate::makeAssertCollection()

  # Check 1: date_col exists in interviews
  if (!date_col %in% names(interviews)) {
    collection$push(sprintf(
      "Date column '%s' not found in interview data",
      date_col
    ))
  }

  # Check 2: catch_col exists and is numeric
  if (!catch_col %in% names(interviews)) {
    collection$push(sprintf(
      "Catch column '%s' not found in interview data",
      catch_col
    ))
  } else if (!is.numeric(interviews[[catch_col]])) {
    collection$push(sprintf(
      "Catch column '%s' must be numeric, not %s",
      catch_col,
      class(interviews[[catch_col]])[1]
    ))
  }

  # Check 3: effort_col exists and is numeric
  if (!effort_col %in% names(interviews)) {
    collection$push(sprintf(
      "Effort column '%s' not found in interview data",
      effort_col
    ))
  } else if (!is.numeric(interviews[[effort_col]])) {
    collection$push(sprintf(
      "Effort column '%s' must be numeric, not %s",
      effort_col,
      class(interviews[[effort_col]])[1]
    ))
  }

  # Check 4: harvest_col exists and is numeric (only if not NULL)
  if (!is.null(harvest_col)) {
    if (!harvest_col %in% names(interviews)) {
      collection$push(sprintf(
        "Harvest column '%s' not found in interview data",
        harvest_col
      ))
    } else if (!is.numeric(interviews[[harvest_col]])) {
      collection$push(sprintf(
        "Harvest column '%s' must be numeric, not %s",
        harvest_col,
        class(interviews[[harvest_col]])[1]
      ))
    }
  }

  # Check 5: No NA values in date_col
  if (date_col %in% names(interviews)) {
    na_count_date <- sum(is.na(interviews[[date_col]]))
    if (na_count_date > 0) {
      collection$push(sprintf(
        "Date column '%s' contains %d NA value(s)",
        date_col,
        na_count_date
      ))
    }
  }

  # Check 6: Interview dates all exist in design calendar
  if (date_col %in% names(interviews)) {
    interview_dates <- unique(interviews[[date_col]])
    calendar_dates <- design$calendar[[design$date_col]]
    missing_dates <- setdiff(interview_dates, calendar_dates)
    if (length(missing_dates) > 0) {
      collection$push(sprintf(
        "Interview dates not found in design calendar: %s",
        paste(as.character(missing_dates), collapse = ", ")
      ))
    }
  }

  # Check 7: harvest <= catch consistency (if harvest_col provided)
  harvest_col_present <- !is.null(harvest_col) && harvest_col %in% names(interviews)
  catch_col_present <- catch_col %in% names(interviews)
  if (harvest_col_present && catch_col_present) {
    catch_vals <- interviews[[catch_col]]
    harvest_vals <- interviews[[harvest_col]]
    # Check only non-NA rows
    valid_rows <- !is.na(catch_vals) & !is.na(harvest_vals)
    if (any(valid_rows)) {
      violations <- sum(harvest_vals[valid_rows] > catch_vals[valid_rows])
      if (violations > 0) {
        collection$push(sprintf(
          "Harvest exceeds catch in %d row(s) - harvest must be <= catch",
          violations
        ))
      }
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
        "Interview data validation failed (Tier 1):",
        stats::setNames(paste0("{.var ", msgs, "}"), rep("x", length(msgs))),
        "i" = "Interview data must have all design columns with no NA values."
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
  new_creel_validation(
    # nolint: object_usage_linter
    results = results,
    tier = 1L,
    context = "add_interviews validation"
  )
}

#' Validate trip metadata in interview data
#'
#' Internal function that validates trip completion status and duration fields
#' in interview data. Enforces data quality rules for trip_status, trip_duration,
#' trip_start, and interview_time columns.
#'
#' @param interviews Data frame containing interview data
#' @param trip_status_col Character name of trip status column
#' @param trip_duration_col Character name of trip duration column (hours), or NULL
#' @param trip_start_col Character name of trip start time column (POSIXct), or NULL
#' @param interview_time_col Character name of interview time column (POSIXct), or NULL
#'
#' @return invisible(NULL) on success; aborts on validation failure
#'
#' @keywords internal
#' @noRd
validate_trip_metadata <- function(
  interviews,
  trip_status_col,
  trip_duration_col,
  trip_start_col,
  interview_time_col
) {
  collection <- checkmate::makeAssertCollection()

  # Check 1: trip_status_col exists in interviews
  if (!trip_status_col %in% names(interviews)) {
    collection$push(sprintf(
      "Trip status column '%s' not found in interview data",
      trip_status_col
    ))
  } else {
    # Check 2: trip_status_col values are valid
    status_vals <- interviews[[trip_status_col]]
    status_vals_lower <- tolower(status_vals)
    valid_statuses <- c("complete", "incomplete")
    invalid_mask <- !is.na(status_vals_lower) & !status_vals_lower %in% valid_statuses
    if (any(invalid_mask)) {
      invalid_vals <- unique(status_vals[invalid_mask])
      collection$push(sprintf(
        "Trip status column '%s' contains invalid value(s): %s. Must be 'complete' or 'incomplete' (case-insensitive)",
        trip_status_col,
        paste(invalid_vals, collapse = ", ")
      ))
    }

    # Check 3: No NA in trip_status
    na_count <- sum(is.na(status_vals))
    if (na_count > 0) {
      collection$push(sprintf(
        "Trip status column '%s' contains %d NA value(s). Trip status is required for all interviews",
        trip_status_col,
        na_count
      ))
    }
  }

  # Check 4: Mutually exclusive input - error if BOTH trip_duration_col AND (trip_start_col or interview_time_col)
  has_duration <- !is.null(trip_duration_col)
  has_start <- !is.null(trip_start_col)
  has_interview_time <- !is.null(interview_time_col)

  if (has_duration && (has_start || has_interview_time)) {
    collection$push(
      "Provide either trip_duration or trip_start/interview_time, not both"
    )
  }

  # Check 5: trip_start requires interview_time
  if (has_start && !has_interview_time) {
    collection$push(
      "trip_start requires interview_time to calculate duration"
    )
  }

  # Check 6: interview_time requires trip_start
  if (has_interview_time && !has_start) {
    collection$push(
      "interview_time requires trip_start to calculate duration"
    )
  }

  # Check 7: Duration column validation (if trip_duration_col provided)
  if (has_duration) {
    if (!trip_duration_col %in% names(interviews)) {
      collection$push(sprintf(
        "Trip duration column '%s' not found in interview data",
        trip_duration_col
      ))
    } else {
      duration_vals <- interviews[[trip_duration_col]]

      # Must be numeric
      if (!is.numeric(duration_vals)) {
        collection$push(sprintf(
          "Trip duration column '%s' must be numeric, not %s",
          trip_duration_col,
          class(duration_vals)[1]
        ))
      } else {
        # No NA values
        na_count_duration <- sum(is.na(duration_vals))
        if (na_count_duration > 0) {
          collection$push(sprintf(
            "Trip duration column '%s' contains %d NA value(s). Trip duration is required for all interviews",
            trip_duration_col,
            na_count_duration
          ))
        }

        # No negative values
        if (any(duration_vals < 0, na.rm = TRUE)) {
          collection$push(sprintf(
            "Trip duration column '%s' contains negative values",
            trip_duration_col
          ))
        }

        # No values < 1/60 hours (1 minute)
        min_duration <- 1 / 60
        if (any(duration_vals < min_duration & duration_vals >= 0, na.rm = TRUE)) {
          collection$push(sprintf(
            # nolint: line_length_linter
            paste(
              "Trip duration column '%s' contains values less than 1 minute (1/60 hours).",
              "Trip durations less than 1 minute are unrealistic"
            ),
            trip_duration_col
          ))
        }

        # Warn if any values > 48 hours
        if (any(duration_vals > 48, na.rm = TRUE)) {
          n_long <- sum(duration_vals > 48, na.rm = TRUE) # nolint: object_usage_linter
          cli::cli_warn(c(
            # nolint: line_length_linter
            "!" = "Trip duration column '{trip_duration_col}' contains {n_long} value{?s} > 48 hours",
            "i" = "Multi-day trips are valid, but verify these are not data entry errors"
          ))
        }
      }
    }
  }

  # Check 8: Time column validation (if trip_start_col and interview_time_col provided)
  if (has_start && has_interview_time) {
    # Check trip_start_col exists
    if (!trip_start_col %in% names(interviews)) {
      collection$push(sprintf(
        "Trip start column '%s' not found in interview data",
        trip_start_col
      ))
    } else {
      start_vals <- interviews[[trip_start_col]]

      # Must be POSIXct or POSIXlt
      if (!inherits(start_vals, "POSIXct") && !inherits(start_vals, "POSIXlt")) {
        collection$push(sprintf(
          "Trip start column '%s' must be POSIXct or POSIXlt, not %s",
          trip_start_col,
          class(start_vals)[1]
        ))
      }

      # No NA values
      na_count_start <- sum(is.na(start_vals))
      if (na_count_start > 0) {
        collection$push(sprintf(
          "Trip start column '%s' contains %d NA value(s)",
          trip_start_col,
          na_count_start
        ))
      }
    }

    # Check interview_time_col exists
    if (!interview_time_col %in% names(interviews)) {
      collection$push(sprintf(
        "Interview time column '%s' not found in interview data",
        interview_time_col
      ))
    } else {
      interview_vals <- interviews[[interview_time_col]]

      # Must be POSIXct or POSIXlt
      if (!inherits(interview_vals, "POSIXct") && !inherits(interview_vals, "POSIXlt")) {
        collection$push(sprintf(
          "Interview time column '%s' must be POSIXct or POSIXlt, not %s",
          interview_time_col,
          class(interview_vals)[1]
        ))
      }

      # No NA values
      na_count_interview <- sum(is.na(interview_vals))
      if (na_count_interview > 0) {
        collection$push(sprintf(
          "Interview time column '%s' contains %d NA value(s)",
          interview_time_col,
          na_count_interview
        ))
      }
    }

    # If both columns exist and are time-like, check computed duration
    if (
      trip_start_col %in%
        names(interviews) && # nolint: indentation_linter
        interview_time_col %in% names(interviews)
    ) {
      # nolint: indentation_linter
      start_vals <- interviews[[trip_start_col]]
      interview_vals <- interviews[[interview_time_col]]

      if (
        (inherits(start_vals, "POSIXct") || inherits(start_vals, "POSIXlt")) && # nolint: indentation_linter
          (inherits(interview_vals, "POSIXct") || inherits(interview_vals, "POSIXlt"))
      ) {
        # nolint: indentation_linter
        # Check timezone consistency
        tz_start <- attr(start_vals, "tzone")
        tz_interview <- attr(interview_vals, "tzone")
        # Only error if both explicitly set to different timezones
        if (
          !is.null(tz_start) &&
            !is.null(tz_interview) && # nolint: indentation_linter
            nzchar(tz_start) &&
            nzchar(tz_interview) && # nolint: indentation_linter
            tz_start != tz_interview
        ) {
          collection$push(sprintf(
            # nolint: line_length_linter
            "trip_start timezone '%s' differs from interview_time timezone '%s'. Use the same timezone for both columns", # nolint: line_length_linter
            tz_start,
            tz_interview
          ))
        }

        # Calculate duration in hours
        computed_duration <- as.numeric(
          difftime(interview_vals, start_vals, units = "hours")
        )

        # No negative durations
        if (any(computed_duration < 0, na.rm = TRUE)) {
          collection$push(sprintf(
            paste(
              "Computed duration (interview_time - trip_start) is negative for some interviews.",
              "Check that interview_time > trip_start"
            )
          ))
        }

        # No durations < 1 minute
        min_duration <- 1 / 60
        if (any(computed_duration < min_duration & computed_duration >= 0, na.rm = TRUE)) {
          collection$push(sprintf(
            paste(
              "Computed duration (interview_time - trip_start) is less than 1 minute",
              "for some interviews. This is unrealistic"
            )
          ))
        }

        # Warn if any > 48 hours
        if (any(computed_duration > 48, na.rm = TRUE)) {
          n_long <- sum(computed_duration > 48, na.rm = TRUE) # nolint: object_usage_linter
          cli::cli_warn(c(
            # nolint: line_length_linter
            "!" = "Computed duration (interview_time - trip_start) > 48 hours for {n_long} interview{?s}",
            "i" = "Multi-day trips are valid, but verify these are not data entry errors"
          ))
        }
      }
    }
  }

  # Abort if any validation errors
  if (!collection$isEmpty()) {
    msgs <- collection$getMessages()
    cli::cli_abort(c(
      "Trip metadata validation failed:",
      stats::setNames(paste0("{.var ", msgs, "}"), rep("x", length(msgs)))
    ))
  }

  invisible(NULL)
}

#' Construct interview survey design object
#'
#' Internal function that wraps survey::svydesign() for interview data with
#' domain-specific error handling. Constructs a stratified survey design from
#' interview data using terminal sampling units (ids = ~1) since interviews
#' are individual observations, not clustered by day.
#'
#' For multiple strata columns, creates an interaction variable to combine them
#' into a single stratification factor before passing to svydesign.
#'
#' @param design A creel_design object with $interviews already populated
#'
#' @return An object of class "survey.design2" (from survey::svydesign)
#'
#' @keywords internal
#' @noRd
construct_interview_survey <- function(design) {
  interviews_data <- design$interviews
  strata_cols <- design$strata_cols

  # Create strata variable
  if (length(strata_cols) == 1) {
    # Single stratum - use directly
    interviews_data$.strata <- interviews_data[[strata_cols]]
  } else {
    # Multiple strata - create interaction
    strata_factors <- interviews_data[strata_cols]
    interviews_data$.strata <- interaction(strata_factors, drop = TRUE)
  }

  # Build formulas - use ~1 for ids (terminal sampling units)
  strata_formula <- stats::reformulate(".strata")

  # Attempt to construct survey design with error wrapping
  tryCatch(
    {
      build_interview_survey(interviews_data, strata = strata_formula)
    },
    error = function(e) {
      # Detect specific error types and provide domain guidance
      err_msg <- conditionMessage(e)

      if (grepl("Stratum.*has only one PSU", err_msg, ignore.case = TRUE)) {
        # Lonely PSU error (less likely for interviews but handle it)
        cli::cli_abort(
          c(
            "Interview survey construction failed: lonely PSU detected.",
            "x" = paste(
              "At least one stratum has only one observation.",
              "Variance estimation requires 2+ observations per stratum."
            ),
            "i" = "Possible solutions:",
            "*" = "Combine small strata with similar characteristics",
            "*" = "Use a different stratification scheme",
            "*" = "Collect more interview observations in sparse strata"
          ),
          class = "creel_error_single_psu"
        )
      } else if (grepl("variable.*not found", err_msg, ignore.case = TRUE)) {
        # Column not found
        required_cols <- strata_cols # nolint: object_usage_linter
        cli::cli_abort(c(
          "Interview survey construction failed: missing column.",
          "x" = err_msg,
          "i" = "Required columns: {.field {required_cols}}"
        ))
      } else {
        # Generic survey error - wrap with guidance
        cli::cli_abort(c(
          "Interview survey construction failed.",
          "x" = err_msg,
          "i" = paste(
            "Check that interview data has correct structure for",
            "strata columns {.field {strata_cols}}."
          )
        ))
      }
    }
  )
}

#' Validate design compatibility for total catch/harvest estimation
#'
#' Checks that design has both count data (for effort) and interview data
#' (for CPUE/HPUE) required to compute total catch/harvest as effort × rate.
#'
#' @param design A creel_design object
#'
#' @return NULL (invisible) - function called for side effects (errors)
#'
#' @keywords internal
#' @noRd
validate_design_compatibility <- function(design) {
  # Check count data exists
  if (is.null(design$counts) || is.null(design$survey)) {
    cli::cli_abort(c(
      "No count data available for effort estimation.",
      "x" = "Total catch/harvest requires both effort (from counts) and catch rates (from interviews).",
      "i" = "Call {.fn add_counts} before estimating total catch or harvest:",
      "i" = "{.code design <- add_counts(design, count_data)}"
    ))
  }

  # Check interview data exists
  if (is.null(design$interviews) || is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview data available for catch rate estimation.",
      "x" = "Total catch/harvest requires both effort (from counts) and catch rates (from interviews).",
      "i" = "Call {.fn add_interviews} before estimating total catch or harvest:",
      "i" = "{.code design <- add_interviews(design, interviews, catch = catch, effort = effort)}"
    ))
  }

  invisible(NULL)
}

#' Validate grouping variable compatibility for total catch/harvest
#'
#' Checks that grouping variables specified in by parameter exist in both
#' count data (for effort) and interview data (for CPUE/HPUE), enabling grouped
#' total catch/harvest estimation.
#'
#' @param design A creel_design object
#' @param by_vars Character vector of grouping variable names
#'
#' @return NULL (invisible) - function called for side effects (errors)
#'
#' @keywords internal
#' @noRd
validate_grouping_compatibility <- function(design, by_vars) {
  # nolint: object_length_linter
  # Check grouping variables exist in count data
  missing_in_counts <- setdiff(by_vars, names(design$counts))
  if (length(missing_in_counts) > 0) {
    n_missing_counts <- length(missing_in_counts) # nolint: object_usage_linter
    cli::cli_abort(c(
      "{n_missing_counts} grouping variable{?s} not found in count data:",
      "x" = "Missing: {.val {missing_in_counts}}",
      "i" = "Available in counts: {.val {names(design$counts)}}",
      "i" = "Grouped total estimation requires variables present in both counts and interviews"
    ))
  }

  # Check grouping variables exist in interview data
  missing_in_interviews <- setdiff(by_vars, names(design$interviews))
  if (length(missing_in_interviews) > 0) {
    n_missing_interviews <- length(missing_in_interviews) # nolint: object_usage_linter
    cli::cli_abort(c(
      "{n_missing_interviews} grouping variable{?s} not found in interview data:",
      "x" = "Missing: {.val {missing_in_interviews}}",
      "i" = "Available in interviews: {.val {names(design$interviews)}}",
      "i" = "Grouped total estimation requires variables present in both counts and interviews"
    ))
  }

  invisible(NULL)
}

# Pooled-domain mix warning (GH #242) ------------------------------------

#' Relative spread of a crude rate across a domain's levels
#'
#' Deliberately a ratio of sums straight off the interview columns, not a
#' survey-weighted estimate. `estimate_catch_rate(by=)` aborts when a level
#' holds fewer than 10 interviews, which is exactly the sparse case most at risk
#' here, so a screen built on it would fail where it is needed most. This is
#' O(n), cannot error, and is only ever compared against a threshold.
#'
#' @param interviews Interview data frame.
#' @param domain_col Name of the domain column.
#' @param num_col Name of the rate numerator column (catch or harvest).
#' @param den_col Name of the rate denominator column (angler effort).
#'
#' @return Named list with `spread` (relative, `(max - min) / max`) and `rates`,
#'   or `NULL` when fewer than two levels carry usable effort.
#'
#' @keywords internal
#' @noRd
domain_rate_spread <- function(interviews, domain_col, num_col, den_col) {
  lev <- interviews[[domain_col]]
  num <- suppressWarnings(as.numeric(interviews[[num_col]]))
  den <- suppressWarnings(as.numeric(interviews[[den_col]]))
  ok <- !is.na(lev) & !is.na(num) & !is.na(den) & den > 0
  if (sum(ok) < 2L) {
    return(NULL)
  }

  lev <- as.character(lev[ok])
  num_by <- tapply(num[ok], lev, sum)
  den_by <- tapply(den[ok], lev, sum)
  rates <- num_by / den_by
  # A zero rate is kept deliberately. A level with no catch against positive
  # effort next to a level with catch is the most mix-sensitive case there is;
  # dropping it collapsed `rates` to one level and silenced the warning exactly
  # where it matters most. Only non-finite rates (no effort) are discarded.
  rates <- rates[is.finite(rates)]
  if (length(rates) < 2L || max(rates) <= 0) {
    return(NULL)
  }

  list(spread = (max(rates) - min(rates)) / max(rates), rates = rates)
}

#' Interview columns that could be a domain the counts never classified
#'
#' Every column the design gave a role to is claimed through one of its `*_col`
#' fields, so what is left is genuinely unaccounted for. Restricted to
#' categorical columns with 2-10 levels: a domain is something effort could have
#' been broken down by, not a free-text note or a per-trip measurement.
#'
#' @param design A creel_design object.
#'
#' @return Character vector of candidate column names.
#'
#' @keywords internal
#' @noRd
pooled_domain_candidates <- function(design) {
  interviews <- design[["interviews"]]
  role_cols <- unlist(design[grep("_col$", names(design))], use.names = FALSE)
  claimed <- unique(c(
    role_cols,
    design[["strata_cols"]],
    design[["date_col"]],
    design[["psu_col"]],
    names(design[["counts"]])
  ))

  candidates <- setdiff(names(interviews), claimed)
  # Package-internal working columns are never a user domain.
  candidates <- candidates[!startsWith(candidates, ".")]

  keep <- vapply(
    candidates,
    function(nm) {
      v <- interviews[[nm]]
      if (!(is.character(v) || is.factor(v) || is.logical(v))) {
        return(FALSE)
      }
      n_levels <- length(unique(v[!is.na(v)]))
      n_levels > 1L && n_levels <= 10L
    },
    logical(1)
  )

  candidates[keep]
}

#' Warn that a total is pooled over a domain the counts never classified
#'
#' When a domain is not classified in the counts, the only available total is
#' `E_total * rate_pooled`, and `rate_pooled` is a ratio of means weighted by the
#' **interview sample's** composition over that domain. Had the domain been
#' classified in the counts it would be a stratum and the total would be
#' `sum_h E_h * rate_h`, which is unbiased whatever the interview composition.
#'
#' The two agree only when the interview sample's effort composition matches the
#' true effort composition. Interview selection is non-proportional to effort by
#' construction of the standard designs -- access interviews intercept completed
#' trips, over-representing anglers who must return to a fixed point, and roving
#' interviews are length-biased toward longer trips (Malvestuto 1996). So the
#' mix differs by design, not by accident, and when levels differ in rate the
#' pooled total inherits that difference.
#'
#' This cannot be verified from within the data: the counts hold no composition
#' to compare against. The warning therefore flags a risk, not a defect, and is
#' worded so it is not read as an error.
#'
#' @param design A creel_design object.
#' @param fn_label Name of the calling estimator, for the message.
#' @param num_col Rate numerator column; defaults to the design's catch column.
#'
#' @return NULL, invisibly. Called for its warning.
#'
#' @keywords internal
#' @noRd
warn_pooled_domain_mix <- function(design, fn_label, num_col = NULL) {
  interviews <- design[["interviews"]]
  # No counts means no total to compute, so there is nothing to warn about yet.
  if (is.null(interviews) || is.null(design[["counts"]]) || nrow(interviews) < 2L) {
    return(invisible(NULL))
  }

  num_col <- num_col %||% design[["catch_col"]]
  den_col <- design[["angler_effort_col"]] %||% design[["effort_col"]]
  if (is.null(num_col) || is.null(den_col)) {
    return(invisible(NULL))
  }
  if (!all(c(num_col, den_col) %in% names(interviews))) {
    return(invisible(NULL))
  }

  flagged <- character(0)
  detail <- character(0)
  for (nm in pooled_domain_candidates(design)) {
    spread <- domain_rate_spread(interviews, nm, num_col, den_col)
    if (is.null(spread) || spread$spread < pooled_domain_mix_threshold()) {
      next
    }
    flagged <- c(flagged, nm)
    detail <- c(
      detail,
      paste0(
        nm, ": ",
        paste0(names(spread$rates), " ", round(spread$rates, 3), collapse = ", ")
      )
    )
  }

  if (length(flagged) == 0L) {
    return(invisible(NULL))
  }

  cli::cli_warn(
    c(
      paste(
        "{.fn {fn_label}} is pooling over {cli::qty(flagged)}{?a domain/domains}",
        "the counts do not classify: {.field {flagged}}."
      ),
      "!" = paste(
        "The rate differs across {cli::qty(flagged)}{?its/their} levels in these",
        "interviews ({detail}), so the total depends on the interview sample's",
        "mix over {cli::qty(flagged)}{?that domain/those domains}."
      ),
      "i" = paste(
        "Without the domain in the counts the total is",
        "{.code E_total * rate_pooled}, weighted by the interview mix rather",
        "than the effort mix. Interview selection is not proportional to effort",
        "by construction (Malvestuto 1996)."
      ),
      "i" = paste(
        "This is a risk, not an error: the counts carry no composition to check",
        "against, so it cannot be verified from the data."
      ),
      "i" = paste(
        "Classifying {.field {flagged}} in the count data removes the",
        "assumption -- the total becomes {.code sum(E_h * rate_h)}."
      )
    ),
    class = "creel_warning_pooled_domain_mix",
    .frequency = "once",
    # Keyed by the domain as well as the estimator: a later design with a
    # different unclassified domain is a different risk and must still be heard,
    # which a per-function key would silently swallow.
    .frequency_id = paste0(
      "tidycreel_pooled_domain_mix_", fn_label, "_", paste(flagged, collapse = "+")
    )
  )

  invisible(NULL)
}

#' Relative-rate-difference threshold for the pooled-domain warning
#'
#' A deliberate, conservative default rather than a significance test: the
#' quantity being screened is unverifiable, so the threshold only decides when a
#' difference is large enough to be worth mentioning. 20% relative difference
#' between the highest and lowest level.
#'
#' @keywords internal
#' @noRd
pooled_domain_mix_threshold <- function() {
  0.2
}

#' Refuse the section column inside `by=` on a sectioned design
#'
#' A sectioned result is already one row per section, so naming the section
#' column in `by=` asks for a split that has happened. Left to itself it reached
#' `tibble::add_column()` and failed with "Column `section` must not be
#' duplicated", which describes the implementation rather than the request.
#'
#' @param by_vars Character vector of resolved grouping columns.
#' @param design A creel_design object.
#' @param error_call Environment used for error reporting.
#'
#' @return NULL, invisibly.
#'
#' @keywords internal
#' @noRd
refuse_section_in_by <- function(by_vars, design, error_call = rlang::caller_env()) {
  section_col <- design[["section_col"]]
  if (is.null(section_col) || !section_col %in% (by_vars %||% character(0))) {
    return(invisible(NULL))
  }

  cli::cli_abort(
    c(
      "{.arg by} cannot name the section column on a sectioned design.",
      "x" = "{.field {section_col}} is already how the result is split.",
      "i" = "Every row of a sectioned estimate is one section; drop it from {.arg by}.",
      "i" = "To group within sections, name the other variables only."
    ),
    class = "creel_error_section_in_by",
    call = error_call
  )
}

#' Resolve a `by=` selector against count data, explaining the count constraint
#'
#' Effort is estimated from the counts, so `by=` on effort and on any total can
#' only name columns the count data carries. Resolving the selector against
#' `design$counts` enforces that correctly, but tidyselect reports the refusal as
#' "Column `x` doesn't exist" -- misleading when the column plainly exists in the
#' interviews and worked in `estimate_catch_rate(by=)` one line earlier.
#'
#' The counts resolution is attempted unchanged, so every selector that works
#' today keeps working byte-for-byte. Only when it fails is the selector
#' re-resolved against a zero-row union frame, purely to learn which names were
#' asked for. A name found in the interviews but not the counts gets the
#' constraint message; anything else re-raises tidyselect's own error untouched.
#'
#' @param by_quo A quosure holding the user's `by=` selector.
#' @param design A creel_design object.
#' @param species_route Logical. Whether to point at the `by = <species>` route,
#'   which the totals support and `estimate_effort()` does not.
#' @param error_call Environment used for error reporting.
#'
#' @return Character vector of resolved column names.
#'
#' @keywords internal
#' @noRd
eval_select_count_by <- function(by_quo, design, species_route = FALSE, error_call = rlang::caller_env()) {
  rlang::try_fetch(
    names(tidyselect::eval_select(
      by_quo,
      data = design[["counts"]],
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = error_call
    )),
    error = function(cnd) {
      abort_count_unobservable_by(by_quo, design, cnd, species_route, error_call)
    }
  )
}

#' Abort naming the count-observability constraint, or re-raise
#'
#' @param by_quo A quosure holding the user's `by=` selector.
#' @param design A creel_design object.
#' @param cnd The condition raised by resolving `by_quo` against the counts.
#' @param species_route Logical. Whether to point at the `by = <species>` route.
#' @param error_call Environment used for error reporting.
#'
#' @keywords internal
#' @noRd
abort_count_unobservable_by <- function(by_quo, design, cnd, species_route, error_call) {
  count_cols <- names(design[["counts"]])
  interview_cols <- names(design[["interviews"]])

  # Diagnostic-only resolution: a zero-row frame carrying both vocabularies, so
  # that c(day_type, target) reports `target` rather than failing a second time.
  union_cols <- union(count_cols, interview_cols)
  # check.names = FALSE or a non-syntactic column ("trip type") is mangled here,
  # the selector then fails to resolve against the probe, and the constraint
  # message silently never fires for exactly those columns.
  probe <- as.data.frame(
    stats::setNames(rep(list(logical(0)), length(union_cols)), union_cols),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  requested <- tryCatch(
    names(tidyselect::eval_select(by_quo, data = probe, allow_rename = FALSE)),
    error = function(e) character(0)
  )

  interview_only <- setdiff(intersect(requested, interview_cols), count_cols)
  if (length(interview_only) == 0L) {
    # Not the count-observability case -- the user's own tidyselect error stands.
    rlang::cnd_signal(cnd)
  }

  abort_count_unobservable_names(interview_only, design, species_route, error_call)
}

#' Abort naming the count-observability constraint for known column names
#'
#' Split out of `abort_count_unobservable_by()` so a caller that already knows
#' which names are interview-only -- the sectioned species path, which resolves
#' `by=` itself -- raises exactly the same refusal instead of a second wording.
#'
#' @param interview_only Character vector of offending column names.
#' @param design A creel_design object.
#' @param species_route Logical. Whether to point at the `by = <species>` route.
#' @param error_call Environment used for error reporting.
#'
#' @keywords internal
#' @noRd
abort_count_unobservable_names <- function(interview_only, design, species_route, error_call) {
  count_cols <- names(design[["counts"]]) # nolint: object_usage_linter

  # Deparse through symbols so a non-syntactic name keeps its backticks; pasting
  # raw names would suggest `estimate_catch_rate(by = trip type)`, which is not
  # valid R and is worse than offering no suggestion at all.
  quoted <- vapply(interview_only, function(nm) deparse(as.name(nm), backtick = TRUE), character(1))
  rate_by <- if (length(quoted) > 1L) {
    paste0("c(", paste(quoted, collapse = ", "), ")")
  } else {
    quoted
  }
  rate_call <- paste0("estimate_catch_rate(by = ", rate_by, ")") # nolint: object_usage_linter
  hints <- c(
    "i" = "Available for grouping effort: {.field {count_cols}}.",
    "i" = paste(
      "Effort comes from counts, so it can only be split by what the counter",
      "could see. Copying the column into the count data would fabricate a",
      "classification that was never made."
    ),
    "i" = "For a rate over this attribute, use {.code {rate_call}}."
  )
  if (isTRUE(species_route)) {
    hints <- c(
      hints,
      "i" = paste(
        "For species, use {.code by = <species column>}, which apportions catch",
        "against whole effort instead of splitting effort."
      )
    )
  }

  cli::cli_abort(
    c(
      "{.arg by} can only group by columns present in the count data.",
      "x" = "{.field {interview_only}} {?is/are} in the interview data but not the count data.",
      hints
    ),
    class = "creel_error_count_unobservable_by",
    call = error_call
  )
}

#' Issue truncation message for MOR estimation
#'
#' @param n_truncated Number of trips excluded by truncation
#' @param n_before_truncation Size of the interview set truncation was applied
#'   to, counted before it ran. This is the denominator the reported percentage
#'   is a share of, so it must be the set that was actually filtered -- not the
#'   incomplete-trip count, which on an all-trip or complete-trip MOR path is a
#'   different set and, for complete trips, is zero.
#' @param truncate_at Threshold used (hours)
#'
#' @keywords internal
#' @noRd
mor_truncation_message <- function(n_truncated, n_before_truncation, truncate_at) {
  # Only reached with a non-zero denominator: n_before_truncation == 0 forces
  # n_truncated == 0, which returns through the branch below.
  pct_truncated <- n_truncated / n_before_truncation

  if (n_truncated == 0) {
    # No trips truncated - informative message
    cli::cli_inform(c(
      "i" = "MOR truncation: 0 trips excluded (all >= {truncate_at} hours)"
    ))
  } else if (pct_truncated >= 0.10) {
    # >=10% truncated - data quality warning
    pct_label <- sprintf("%.1f%%", pct_truncated * 100) # nolint: object_usage_linter
    cli::cli_warn(c(
      "!" = "MOR truncation: {n_truncated} trip{?s} excluded ({pct_label})",
      "i" = "Trips < {truncate_at} hours excluded to prevent unstable variance",
      "!" = "High truncation rate may indicate data quality issues",
      "i" = "Consider reviewing trip duration data for errors"
    ))
  } else {
    # Normal truncation - informative message
    cli::cli_inform(c(
      "i" = "MOR truncation: {n_truncated} trip{?s} excluded (< {truncate_at} hours)"
    ))
  }
}

#' Warn when complete trip percentage is below threshold
#'
#' Internal function that issues a warning when the percentage of complete trips
#' is below the recommended threshold following Pollock et al. roving-access
#' design best practices. Alerts users to insufficient complete trip samples
#' for scientifically valid estimation.
#'
#' The threshold is controlled by the package option tidycreel.min_complete_pct
#' (default 0.10 = 10%). Users can set a custom threshold for their session:
#' options(tidycreel.min_complete_pct = 0.05)
#'
#' @param n_complete Number of complete trips (integer)
#' @param n_total Total number of interviews (integer)
#' @param threshold Minimum percentage threshold for complete trips (numeric).
#'   If NULL (default), uses getOption("tidycreel.min_complete_pct", 0.10)
#'
#' @return NULL (invisible) - function called for side effects (warnings)
#'
#' @keywords internal
#' @noRd
warn_low_complete_pct <- function(n_complete, n_total, threshold = NULL) {
  # Handle edge case: n_total = 0
  if (n_total == 0) {
    return(invisible(NULL))
  }

  # Get threshold from package option if not provided
  if (is.null(threshold)) {
    threshold <- getOption("tidycreel.min_complete_pct", default = 0.10)
  }

  # Calculate percentage complete
  pct_complete <- n_complete / n_total

  # Skip if percentage meets threshold
  if (pct_complete >= threshold) {
    return(invisible(NULL))
  }

  # Format percentages for display
  pct_complete_display <- sprintf("%.1f", pct_complete * 100) # nolint: object_usage_linter
  threshold_display <- sprintf("%.0f", threshold * 100) # nolint: object_usage_linter

  # Issue warning with scientific rationale and guidance
  cli::cli_warn(c(
    "!" = "Only {pct_complete_display}% of interviews are complete trips (threshold: {threshold_display}%)",
    "i" = "Pollock et al. recommends >=10% complete trips for valid estimation",
    "i" = "Consider use_trips='diagnostic' to validate incomplete trip estimates"
  ))

  invisible(NULL)
}

#' Refuse a camera design at an estimator that cannot handle one
#'
#' `estimate_effort()` and the three total estimators dispatch on
#' `design$design_type` for `bus_route`, `ice` and `aerial`, and every remaining
#' design falls through to the instantaneous path, which sums the count column.
#' A camera design has no branch of its own, so it fell through too — and a
#' camera count is a daily ingress total, a count of arrivals, not an
#' instantaneous count of anglers present. Summing arrivals over days gives
#' arrivals, which is not effort, and nothing said so (GH #214).
#'
#' Refusing rather than dispatching is deliberate. `est_effort_camera()` already
#' implements the calibrated estimator and carries the guards added by #136,
#' #137, #142 and #158; routing to it silently from a second entry point would
#' give those guards two callers to be right about. The camera estimator also
#' takes arguments the generic signature has nowhere to put — `interviews`,
#' `n_anglers`, `h_open`, `calibration` — so a dispatch would have to guess
#' them.
#'
#' Raised at all four entry points because the three totals call
#' `estimate_effort_total()` directly rather than going through
#' `estimate_effort()`, exactly as [warn_missing_period_length()] has to be.
#' Guarding only `estimate_effort()` would leave `estimate_total_catch()` still
#' building a total from the arrival count it refuses.
#'
#' @param design A creel_design object.
#' @param fn Name of the estimator the caller reached, as a string. Chooses the
#'   remedy: the effort entry point has one, the totals do not.
#' @param call Environment for the error's call, so the abort points at the
#'   user's call rather than at this helper.
#'
#' @return NULL (invisible) for every non-camera design. Aborts otherwise.
#'
#' @keywords internal
#' @noRd
refuse_camera_design <- function(design, fn, call = rlang::caller_env()) {
  if (!identical(design$design_type, "camera")) {
    return(invisible(NULL))
  }

  remedy <- if (identical(fn, "estimate_effort")) {
    c(
      "i" = paste(
        "Use {.fn est_effort_camera}, which calibrates the counts against",
        "interview effort and propagates the calibration's uncertainty."
      ),
      "i" = paste(
        "To expand the raw counts uncalibrated, pass",
        "{.code calibration = \"none\"} and {.arg h_open} to that function. The",
        "reported standard error is {.code NA}, because the assumption of one",
        "angler-hour per count per hour open is unmeasured."
      )
    )
  } else {
    c(
      "i" = paste(
        "Camera designs estimate effort only. {.fn est_effort_camera} returns",
        "angler-hours; there is no camera catch estimator to multiply them by."
      ),
      "i" = paste(
        "A total from this function would multiply a rate per angler-hour by a",
        "count of arrivals and report the product as fish."
      )
    )
  }

  cli::cli_abort(
    c(
      "{.fn {fn}} does not estimate camera designs.",
      "x" = paste(
        "A camera count is a daily ingress total -- a count of arrivals -- not",
        "an instantaneous count of anglers present, so summing it over days",
        "gives arrivals rather than effort."
      ),
      remedy
    ),
    class = "creel_error_camera_generic_estimator",
    call = call
  )
}
