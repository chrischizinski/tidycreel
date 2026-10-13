# Recording warnings on the objects they describe (GH #496)
#
# A warning that scrolls past is gone, so a season script that raises dozens
# leaves nothing to look back at, and users silence everything to cope. Every
# tidycreel warning is therefore also recorded, and the record travels with
# the object the call returns: an estimate keeps the warnings raised while it
# was computed, a design keeps the warnings raised by creel_design() and each
# add_*(). get_warnings() reads them back as a table.
#
# Mechanics. creel_warn() is cli::cli_warn() plus a record. A record is keyed
# to the user's call -- the outermost tidycreel frame on the stack -- so a
# total that runs its rate internally collects the rate's warnings too. The
# estimate constructor and record_step() claim the records of the current
# call. Records are only ever copied out, never removed on claim, because one
# call can build several objects (a total builds its rate first) and the one
# returned is built last. Records of calls that have finished are dropped the
# next time the log is touched.
#
# The key is a weak reference to the frame, so the log never keeps a finished
# call's frame -- and the design and intermediate tables in it -- alive.

creel_warning_log <- new.env(parent = emptyenv())
creel_warning_log$records <- list()
creel_warning_log$seq <- 0L

#' The frame of the user's call into tidycreel
#'
#' The outermost frame on the stack whose function belongs to this namespace.
#' @return An environment, or NULL when called from outside the package.
#' @keywords internal
#' @noRd
creel_call_frame <- function() {
  ns <- topenv(environment(creel_call_frame))
  for (i in seq_len(sys.nframe())) {
    env <- environment(sys.function(i))
    if (!is.null(env) && identical(topenv(env), ns)) {
      return(sys.frame(i))
    }
  }
  NULL
}

#' The frame a record is keyed to, or NULL once that frame is gone
#' @keywords internal
#' @noRd
record_frame <- function(record) {
  rlang::wref_key(record$key)
}

#' Drop records whose call is no longer on the stack
#' @keywords internal
#' @noRd
prune_warning_log <- function() {
  live <- sys.frames()
  keep <- vapply(creel_warning_log$records, function(r) {
    frame <- record_frame(r)
    !is.null(frame) && any(vapply(live, identical, logical(1), frame))
  }, logical(1))
  creel_warning_log$records <- creel_warning_log$records[keep]
  invisible(NULL)
}

#' Tier of a warning condition
#'
#' @param cls The condition's class vector.
#' @return 1, 2 or 3; `NA` for a class missing from the registry, which the
#'   registry test forbids.
#' @keywords internal
#' @noRd
creel_warning_tier_of <- function(cls) {
  hit <- intersect(cls, names(creel_warning_tiers))
  if (length(hit)) creel_warning_tiers[[hit[[1]]]] else NA_integer_
}

#' Raise a tidycreel warning and record it
#'
#' Takes exactly the arguments of [cli::cli_warn()]. The record is made from
#' the condition as raised, so a warning that is not raised (one suppressed by
#' `.frequency`) is not recorded, and a warning a caller muffles still is.
#'
#' @keywords internal
#' @noRd
creel_warn <- function(message, ..., .envir = parent.frame()) {
  fn <- raising_fn_name(sys.nframe() - 1L)
  withCallingHandlers(
    cli::cli_warn(message, ..., .envir = .envir),
    creel_warning = function(w) record_creel_warning(w, fn)
  )
}

#' Name of the function that raised a warning
#'
#' Walks out from the frame that called creel_warn() to the nearest frame
#' running a named function of this namespace. A warning raised inside an
#' anonymous function (an lapply() body, whose call reads `FUN(...)`) is named
#' after the function that holds it, and one reached through do.call(), whose
#' call head is the function itself, is named by looking it up.
#'
#' @param frame Index of the frame that called creel_warn().
#' @keywords internal
#' @noRd
raising_fn_name <- function(frame) {
  ns <- topenv(environment(raising_fn_name))
  for (j in rev(seq_len(frame))) {
    head <- sys.call(j)[[1]]
    fun <- sys.function(j)
    if (is.name(head)) {
      nm <- as.character(head)
      if (identical(get0(nm, envir = ns, inherits = FALSE), fun)) {
        return(nm)
      }
    } else if (is.call(head) && as.character(head[[1]])[[1]] %in% c("::", ":::")) {
      return(as.character(head[[3]]))
    }
    # A named namespace function is enclosed by the namespace itself; an
    # anonymous one by the frame of the function that made it.
    if (identical(environment(fun), ns)) {
      for (nm in ls(ns, all.names = TRUE)) {
        if (identical(get(nm, envir = ns), fun)) {
          return(nm)
        }
      }
    }
  }
  NA_character_
}

#' @keywords internal
#' @noRd
record_creel_warning <- function(w, fn) {
  key <- creel_call_frame()
  if (is.null(key)) {
    return(invisible(NULL))
  }
  prune_warning_log()
  creel_warning_log$seq <- creel_warning_log$seq + 1L
  cls <- class(w)
  own <- grep("^creel_warning_", cls, value = TRUE)
  creel_warning_log$records[[length(creel_warning_log$records) + 1L]] <- list(
    key = rlang::new_weakref(key),
    # Set once the record is on a design, so a call that runs several add_*()
    # steps puts each warning on the design once.
    attached = FALSE,
    row = data.frame(
      id = creel_warning_log$seq,
      class = if (length(own)) own[[1]] else NA_character_,
      tier = creel_warning_tier_of(cls),
      fn = fn,
      message = cli::ansi_strip(conditionMessage(w)),
      stringsAsFactors = FALSE
    )
  )
  invisible(NULL)
}

#' An empty warnings table, with the columns get_warnings() returns
#' @keywords internal
#' @noRd
empty_warning_table <- function() {
  data.frame(
    id = integer(0), class = character(0), tier = integer(0),
    fn = character(0), message = character(0), stringsAsFactors = FALSE
  )
}

#' Positions in the log of the current call's records
#' @keywords internal
#' @noRd
current_call_records <- function() {
  key <- creel_call_frame()
  prune_warning_log()
  which(vapply(creel_warning_log$records, function(r) {
    identical(record_frame(r), key)
  }, logical(1)))
}

#' Rows of the warnings table for some log positions
#' @keywords internal
#' @noRd
warning_rows <- function(idx) {
  if (!length(idx)) {
    return(empty_warning_table())
  }
  do.call(rbind, lapply(creel_warning_log$records[idx], `[[`, "row"))
}

#' The warnings raised so far in the current call
#'
#' @return A data frame with the columns of [get_warnings()], possibly empty.
#' @keywords internal
#' @noRd
claim_creel_warnings <- function() {
  warning_rows(current_call_records())
}

#' Append the current call's warnings to a design
#'
#' A design accumulates: each add_*() adds the warnings its call raised. Each
#' record goes on a design once, even when one call runs several add_*()
#' steps. The log marks it rather than the design matching ids, because ids
#' restart in a new session and a saved design keeps the old ones.
#' @keywords internal
#' @noRd
record_design_warnings <- function(design) {
  idx <- current_call_records()
  idx <- idx[!vapply(creel_warning_log$records[idx], `[[`, logical(1), "attached")]
  for (i in idx) creel_warning_log$records[[i]]$attached <- TRUE
  design$warnings <- rbind(design$warnings %||% empty_warning_table(), warning_rows(idx))
  design
}

#' The warnings recorded on a design or an estimate
#'
#' Every warning tidycreel raises is also recorded on the object the call
#' returns, so it can be read back after it has scrolled past. A design keeps
#' the warnings raised by [creel_design()], each `add_*()` step and
#' [adjust_nonresponse()]; an
#' estimate keeps the warnings raised while it was computed, including those
#' from a rate a total computes internally.
#'
#' Each warning has a tier, as listed in [creel_warnings]:
#' \describe{
#'   \item{1}{The estimate may be wrong: units, a missing period length,
#'     sections or cells left out of a total, an SE that ignores the design.}
#'   \item{2}{Data quality or precision: small samples, exclusions, short
#'     trips, thin cells.}
#'   \item{3}{Information: an argument with no effect, an estimator choice.}
#' }
#'
#' A warning is recorded even when the caller handles or muffles it, and is
#' not recorded when it was not raised at all. Warnings raised by other
#' packages (`survey`, `lme4`) are not recorded.
#'
#' @param x A `creel_design` or a `creel_estimates` object.
#'
#' @return A data frame with one row per warning, in the order raised:
#'   \describe{
#'     \item{id}{Position in the session's sequence of tidycreel warnings.}
#'     \item{class}{The warning's own class, `creel_warning_<fact>`.}
#'     \item{tier}{1, 2 or 3, as above.}
#'     \item{fn}{The function that raised it.}
#'     \item{message}{The warning text, without formatting.}
#'   }
#'   Zero rows when nothing was raised.
#'
#' @seealso [creel_warnings] for every class and its meaning.
#' @export
#' @examples
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#'
#' # The party-size warning is handled for this one call, so it does not
#' # print, but the design still records it.
#' design <- withCallingHandlers(
#'   add_interviews(design, example_interviews,
#'     catch = catch_total, effort = hours_fished, trip_status = trip_status
#'   ),
#'   creel_warning_no_party_size = function(w) invokeRestart("muffleWarning")
#' )
#' get_warnings(design)
get_warnings <- function(x) {
  if (inherits(x, "creel_design") || inherits(x, "creel_estimates")) {
    return(x$warnings %||% empty_warning_table())
  }
  cli::cli_abort(
    c(
      "{.fn get_warnings} needs a {.cls creel_design} or a {.cls creel_estimates} object.",
      "x" = "{.arg x} is {.cls {class(x)}}."
    ),
    class = "creel_error_get_warnings_class"
  )
}
