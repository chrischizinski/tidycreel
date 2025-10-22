# scripts/normalize_exports.R
# More robust normalizer for roxygen @export lines.
# - Matches any roxygen line that contains "@export" anywhere
# - Allows leading spaces and multiple #' markers
# - Replaces ENTIRE line with exactly "#' @export"
files <- Sys.glob("R/*.R")
changed_files <- character()
for (f in files) {
  t <- readLines(f, warn = FALSE)
  t2 <- t
  # Match any roxygen line (starts with optional spaces then one or more #' ) that contains @export
  rx <- "^[[:space:]]*#\\'+[[:space:]]*.*@export.*$"
  hit <- grepl(rx, t2, perl = TRUE)
  if (any(hit)) {
    t2[hit] <- "#' @export"
  }
  if (!identical(t, t2)) {
    writeLines(t2, f, useBytes = TRUE)
    changed_files <- c(changed_files, f)
  }
}
message(sprintf("Normalized @export lines in %d files.", length(unique(changed_files))))
if (length(changed_files)) message(paste(" -", unique(changed_files), collapse = "\n"))
