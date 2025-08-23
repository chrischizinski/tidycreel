#' Null-coalescing operator
#'
#' Returns `y` when `x` is `NULL`, otherwise returns `x`.
#' Lightweight fallback to avoid importing infix operators.
#' @keywords internal
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x
