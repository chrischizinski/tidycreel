# Check that vignettes raise only the warnings they mean to (GH #478, #480).
#
# A warning in a rendered vignette is either a defect in the example or a
# deliberate teaching point, and a reader cannot tell which. Each vignette
# listed in `allowed` below is run expression by expression, printing visible
# values as knitr does (so print and plot methods run), and the check
# fails on:
#   - an error;
#   - a warning matching none of the vignette's allowed patterns;
#   - an allowed pattern that never fires, so a stale entry cannot linger
#     after the warning it explained is gone.
# Every allowed pattern must be explained in the vignette's text. That part is
# a review rule, not something this script can check.
#
# Vignettes join the list as #480 restructures them, one pkgdown section at a
# time; a vignette not listed is not checked yet.
#
# Usage: Rscript scripts/check-vignette-warnings.R   (or `just vignette-warnings`)

allowed <- list(
  tidycreel = character(),
  # How-to section (#480).
  # Roving rates drop trips under half an hour and warn when that is 10% or
  # more; the page explains why that many is expected on roving data.
  `instantaneous-counts` = c("MOR truncation"),
  `bus-route-surveys` = character(),
  `ice-fishing` = character(),
  # One paired interview/count day in a stratum: the SE is NA, and the text
  # says why.
  `camera-surveys` = c("has one paired interview/count day"),
  `aerial-surveys` = character(),
  # The page omits n_anglers on purpose to show the party-hour warning
  # (decision on #478), keeps the GLMM's one-row-per-flight counts, and shows
  # the glmer.nb convergence warning open as #492. Each is explained in the text.
  `aerial-glmm` = c(
    "repeated sampling units, with no count time",
    "iteration limit reached",
    "No `n_anglers` provided",
    "Rate and effort may be in different units"
  ),
  # How-to: Tasks, part 1 (#480): the former Estimation group.
  # The interview example is small: 17 complete trips, a 7-trip weekend cell,
  # and method/species domains the counts do not record. The age example
  # rescales aged fish onto the reported catch. The text explains each.
  `interview-estimation` = c(
    "Small sample size for CPUE estimation",
    "pooling over domains the counts do not classify",
    "rests on fewer than 10 trips",
    "Age totals were rescaled"
  ),
  `mark-recapture` = character(),
  # The roving example has 22 interviews, and the truncation example raises the
  # cutoff to show the high-truncation warning; both are explained in the text.
  `incomplete-trips` = c("Small sample size for CPUE estimation", "MOR truncation"),
  `progressive-count-surveys` = character(),
  # 27 interviews over three sections leave thin rate cells, and the
  # missing-section example is there to show its warning.
  `section-estimation` = c(
    "Small sample size for CPUE estimation",
    "rests on fewer than 10 trips",
    "missing section"
  ),
  `temporal-extrapolation` = character(),
  # Explanation section (#480).
  `effort-pipeline` = character(),
  `catch-pipeline` = character(),
  # The single-PSU example attaches counts to strata of two days and one day;
  # add_counts() warns, and the text says the refusal follows from it.
  `replicate-designs` = c("fewer than 3 observations"),
  # The page shows each unit rule failing on purpose: counts without a period
  # length, interviews without a party size, and the product of the two. The
  # text explains each warning where it appears.
  # The roving example drops trips under half an hour, and the text explains
  # why that many is expected on roving data.
  `estimator-choice` = c("MOR truncation"),
  # The missing_rate = "exclude" example is there to show its warning: the
  # total covers the weekday stratum only, and the text says so.
  `refusals-and-na` = c("with no rate excluded"),
  `unit-rules` = c(
    "Instantaneous counts were expanded without a period length",
    "No `n_anglers` provided",
    "Rate and effort may be in different units"
  ),
  glossary = character(),
  # The Pollock et al. (1994) check is party effort, so the interviews carry no
  # n_anglers on purpose; the text explains the warning and the party-hours unit.
  `bus-route-equations` = c("No `n_anglers` provided"),
  `survey-tidycreel` = character(),
  `articles/api-conventions` = character()
)

suppressMessages(devtools::load_all(quiet = TRUE))
options(rlib_warning_verbosity = "verbose")
grDevices::pdf(NULL) # plots are drawn, to raise their warnings, then discarded

check_vignette <- function(name, patterns) {
  r_file <- file.path(tempdir(), paste0(basename(name), ".R"))
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
        utils::capture.output({
          res <- withVisible(eval(exprs[[i]], env))
          if (res$visible) print(res$value)
        }),
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
