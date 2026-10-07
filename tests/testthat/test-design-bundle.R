# Design bundles (GH #438, part 1). A bundle is a recipe: the steps that built
# a design and the tables they were given. read_design() runs the steps again,
# so the point of every round-trip test here is that the REBUILT design gives
# the same estimates as the original -- not that a file was written.

bd_dir <- function(name) {
  p <- file.path(withr::local_tempdir(.local_envir = parent.frame()), name)
  p
}

bd_quiet <- function(expr) suppressMessages(suppressWarnings(expr))

bd_plain <- function() {
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- bd_quiet(add_counts(d, example_counts, count_col = effort_hours))
  bd_quiet(add_interviews(d, example_interviews, catch = catch_total, effort = hours_fished,
                          trip_status = trip_status, trip_duration = trip_duration, n_anglers = n_anglers))
}

bd_same_design <- function(a, b) {
  slots <- union(names(a), names(b))
  differ <- slots[!vapply(slots, function(s) isTRUE(all.equal(a[[s]], b[[s]])), logical(1))]
  expect_identical(differ, character(0))
}

bd_same_effort <- function(a, b) {
  ea <- bd_quiet(estimate_effort(a))$estimates
  eb <- bd_quiet(estimate_effort(b))$estimates
  expect_equal(eb$estimate, ea$estimate)
  expect_equal(eb$se, ea$se)
}

test_that("#438: a roving design round-trips to the same estimates", {
  d <- bd_plain()
  p <- bd_dir("plain")
  write_design(d, p)
  r <- bd_quiet(read_design(p))
  bd_same_design(d, r)
  bd_same_effort(d, r)
  ca <- bd_quiet(estimate_catch_rate(d))$estimates
  cb <- bd_quiet(estimate_catch_rate(r))$estimates
  expect_equal(cb$estimate, ca$estimate)
})

test_that("#438: a step records only the arguments the caller supplied", {
  # Some functions behave differently when an argument is missing
  # (add_interviews() checks missing(n_anglers)); replaying a default as if it
  # had been given would change that, so defaults are never recorded.
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- bd_quiet(add_interviews(d, example_interviews, catch = catch_total, effort = hours_fished,
                               trip_status = trip_status))
  expect_identical(names(d$steps[[1]]$args), c("date", "strata"))
  expect_identical(names(d$steps[[2]]$args), c("catch", "effort", "trip_status"))
})

test_that("#438: a shift design with p_period from the schedule round-trips", {
  s <- generate_schedule("2024-06-03", "2024-06-30", n_periods = 2, sampling_rate = 0.5,
                         periods_per_day = 1, include_all = TRUE, seed = 3,
                         periods = data.frame(period_id = 1:2, start_time = c("06:00", "13:00"),
                                              end_time = c("13:00", "20:00")))
  d <- bd_quiet(creel_design(s, date = date, strata = day_type))
  w <- s[!is.na(s$p_period), ]
  cnt <- data.frame(date = w$date, day_type = w$day_type, anglers = seq_len(nrow(w)) %% 7 + 2, hrs = 7)
  d <- bd_quiet(add_counts(d, cnt, count_col = anglers, period_length_col = hrs))
  p <- bd_dir("shift")
  write_design(d, p)
  r <- bd_quiet(read_design(p))
  bd_same_design(d, r)
  bd_same_effort(d, r)
})

test_that("#438: a sectioned design round-trips, whatever order the steps ran in", {
  cal <- data.frame(date = as.Date("2024-06-01") + 0:7,
                    day_type = rep(c("weekday", "weekend"), each = 4L))
  d <- creel_design(cal, date = date, strata = day_type)
  counts <- data.frame(date = rep(cal$date, each = 2L), day_type = rep(cal$day_type, each = 2L),
                       section = rep(c("North", "South"), times = 8L),
                       effort_hours = c(15, 12, 23, 19, 18, 14, 21, 17, 45, 38, 52, 44, 48, 40, 51, 43),
                       period_hours = 12)
  d <- bd_quiet(add_counts(d, counts, period_length_col = period_hours))
  d <- bd_quiet(add_sections(d, data.frame(section = c("North", "South")), section_col = section))
  p <- bd_dir("sections")
  write_design(d, p)
  r <- bd_quiet(read_design(p))
  bd_same_design(d, r)
  expect_identical(vapply(r$steps, `[[`, "", "fn"), c("creel_design", "add_counts", "add_sections"))
})

test_that("#438: a night design round-trips with its zone, even one taken from the option", {
  s <- generate_schedule("2024-04-01", "2024-04-14", n_periods = 2, sampling_rate = 0.5,
                         periods_per_day = 1, day_start = "12:00", weekend_days = c("Friday", "Saturday"),
                         include_all = TRUE, seed = 1,
                         periods = data.frame(period_id = 1:2, start_time = c("19:30", "00:30"),
                                              end_time = c("00:30", "06:00")))
  withr::local_options(tidycreel.tz = "America/Denver")
  d <- creel_design(s, date = date, strata = day_type)
  w <- s[!is.na(s$p_period), ]
  cnt <- do.call(rbind, lapply(seq_len(nrow(w)), function(i) {
    r <- w[i, ]
    after <- r$period_id == 2L
    data.frame(date = r$date + c(as.integer(after), 1L), day_type = r$day_type, period_id = r$period_id,
               time = if (after) c("01:30", "04:30") else c("21:30", "00:15"),
               anglers = c(4, 2) + i, hrs = if (after) 5.5 else 5)
  }))
  d <- bd_quiet(add_counts(d, cnt, count_col = anglers, count_time_col = time, period_length_col = hrs))
  iv <- data.frame(date = as.Date(c("2024-04-04", "2024-04-05")), day_type = "weekday",
                   catch = c(2, 1), hours = c(2, 1.5), status = "complete",
                   itime = as.POSIXct(c("2024-04-04 22:00", "2024-04-05 01:30"), tz = "America/Denver"))
  d <- bd_quiet(add_interviews(d, iv, catch = catch, effort = hours, trip_status = status,
                               interview_time = itime))
  p <- bd_dir("night")
  write_design(d, p)
  # Read in a session with no zone set: the bundle carries its own.
  withr::local_options(tidycreel.tz = NULL)
  r <- bd_quiet(read_design(p))
  expect_identical(r$night$tz, "America/Denver")
  expect_identical(attr(r$interviews$itime, "tzone"), "America/Denver")
  bd_same_design(d, r)
  bd_same_effort(d, r)
})

test_that("#438: a table changed after writing fails its checksum, naming the table", {
  p <- bd_dir("edited")
  write_design(bd_plain(), p)
  f <- file.path(p, "02-counts.csv")
  x <- readLines(f)
  x[2] <- sub(",[^,]*$", ",999", x[2])
  writeLines(x, f)
  expect_error(read_design(p), "02-counts.csv", class = "creel_error_bundle_checksum")
  file.remove(f)
  expect_error(read_design(p), "02-counts.csv", class = "creel_error_bundle_table_missing")
})

test_that("#438: include_data = FALSE writes the design; the same data gives the same estimates", {
  d <- bd_plain()
  p <- bd_dir("plan")
  write_design(d, p, include_data = FALSE)
  expect_false(any(grepl("counts|interviews", list.files(p))))
  expect_error(read_design(p), "counts", class = "creel_error_bundle_table_missing")
  r <- bd_quiet(read_design(p, counts = example_counts, interviews = example_interviews))
  bd_same_design(d, r)
  bd_same_effort(d, r)
  expect_error(bd_quiet(read_design(p, counts = example_counts, interviews = example_interviews,
                                    catch = data.frame())), "catch")
})

test_that("#438: a newer format, an unknown field and a foreign manifest are refused", {
  p <- bd_dir("manifest")
  write_design(bd_plain(), p)
  mf <- file.path(p, "manifest.yml")
  m <- yaml::read_yaml(mf)
  newer <- m
  newer$format_version <- 99L
  yaml::write_yaml(newer, mf)
  expect_error(read_design(p), "Update tidycreel", class = "creel_error_bundle_manifest")
  extra <- m
  extra$surprise <- 1L
  yaml::write_yaml(extra, mf)
  expect_error(read_design(p), "surprise", class = "creel_error_bundle_manifest")
  step_extra <- m
  step_extra$steps[[2]]$surprise <- 1L
  yaml::write_yaml(step_extra, mf)
  expect_error(read_design(p), "surprise", class = "creel_error_bundle_manifest")
})

test_that("#438: a hand-written manifest and calendar build a design", {
  p <- bd_dir("handmade")
  dir.create(p)
  utils::write.csv(data.frame(date = as.character(as.Date("2024-06-01") + 0:3),
                              day_type = c("weekday", "weekday", "weekend", "weekend")),
                   file.path(p, "calendar.csv"), row.names = FALSE)
  yaml::write_yaml(list(format = "tidycreel-design", format_version = 1L,
                        steps = list(list(fn = "creel_design",
                                          args = list(date = "date", strata = "day_type"),
                                          table = "calendar.csv"))),
                   file.path(p, "manifest.yml"))
  expect_message(d <- read_design(p), "not verified")
  expect_s3_class(d, "creel_design")
  expect_s3_class(d$calendar$date, "Date")
})

test_that("#438: a design changed by hand is refused, so a bundle cannot lose the change", {
  d <- bd_plain()
  d$calendar$day_type[3] <- if (d$calendar$day_type[3] == "weekday") "weekend" else "weekday"
  expect_error(write_design(d, bd_dir("hand")), "calendar", class = "creel_error_bundle_hand_edited")
})

test_that("#438: designs part 1 cannot carry are refused, not written in part", {
  d <- bd_plain()
  old <- d
  old$steps <- NULL
  expect_error(write_design(old, bd_dir("old")), class = "creel_error_bundle_no_steps")
  d$catch <- data.frame(x = 1)
  p <- bd_dir("catch")
  expect_error(write_design(d, p), "add_catch", class = "creel_error_bundle_unsupported")
  expect_false(file.exists(p))
})

test_that("#438: a .zip bundle round-trips", {
  skip_if_not_installed("zip")
  d <- bd_plain()
  p <- file.path(withr::local_tempdir(), "plain.zip")
  write_design(d, p)
  expect_true(file.exists(p))
  r <- bd_quiet(read_design(p))
  bd_same_effort(d, r)
  expect_error(write_design(d, p), "already exists")
})

test_that("#438: date-times keep their instants: no zone, and the repeated DST hour (review)", {
  # Written as local clock text, a zoneless time would be read in the reader's
  # zone, and the two 01:30s of the fall-back night would collapse into one.
  iv <- example_interviews
  first <- as.POSIXct("2024-11-03 06:30:00", tz = "UTC")  # 01:30 CDT
  iv$seen_chicago <- first + c(0, 3600, rep(7200, nrow(iv) - 2))  # 01:30 CDT, 01:30 CST, ...
  attr(iv$seen_chicago, "tzone") <- "America/Chicago"
  iv$seen_nozone <- as.POSIXct("2024-06-01 10:00:00", tz = "UTC") + seq_len(nrow(iv))
  attr(iv$seen_nozone, "tzone") <- NULL
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- bd_quiet(add_interviews(d, iv, catch = catch_total, effort = hours_fished, trip_status = trip_status))
  p <- bd_dir("times")
  write_design(d, p)
  r <- withr::with_timezone("Asia/Tokyo", bd_quiet(read_design(p)))
  got <- r$steps[[2]]$table
  expect_identical(as.numeric(got$seen_chicago), as.numeric(iv$seen_chicago))
  expect_identical(attr(got$seen_chicago, "tzone"), "America/Chicago")
  expect_identical(as.numeric(got$seen_nozone), as.numeric(iv$seen_nozone))
  expect_null(attr(got$seen_nozone, "tzone"))
})

test_that("#438: a text value that is literally \"NA\" stays a value (review)", {
  iv <- example_interviews
  iv$note <- c("NA", NA, rep("ok", nrow(iv) - 2))
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- bd_quiet(add_interviews(d, iv, catch = catch_total, effort = hours_fished, trip_status = trip_status))
  p <- bd_dir("na-label")
  write_design(d, p)
  got <- bd_quiet(read_design(p))$steps[[2]]$table$note
  expect_identical(got[1:2], c("NA", NA))
})

test_that("#438: a failed overwrite leaves the existing bundle intact (review)", {
  p <- bd_dir("keep")
  write_design(bd_plain(), p)
  before <- readLines(file.path(p, "manifest.yml"))
  cnt <- example_counts
  cnt$span <- as.difftime(seq_len(nrow(cnt)), units = "hours")  # cannot survive a CSV
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- bd_quiet(add_counts(d, cnt, count_col = effort_hours))
  expect_error(write_design(d, p, overwrite = TRUE), class = "creel_error_bundle_table_roundtrip")
  expect_identical(readLines(file.path(p, "manifest.yml")), before)
  expect_length(list.files(dirname(p), pattern = "^\\.tidycreel-bundle-", all.files = TRUE), 0L)
})

test_that("#438: p_period is recorded as resolved, not evaluated a second time (review)", {
  s <- generate_schedule("2024-06-03", "2024-06-16", n_periods = 1, sampling_rate = 0.5, seed = 3)
  d <- bd_quiet(creel_design(s, date = date, strata = day_type))
  cnt <- data.frame(date = s$date[!is.na(s$day_type)], day_type = s$day_type, anglers = 3, hrs = 8)
  i <- 0L
  d <- bd_quiet(add_counts(d, cnt, count_col = anglers, period_length_col = hrs,
                           p_period = {
                             i <<- i + 1L
                             c(0.5, 1)[i]
                           }))
  expect_identical(i, 1L)
  expect_identical(d$steps[[2]]$args$p_period, 0.5)
})

test_that("#438: numbers in the manifest read back exactly (review)", {
  # yaml's default 7 digits wrote 2/3 as 0.6666667: p_period changed, and a
  # progressive design's circuit_time no longer fitted its shift.
  cal <- data.frame(date = as.Date("2024-06-01") + 0:5, day_type = "weekday")
  d <- creel_design(cal, date = date, strata = day_type)
  cnt <- data.frame(date = cal$date, day_type = "weekday", anglers = 1:6, hrs = 2 / 3)
  d <- bd_quiet(add_counts(d, cnt, count_col = anglers, count_type = "progressive",
                           circuit_time = 2 / 3, period_length_col = hrs, p_period = 1 / 3))
  p <- bd_dir("precise")
  write_design(d, p)
  m <- yaml::read_yaml(file.path(p, "manifest.yml"))
  expect_identical(m$steps[[2]]$args$circuit_time, 2 / 3)
  expect_identical(m$steps[[2]]$args$p_period, 1 / 3)
  r <- bd_quiet(read_design(p))
  bd_same_design(d, r)
})

test_that("#438: a .zip write leaves no staging copy behind (review)", {
  skip_if_not_installed("zip")
  where <- withr::local_tempdir()
  write_design(bd_plain(), file.path(where, "plain.zip"))
  expect_identical(list.files(where, all.files = TRUE, no.. = TRUE), "plain.zip")
})
