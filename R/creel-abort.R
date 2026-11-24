#' Abort with a tidycreel refusal
#'
#' Internal (GH #511). [cli::cli_abort()] with `"creel_error"` added to the
#' condition's classes, so every refusal from the package's own checks can be
#' caught as one (argument checks left to checkmate, match.arg() or rlang are
#' not; GH #701): `tryCatch(..., creel_error = ...)`, as every warning can as
#' `creel_warning`. A specific class given by the caller comes first and is
#' unchanged.
#'
#' The message is interpolated in the caller's environment and the error is
#' reported from the caller's call, exactly as a direct `cli::cli_abort()`
#' there would be.
#'
#' @inheritParams cli::cli_abort
#' @param class Subclasses of the condition, most specific first.
#' @keywords internal
#' @noRd
creel_abort <- function(message, ..., class = NULL, call = .envir, .envir = parent.frame(),
                        .frame = .envir) {
  cli::cli_abort(
    message, ...,
    class = unique(c(class, "creel_error")),
    call = call, .envir = .envir, .frame = .frame
  )
}
