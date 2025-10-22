# scripts/find_export_offenders.R
# Report any roxygen lines that still contain "@export" and have extra text
files <- Sys.glob("R/*.R")
any_offenders <- FALSE
for (f in files) {
  t <- readLines(f, warn = FALSE)
  # Offender = roxygen line with @export AND extra non-space text on the same line (beyond the tag)
  rx <- "^[[:space:]]*#\\'+[[:space:]]*@export[[:space:]]+.+$"
  hit <- grepl(rx, t, perl = TRUE)
  if (any(hit)) {
    any_offenders <- TRUE
    cat("Offenders in", f, ":\n")
    for (i in which(hit)) cat(sprintf("  %5d: %s\n", i, t[i]))
  }
}
if (!any_offenders) cat("No remaining offenders found.\\n")
