# tidycreel.connect: S3 print methods for creel_connection
# Phase 67: CONNECT-05

#' @export
format.creel_connection <- function(x, ...) {
  stop("not yet implemented")
}

#' @export
print.creel_connection <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
