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

test_that("#438: designs a bundle cannot carry are refused, not written in part", {
  d <- bd_plain()
  old <- d
  old$steps <- NULL
  expect_error(write_design(old, bd_dir("old")), class = "creel_error_bundle_no_steps")
  # Until part 2b a step carries one table, and these designs need a second
  # (the sampling frame).
  for (type in c("bus_route", "ice")) {
    d$design_type <- type
    p <- bd_dir(type)
    expect_error(write_design(d, p), type, class = "creel_error_bundle_unsupported")
    expect_false(file.exists(p))
  }
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

test_that("#459: whole-valued arguments round-trip instead of being refused", {
  # "2" in YAML is the integer 2L, not the double 2, so a census p_period = 1 or
  # an hour-long circuit_time = 2 failed the identical() check and refused a
  # valid design. The rebuilt design must also carry doubles, not integers.
  cal <- data.frame(date = as.Date("2024-06-01") + 0:5, day_type = "weekday")
  d <- creel_design(cal, date = date, strata = day_type)
  cnt <- data.frame(date = cal$date, day_type = "weekday", anglers = 1:6, hrs = 2)
  d <- bd_quiet(add_counts(d, cnt, count_col = anglers, count_type = "progressive",
                           circuit_time = 2, period_length_col = hrs, p_period = 1))
  p <- bd_dir("whole")
  write_design(d, p)
  m <- yaml::read_yaml(file.path(p, "manifest.yml"))
  expect_identical(m$steps[[2]]$args$circuit_time, 2)
  expect_identical(m$steps[[2]]$args$p_period, 1)
  r <- bd_quiet(read_design(p))
  bd_same_design(d, r)
  bd_same_effort(d, r)
})

test_that("#459: the manifest number format reads back as the same double", {
  # Exponent forms without a point ("1e+20") read back as strings, not numbers.
  x <- c(0, 2, -3, 100000, 1e20, -1e20, 1e-20, 2 / 3, 1 / 3)
  for (v in x) {
    expect_identical(yaml::yaml.load(paste0("a: ", unclass(yaml_exact_number(v))))$a, v)
  }
})

test_that("#459: a relative .zip path writes and reads back", {
  skip_if_not_installed("zip")
  # zip::zip() changes into the staging folder, so a relative zip name was
  # written inside the folder it zipped and could not be moved into place.
  withr::local_dir(withr::local_tempdir())
  d <- bd_plain()
  write_design(d, "design.zip")
  expect_identical(list.files(".", all.files = TRUE, no.. = TRUE), "design.zip")
  r <- bd_quiet(read_design("design.zip"))
  bd_same_design(d, r)
  bd_same_effort(d, r)
})

# --- part 2a: catch, lengths, ages, camera, aerial, prepared counts ---------

bd_with_catch <- function() {
  d <- bd_plain()
  bd_quiet(add_catch(d, example_catch, catch_uid = interview_id, interview_uid = interview_id,
                     species = species, count = count, catch_type = catch_type))
}

test_that("#438: catch and ages round-trip to the same species estimates", {
  d <- bd_quiet(add_ages(bd_with_catch(), example_ages, age_uid = interview_id,
                         interview_uid = interview_id, species = species, age = age, age_type = age_type))
  p <- bd_dir("catch-ages")
  write_design(d, p)
  r <- bd_quiet(read_design(p))
  bd_same_design(d, r)
  ea <- bd_quiet(estimate_total_catch(d, by = species))$estimates
  eb <- bd_quiet(estimate_total_catch(r, by = species))$estimates
  expect_equal(eb, ea)
  aa <- bd_quiet(est_age_distribution(d, by = species))
  ab <- bd_quiet(est_age_distribution(r, by = species))
  expect_equal(ab$estimates, aa$estimates)
})

test_that("#438: the catch table is recorded as given, not as add_catch() stored it", {
  # add_catch() lowercases catch_type and makes uids character; replaying the
  # stored table instead of the given one would hide what the user supplied.
  ct <- example_catch
  ct$catch_type <- toupper(ct$catch_type)
  d <- bd_quiet(add_catch(bd_plain(), ct, catch_uid = interview_id, interview_uid = interview_id,
                          species = species, count = count, catch_type = catch_type))
  p <- bd_dir("catch-given")
  write_design(d, p)
  m <- yaml::read_yaml(file.path(p, "manifest.yml"))
  step <- m$steps[[length(m$steps)]]
  expect_identical(step$fn, "add_catch")
  back <- utils::read.csv(file.path(p, step$table))
  expect_identical(unique(back$catch_type), unique(ct$catch_type))
  bd_same_design(d, bd_quiet(read_design(p)))
})

test_that("#438: binned lengths keep their release settings", {
  d <- bd_quiet(add_lengths(bd_plain(), example_lengths, length_uid = interview_id,
                            interview_uid = interview_id, species = species, length = length,
                            length_type = length_type, count = count, release_format = "binned"))
  p <- bd_dir("lengths")
  write_design(d, p)
  r <- bd_quiet(read_design(p))
  expect_identical(r$lengths_release_format, "binned")
  bd_same_design(d, r)
})

test_that("#438: include_data = FALSE leaves out catch, lengths and ages tables", {
  d <- bd_with_catch()
  p <- bd_dir("no-catch-data")
  write_design(d, p, include_data = FALSE)
  m <- yaml::read_yaml(file.path(p, "manifest.yml"))
  fns <- vapply(m$steps, `[[`, "", "fn")
  expect_null(m$steps[[which(fns == "add_catch")]][["table"]])
  # `$table` partial-matched `table_arg`, so a table left out by include_data =
  # FALSE was reported as a missing file instead of asked for.
  expect_error(bd_quiet(read_design(p, counts = example_counts, interviews = example_interviews)),
               "include_data = FALSE", class = "creel_error_bundle_table_missing")
  r <- bd_quiet(read_design(p, counts = example_counts, interviews = example_interviews,
                            data = example_catch))
  bd_same_design(d, r)
})

test_that("#438: an aerial design keeps its correction settings", {
  cal <- unique(example_aerial_glmm_counts[, c("date", "day_type")])
  rownames(cal) <- NULL # row names are not carried; see the PR for #438 part 2a
  for (vis in list(list(visibility_correction = 0.85, visibility_se = 0.05),
                   list(visibility_correction = "none"))) {
    d <- do.call(creel_design, c(list(cal, date = quote(date), strata = quote(day_type),
                                      survey_type = "aerial", angler_ratio = 1,
                                      angler_ratio_se = 0, h_open = 14), vis))
    d <- bd_quiet(add_counts(d, example_aerial_glmm_counts, count_col = n_anglers))
    p <- bd_dir("aerial")
    write_design(d, p, overwrite = TRUE)
    r <- bd_quiet(read_design(p))
    bd_same_design(d, r)
    expect_identical(r$aerial, d$aerial)
    ea <- bd_quiet(estimate_effort_aerial_glmm(d, time_col = time_of_flight))$estimates
    eb <- bd_quiet(estimate_effort_aerial_glmm(r, time_col = time_of_flight))$estimates
    expect_equal(eb, ea)
  }
})

test_that("#438: a camera design keeps its camera mode", {
  cal <- data.frame(date = unique(example_camera_counts$date),
                    day_type = unique(example_camera_counts[, c("date", "day_type")])[["day_type"]])
  d <- creel_design(cal, date = date, strata = day_type, survey_type = "camera",
                    camera_mode = "counter")
  d <- bd_quiet(add_counts(d, example_camera_counts, count_col = ingress_count))
  p <- bd_dir("camera")
  write_design(d, p)
  r <- bd_quiet(read_design(p))
  expect_identical(r$camera$camera_mode, "counter")
  bd_same_design(d, r)
})

test_that("#438: counts from prep_counts_daily_effort() stay marked as effort", {
  # The mark is an attribute a CSV drops. Without it the rebuilt design would
  # read the daily effort as raw instantaneous counts.
  cal <- data.frame(date = as.Date("2024-06-01") + 0:3,
                    day_type = c("weekday", "weekday", "weekend", "weekend"))
  raw <- data.frame(sample_date = cal$date, day_type = cal$day_type, kind = "bank",
                    effort = c(15, 23, 45, 52))
  ready <- prep_counts_daily_effort(raw, date = sample_date, strata = day_type,
                                    effort_type = kind, daily_effort = effort)
  d <- bd_quiet(add_counts(creel_design(cal, date = date, strata = day_type), ready))
  expect_true(d$counts_are_effort)
  p <- bd_dir("prep")
  write_design(d, p)
  m <- yaml::read_yaml(file.path(p, "manifest.yml"))
  expect_true(m$steps[[2]]$counts_are_effort)
  r <- bd_quiet(read_design(p))
  expect_true(r$counts_are_effort)
  bd_same_design(d, r)
  bd_same_effort(d, r)
})

test_that("#438: a table left out by include_data = FALSE is asked for, not reported missing", {
  # `st$table` partial-matched `table_arg`, so the step looked as if it named a
  # file, and the user was told the bundle had lost one.
  p <- bd_dir("ask")
  write_design(bd_plain(), p, include_data = FALSE)
  expect_error(bd_quiet(read_design(p)), "include_data = FALSE", class = "creel_error_bundle_table_missing")
})
