# Check that vignettes raise only the warnings they mean to (GH #478, #480).
#
# A warning in a rendered vignette is either a defect in the example or a
# deliberate teaching point, and a reader cannot tell which. Each vignette
# listed in `allowed` below is run expression by expression, and the check
# fails on:
#   - an error;
#   - a warning matching none of the vignette's allowed patterns;
#   - an allowed pattern that never fires, so a stale entry cannot linger
#     after the warning it explained is gone.
# Every allowed pattern must be explained in the vignette's text.
#
# Vignettes join the list as #480 restructures them, one pkgdown section at a
# time; a vignette not listed is not checked yet.
#
# Usage: Rscript scripts/check-vignette-warnings.R   (or `just vignette-warnings`)

allowed <- list(
  # add_interviews() flags zero-catch interviews; the tutorial explains them.
  tidycreel = c("interviews? ha(s|ve) zero catch")
)

suppressMessages(devtools::load_all(quiet = TRUE))
options(rlib_warning_verbosity = "verbose")

check_vignette <- function(name, patterns) {
  r_file <- file.path(tempdir(), paste0(name, ".R"))
  suppressMessages(knitr::purl(
    file.path("vignettes", paste0(name, ".Rmd")),
    output = r_file, quiet = TRUE, documentation = 0
  ))
  exprs <- parse(r_file, keep.source = TRUE)
  lines <- vapply(attr(exprs, "srcref"), function(x) x[1], integer(1))
  env <- new.env(parent = globalenv())
  fired <- character()
  problems <- character()

  for (i in seq_along(exprs)) {
    tryCatch(
      withCallingHandlers(
        utils::capture.output(eval(exprs[[i]], env)),
        warning = function(w) {
          msg <- conditionMessage(w)
          hit <- patterns[vapply(patterns, grepl, logical(1), x = msg)]
          if (length(hit) == 0) {
            problems <<- c(problems, sprintf(
              "purled line %d: unexpected warning: %s", lines[i],
              strsplit(msg, "\n")[[1]][1]
            ))
          }
          fired <<- union(fired, hit)
          invokeRestart("muffleWarning")
        },
        message = function(m) invokeRestart("muffleMessage")
      ),
      error = function(e) {
        problems <<- c(problems, sprintf(
          "purled line %d: error: %s", lines[i], conditionMessage(e)
        ))
      }
    )
  }

  stale <- setdiff(patterns, fired)
  if (length(stale) > 0) {
    problems <- c(problems, sprintf("allowed warning never raised: %s", stale))
  }
  problems
}

failed <- FALSE
for (name in names(allowed)) {
  problems <- check_vignette(name, allowed[[name]])
  if (length(problems) == 0) {
    cat(sprintf("ok    %s\n", name))
  } else {
    failed <- TRUE
    cat(sprintf("FAIL  %s\n", name), sprintf("      %s\n", problems), sep = "")
  }
}
if (failed) quit(status = 1)
