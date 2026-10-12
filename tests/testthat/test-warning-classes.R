# Every warning has a class, and ?creel_warnings lists exactly those classes
# (GH #496). A class is what lets a caller handle one warning for one call
# instead of suppressWarnings() on everything, which also hides the warnings
# that mean an estimate may be wrong. A warning added without a class, a class
# missing from the help page, or a help-page entry no code raises any more all
# fail here, so the catalogue cannot drift from the code.

# Each cli_warn() call in the namespace, as the character vector its `class`
# argument evaluates to (NULL when it has none). Walks function bodies, so it
# works on the installed package as well as under load_all().
warning_class_args <- function() {
  ns <- asNamespace("tidycreel")
  found <- list()
  walk <- function(x, where) {
    if (is.call(x)) {
      head <- x[[1]]
      is_warn <- identical(head, quote(cli_warn)) ||
        identical(head, quote(cli::cli_warn))
      if (is_warn) {
        cls <- if ("class" %in% names(x)) eval(x[["class"]], baseenv()) else NULL
        found[[length(found) + 1]] <<- list(where = where, class = cls)
      }
      for (el in as.list(x)[-1]) if (!missing(el)) walk(el, where)
    }
  }
  for (nm in ls(ns, all.names = TRUE)) {
    f <- get(nm, envir = ns)
    if (is.function(f) && !is.primitive(f)) walk(body(f), nm)
  }
  found
}

catalogue_classes <- function() {
  src <- test_path("..", "..", "man", "creel_warnings.Rd")
  rd <- if (file.exists(src)) {
    # A malformed page (an unescaped % ends the line) still contains the class
    # names, so a parse warning has to fail the test rather than pass quietly.
    withCallingHandlers(
      tools::parse_Rd(src),
      warning = function(w) stop("man/creel_warnings.Rd: ", conditionMessage(w))
    )
  } else {
    tools::Rd_db("tidycreel")[["creel_warnings.Rd"]]
  }
  txt <- paste(as.character(rd), collapse = "")
  unique(regmatches(txt, gregexpr("creel_warning_[a-z_]+", txt))[[1]])
}

test_that("every warning has its own class and the parent creel_warning", {
  calls <- warning_class_args()
  # Sanity: the walker found the package's warnings, not an empty list.
  expect_gt(length(calls), 100)
  for (cl in calls) {
    own <- grep("^creel_warning_", cl$class, value = TRUE)
    expect_true(
      "creel_warning" %in% cl$class && length(own) == 1,
      info = paste0(cl$where, "(): class = ", paste(cl$class, collapse = ", "))
    )
  }
})

test_that("?creel_warnings lists exactly the classes the code raises", {
  raised <- unique(unlist(lapply(warning_class_args(), function(cl) {
    grep("^creel_warning_", cl$class, value = TRUE)
  })))
  listed <- catalogue_classes()
  expect_setequal(listed, raised)
})

test_that("a classed warning can be handled alone, leaving the others", {
  # The reason for the classes: muffle one fact for one call. Here the
  # roving page's truncation warning is handled while the design still warns
  # about everything else it would have.
  design <- creel_design(example_season_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_season_counts,
    count_col = total_anglers, period_length_col = daylight_hours
  )
  design <- suppressMessages(add_interviews(design, example_roving_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status,
    trip_duration = hours_fished, n_anglers = n_anglers,
    interview_type = "roving"
  ))
  handled <- 0L
  expect_no_warning(withCallingHandlers(
    suppressMessages(estimate_catch_rate(design)),
    creel_warning_mor_truncation = function(w) {
      handled <<- handled + 1L
      invokeRestart("muffleWarning")
    }
  ))
  expect_identical(handled, 1L)
})

test_that("the catch rate and the harvest rate truncate through one implementation", {
  # estimate_catch_rate() and truncate_interviews_for_mor() (harvest and
  # release rates, totals) each carried their own copy of the truncation
  # warnings until GH #496. One shared helper means a change to either cannot
  # leave the other behind: same trips dropped, same warnings, on both routes.
  # add_interviews() refuses a missing duration, so three are blanked
  # afterwards, as in the #272 tests, to reach the missing-duration branch.
  iv <- example_roving_interviews
  iv$duration <- iv$hours_fished
  design <- creel_design(example_season_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_season_counts,
    count_col = total_anglers, period_length_col = daylight_hours
  )
  design <- suppressMessages(add_interviews(design, iv,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = duration,
    n_anglers = n_anglers, interview_type = "roving"
  ))
  iv <- design$interviews
  iv$duration[1:3] <- NA_real_
  design <- rebuild_interview_survey(design, iv)
  classes_of <- function(expr) {
    seen <- character()
    value <- withCallingHandlers(
      suppressMessages(expr),
      creel_warning = function(w) {
        seen <<- c(seen, grep("^creel_warning_", class(w), value = TRUE))
        invokeRestart("muffleWarning")
      }
    )
    list(value = value, classes = seen)
  }
  catch <- classes_of(estimate_catch_rate(design))
  harvest <- classes_of(estimate_harvest_rate(design))
  expect_true("creel_warning_trip_duration_excluded" %in% catch$classes)
  expect_setequal(
    intersect(catch$classes, c(
      "creel_warning_trip_duration_excluded", "creel_warning_mor_truncation"
    )),
    intersect(harvest$classes, c(
      "creel_warning_trip_duration_excluded", "creel_warning_mor_truncation"
    ))
  )
  expect_equal(catch$value$mor_n_truncated, harvest$value$mor_n_truncated)
  expect_gt(catch$value$mor_n_truncated, 0)
})
