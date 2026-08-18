# validate_shared_multiplier() -------------------------------------------------

#' Validate a shared multiplier and its optional standard error
#'
#' A *shared multiplier* is a single estimated proportion in `(0, 1]` that
#' scales the whole estimate — the aerial visibility correction (GH #135), the
#' angler-to-people ratio (GH #158). Each is estimated from data, so each may
#' carry a standard error, and each contributes once at the total rather than
#' per stratum.
#'
#' All of them share one validation shape, deliberately:
#'
#' * **Required, with an explicit `"none"` opt-out.** These arguments used to
#'   default silently to 1, which asserted "no correction applies" on the
#'   caller's behalf and made an uncorrected estimate indistinguishable from a
#'   correction that happened to equal 1. Not supplying a value is not the same
#'   claim as declaring no correction, so the two are spelled differently and
#'   only one of them is silent.
#' * **The opt-out yields `NA`, never `0`.** Declaring no correction still
#'   leaves the correction's uncertainty unpropagated, and a zero would be
#'   indistinguishable from having propagated it and found none. To assert a
#'   multiplier is known exactly, supply it with an SE of `0` deliberately.
#' * **All-or-none.** A standard error requires a numeric value to describe
#'   (GH #117).
#'
#' @return A list with `value` (numeric, 1 under the opt-out), `se` (numeric,
#'   `NA_real_` under the opt-out, `NULL` when not supplied), and `declared`
#'   (`"none"` or `"estimate"`).
#'
#' @keywords internal
#' @noRd
validate_shared_multiplier <- function(
  value,
  se,
  value_arg,
  se_arg,
  required_class,
  se_class,
  required_hint = character(0),
  above_one_hint = character(0),
  se_hint = character(0)
) {
  is_none <- is.character(value) && length(value) == 1L && identical(value, "none")

  if (is.null(value)) {
    cli::cli_abort(
      c(
        "{.arg {value_arg}} is required for an aerial design.",
        required_hint,
        "i" = "To state that no correction applies, pass {.code {value_arg} = \"none\"}."
      ),
      class = required_class
    )
  }

  bad <- !is_none &&
    (!is.numeric(value) ||
       length(value) != 1L ||
       is.na(value) ||
       value <= 0 ||
       value > 1)
  if (bad) {
    hint <- if (is.numeric(value) && length(value) == 1L && !is.na(value) && value > 1) {
      above_one_hint
    } else {
      c("i" = "Valid range: 0 < {.arg {value_arg}} <= 1.")
    }
    cli::cli_abort(c(
      "{.arg {value_arg}} must be a single number in (0, 1], or the string {.val none}.",
      "x" = "Supplied value {.val {value}} is outside the valid range.",
      hint
    ))
  }

  if (!is.null(se)) {
    if (is_none) {
      cli::cli_abort(
        c(
          "{.arg {se_arg}} cannot be combined with {.code {value_arg} = \"none\"}.",
          "x" = "There is no correction for the standard error to describe.",
          "i" = "Supply {.arg {value_arg}} as a number in (0, 1] to propagate its uncertainty."
        ),
        class = se_class
      )
    }
    if (!is.numeric(se) || length(se) != 1L || is.na(se) || se < 0) {
      cli::cli_abort(c(
        "{.arg {se_arg}} must be a single non-negative number.",
        "x" = "Supplied value {.val {se}} is invalid.",
        se_hint
      ))
    }
  }

  list(
    value = if (is_none) 1 else value,
    se = if (is_none) NA_real_ else se,
    declared = if (is_none) "none" else "estimate"
  )
}
