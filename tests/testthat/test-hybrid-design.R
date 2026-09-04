# Tests for as_hybrid_svydesign() ----

# Helpers ---------------------------------------------------------------------
make_access <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(12L, 15L, 30L, 28L),
    stringsAsFactors = FALSE
  )
}

make_roving <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(8L, 10L, 22L, 25L),
    stringsAsFactors = FALSE
  )
}

# The long-form counts table the design now takes (#248). The frame column is
# named `component` and its values are "access"/"roving" so the stratum keys
# stay "weekday.access" and the weight assertions below and in the audit files
# keep testing the same arithmetic across the API change.
make_counts <- function(access = make_access(), roving = make_roving()) {
  access$component <- "access"
  roving$component <- "roving"
  rbind(access, roving)
}

fractions <- list(
  access = c(weekday = 0.5, weekend = 0.5),
  roving = c(weekday = 0.4, weekend = 0.4)
)

# The population of days the totals expand to (#246). Ten weekday days and six
# weekend days, chosen to contain every date the fixtures sample -- including
# the 2024-06-15 weekday HYBR-16 adds to one frame only.
make_calendar <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-07", "2024-06-15", "2024-06-16", "2024-06-17",
      "2024-06-08", "2024-06-09", "2024-06-10", "2024-06-11", "2024-06-12",
      "2024-06-13"
    )),
    day_type = c(rep("weekday", 10), rep("weekend", 6)),
    stringsAsFactors = FALSE
  )
}


# Input validation ------------------------------------------------------------

test_that("HYBR-01: errors when counts is not a data frame", {
  expect_error(
    as_hybrid_svydesign(
      list(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-02: errors when frame_col is not supplied", {
  # No default: the column carries the partition the stratified total rests on,
  # and a default would let a missed argument pick one silently.
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      calendar = make_calendar(),
      fraction = fractions,
      trips_disjoint = TRUE
    ),
    "frame_col.*must be provided"
  )
})

test_that("HYBR-03: errors when required column missing from counts", {
  df <- make_counts()
  df$count <- NULL
  expect_error(
    as_hybrid_svydesign(
      df,
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-04: errors when frame_col names a column counts does not have", {
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "angler_type",
      calendar = make_calendar(),
      fraction = fractions
    ),
    "angler_type.*missing from"
  )
})

test_that("HYBR-05: errors when fraction is NULL", {
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar()
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-06: errors when fraction has no entry for a frame", {
  # Keyed on the frame, not positional, so a frame without an entry is named
  # rather than silently inheriting a neighbour's fraction.
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions["access"],
      trips_disjoint = TRUE
    ),
    "roving"
  )
})

test_that("HYBR-07: errors when fraction missing a stratum", {
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = list(
        access = c(weekday = 0.5), # missing weekend
        roving = fractions$roving
      )
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-08: errors when fraction value <= 0", {
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = list(
        access = c(weekday = 0, weekend = 0.5),
        roving = fractions$roving
      )
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-09: errors when fraction value > 1", {
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = list(
        access = c(weekday = 1.5, weekend = 0.5),
        roving = fractions$roving
      )
    ),
    class = "rlang_error"
  )
})

# Return structure ------------------------------------------------------------

test_that("HYBR-10: returns an svydesign object", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = fractions,
    trips_disjoint = TRUE
  ))
  expect_true(inherits(design, "survey.design"))
})

test_that("HYBR-11: returns creel_hybrid_svydesign class", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = fractions,
    trips_disjoint = TRUE
  ))
  expect_s3_class(design, "creel_hybrid_svydesign")
})

test_that("HYBR-12: combined data carries the frame column and names it", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = fractions,
    trips_disjoint = TRUE
  ))
  expect_true("component" %in% names(design$variables))
  expect_setequal(unique(design$variables$component), c("access", "roving"))
  # The attribute names the frame column, so a consumer does not have to guess.
  expect_equal(attr(design, "component_col"), "component")
})

test_that("HYBR-13: combined data has weight column", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = fractions,
    trips_disjoint = TRUE
  ))
  expect_true("weight" %in% names(design$variables))
  expect_true(all(design$variables$weight > 0))
})

test_that("HYBR-14: row count equals the rows supplied", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = fractions,
    trips_disjoint = TRUE
  ))
  expect_equal(nrow(design$variables), nrow(make_counts()))
})

# Weight correctness ----------------------------------------------------------

test_that("HYBR-15: weights carry the within-day AND the day expansion", {
  # Two factors, not one (#246): 1 / fraction expands the access points
  # covered to the whole of a sampled day, and N_h / n_h expands the sampled
  # days to the days the stratum holds. Asserting only the first would pass
  # while the design silently estimated a sampled-day total.
  design <- suppressWarnings(as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = list(
      access = c(weekday = 0.5, weekend = 0.25),
      roving = fractions$roving
    ),
    trips_disjoint = TRUE
  ))
  vars <- design$variables
  # 10 weekday days and 6 weekend days in the calendar; 2 sampled dates each.
  acc_wk <- vars$weight[vars$component == "access" & vars$day_type == "weekday"]
  expect_equal(unique(acc_wk), (1 / 0.5) * (10 / 2), tolerance = 1e-9)
  acc_we <- vars$weight[vars$component == "access" & vars$day_type == "weekend"]
  expect_equal(unique(acc_we), (1 / 0.25) * (6 / 2), tolerance = 1e-9)

  # The roving frame keeps its own fraction: a lookup keyed on the stratum
  # alone would hand it the access value for the same stratum.
  rov_we <- vars$weight[vars$component == "roving" & vars$day_type == "weekend"]
  expect_equal(unique(rov_we), (1 / 0.4) * (6 / 2), tolerance = 1e-9)
})

# PSU alignment warning -------------------------------------------------------

test_that("HYBR-16: asymmetric dates produce a warning", {
  access_extra <- rbind(
    make_access(),
    data.frame(
      date = as.Date("2024-06-15"),
      day_type = "weekday",
      count = 5L,
      stringsAsFactors = FALSE
    )
  )
  expect_warning(
    as_hybrid_svydesign(
      make_counts(access = access_extra),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions,
      trips_disjoint = TRUE
    ),
    "Asymmetric"
  )
})

test_that("HYBR-17: symmetric dates produce no PSU warning", {
  expect_no_warning(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions,
      trips_disjoint = TRUE,
      fpc = FALSE
    )
  )
})

# fpc = FALSE -----------------------------------------------------------------

test_that("HYBR-18: fpc = FALSE produces a valid design", {
  design <- as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = fractions,
    trips_disjoint = TRUE,
    fpc = FALSE
  )
  expect_s3_class(design, "creel_hybrid_svydesign")
})

# Custom column names ---------------------------------------------------------

test_that("HYBR-19: custom column names work", {
  counts_custom <- make_counts()
  names(counts_custom)[names(counts_custom) == "date"] <- "survey_date"
  names(counts_custom)[names(counts_custom) == "day_type"] <- "stratum"
  names(counts_custom)[names(counts_custom) == "count"] <- "n_anglers"
  names(counts_custom)[names(counts_custom) == "component"] <- "angler_type"

  calendar_custom <- make_calendar()
  names(calendar_custom)[names(calendar_custom) == "date"] <- "survey_date"
  names(calendar_custom)[names(calendar_custom) == "day_type"] <- "stratum"

  design <- as_hybrid_svydesign(
    counts_custom,
    frame_col = "angler_type",
    calendar = calendar_custom,
    date_col = "survey_date",
    strata_col = "stratum",
    count_col = "n_anglers",
    fraction = fractions,
    trips_disjoint = TRUE
  )
  expect_s3_class(design, "creel_hybrid_svydesign")
  expect_equal(attr(design, "component_col"), "angler_type")
})

# svytotal sanity -------------------------------------------------------------

test_that("HYBR-20: svytotal runs without error on the hybrid design", {
  design <- as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = fractions,
    trips_disjoint = TRUE,
    fpc = FALSE
  )
  result <- suppressWarnings(survey::svytotal(~count, design))
  expect_true(is.numeric(coef(result)))
  expect_true(coef(result) > 0)
})

# Missing and mistyped keys ---------------------------------------------------
# Dates and strata are compared through as.character(), which renders NA as the
# string "NA" and then matches it to every other NA. Left unrefused, a missing
# calendar date counts as one more day in N_h -- on a four-day weekday calendar
# with two sampled days, adding one NA row moved the estimated total from 156 to
# 195 with no error and no warning.

test_that("HYBR-21: a missing sampled date is refused", {
  counts_na <- make_counts()
  counts_na$date[2] <- as.Date(NA)
  expect_error(
    as_hybrid_svydesign(
      counts_na,
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions,
      trips_disjoint = TRUE
    ),
    "date.*counts.*missing"
  )
})

test_that("HYBR-22: a missing calendar date is refused, not counted as a day", {
  # The clean calendar is the control: the same design builds, so the refusal
  # below is about the NA and not about the fixture.
  design <- as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = fractions,
    trips_disjoint = TRUE
  )
  expect_s3_class(design, "survey.design")

  calendar_na <- make_calendar()
  calendar_na <- rbind(
    calendar_na,
    data.frame(date = as.Date(NA), day_type = "weekday", stringsAsFactors = FALSE)
  )
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = calendar_na,
      fraction = fractions,
      trips_disjoint = TRUE
    ),
    "date.*calendar.*missing"
  )
})

test_that("HYBR-23: a missing calendar stratum is refused", {
  # A day whose stratum is NA reaches no stratum population at all, so the
  # season it expands to is shorter than the calendar the caller supplied.
  calendar_na <- make_calendar()
  calendar_na$day_type[3] <- NA_character_
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = calendar_na,
      fraction = fractions,
      trips_disjoint = TRUE
    ),
    "day_type.*calendar.*missing"
  )
})

test_that("HYBR-24: a non-Date date column is refused", {
  counts_chr <- make_counts()
  counts_chr$date <- as.character(counts_chr$date)
  expect_error(
    as_hybrid_svydesign(
      counts_chr,
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions,
      trips_disjoint = TRUE
    ),
    "must be a.*Date.*column"
  )
})

test_that("HYBR-25: a non-scalar or missing fpc is refused", {
  # `fpc` is branched on with a bare `if`, where NA is base R's "missing value
  # where TRUE/FALSE needed" and a length-2 vector silently takes its first
  # element -- building the design with a correction the caller never chose.
  for (bad in list(NA, c(TRUE, FALSE), "yes", 1)) {
    expect_error(
      as_hybrid_svydesign(
        make_counts(),
        frame_col = "component",
        calendar = make_calendar(),
        fraction = fractions,
        trips_disjoint = TRUE,
        fpc = bad
      ),
      "fpc.*must be"
    )
  }

  # The two valid values still build.
  for (good in c(TRUE, FALSE)) {
    design <- as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions,
      trips_disjoint = TRUE,
      fpc = good
    )
    expect_s3_class(design, "survey.design")
  }
})

# The frame column itself (#248) ----------------------------------------------

test_that("HYBR-26: frames sharing a date are not read as repeated days", {
  # The regression the long-form table creates. Every frame samples the same
  # dates by design, so in one table those rows share a date and a stratum and
  # differ only by frame. Keyed without the frame, the repeated-day refusal
  # fires on a correct design and no hybrid design can be built at all.
  design <- as_hybrid_svydesign(
    make_counts(),
    frame_col = "component",
    calendar = make_calendar(),
    fraction = fractions,
    trips_disjoint = TRUE
  )
  expect_s3_class(design, "creel_hybrid_svydesign")

  # A genuine repeat -- the same frame counted twice on one date -- is still
  # refused, so the key was widened rather than the check disabled.
  counts_dup <- rbind(make_counts(), make_counts()[1, , drop = FALSE])
  expect_error(
    as_hybrid_svydesign(
      counts_dup,
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions,
      trips_disjoint = TRUE
    ),
    class = "creel_error_repeated_psus"
  )
})

test_that("HYBR-27: a missing frame label is refused", {
  # Through as.character() an NA label becomes the string "NA" and forms a
  # frame of its own, carrying whatever rows lost their label into a stratum
  # nobody asked for -- and `fraction` has no entry for it.
  counts_na <- make_counts()
  counts_na$component[2] <- NA_character_
  expect_error(
    as_hybrid_svydesign(
      counts_na,
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions,
      trips_disjoint = TRUE
    ),
    "component.*counts.*missing"
  )
})

test_that("HYBR-28: fewer than two frames is refused", {
  counts_one <- make_counts()
  counts_one <- counts_one[counts_one$component == "access", , drop = FALSE]
  expect_error(
    as_hybrid_svydesign(
      counts_one,
      frame_col = "component",
      calendar = make_calendar(),
      fraction = fractions,
      trips_disjoint = TRUE
    ),
    "at least two distinct frames"
  )
})

test_that("HYBR-29: three frames stratify and weight independently", {
  # The two-frame ceiling is gone (#248). A third frame is not a special case:
  # it gets its own stratum-by-frame cells, its own n_h, and its own within-day
  # fraction, and the arithmetic is the same as for the first two.
  ice <- make_access()
  ice$count <- c(3L, 4L, 6L, 5L)
  counts3 <- rbind(make_counts(), transform(ice, component = "ice"))

  design <- as_hybrid_svydesign(
    counts3,
    frame_col = "component",
    calendar = make_calendar(),
    fraction = c(fractions, list(ice = c(weekday = 0.2, weekend = 0.2))),
    trips_disjoint = TRUE
  )
  vars <- design$variables

  expect_setequal(unique(vars$component), c("access", "roving", "ice"))
  expect_setequal(
    unique(vars$.hybrid_stratum),
    c(
      "weekday.access", "weekend.access",
      "weekday.roving", "weekend.roving",
      "weekday.ice", "weekend.ice"
    )
  )

  # The third frame's weight uses its own fraction, not a neighbour's.
  ice_wk <- vars$weight[vars$component == "ice" & vars$day_type == "weekday"]
  expect_equal(unique(ice_wk), (1 / 0.2) * (10 / 2), tolerance = 1e-9)

  # And adding it did not disturb the first two.
  acc_wk <- vars$weight[vars$component == "access" & vars$day_type == "weekday"]
  expect_equal(unique(acc_wk), (1 / 0.5) * (10 / 2), tolerance = 1e-9)
})

test_that("HYBR-30: an ambiguous stratum-by-frame key is refused", {
  # The stratum key is `paste(stratum, frame, sep = ".")`, so a dot inside
  # either value can make two different combinations land on one key: stratum
  # "a" with frame "b.c" and stratum "a.b" with frame "c" both give "a.b.c".
  # Pooled, `survey` treats them as one stratum, n_h is counted over the union
  # of their sampled dates, and the day expansion and the fpc are wrong for
  # both -- with no error and no warning. Measured before the guard: four
  # distinct (stratum, frame) pairs collapsed to three strata.
  cts <- make_counts()
  cts$day_type <- ifelse(cts$day_type == "weekday", "a", "a.b")
  cts$component <- ifelse(cts$component == "access", "b.c", "c")
  cal <- make_calendar()
  cal$day_type <- ifelse(cal$day_type == "weekday", "a", "a.b")

  # The message must name the key that actually collides. Computing the guard by
  # indexing the row-length stratum vector with a pair-length `duplicated()`
  # recycles, and still errors, but names whichever keys the recycled positions
  # land on -- so asserting only "ambiguous" passes on a guard that sends the
  # caller to rename a value that is fine.
  expect_error(
    suppressWarnings(as_hybrid_svydesign(
      cts,
      frame_col = "component",
      calendar = cal,
      fraction = list(`b.c` = c(a = 0.5, `a.b` = 0.5), c = c(a = 0.4, `a.b` = 0.4)),
      trips_disjoint = TRUE
    )),
    "a\\.b\\.c"
  )

  # And it must name ONLY the colliding key. Three pairs -- ("a","b.c") and
  # ("a.b","c"), which collide on "a.b.c", plus an innocent ("z","w") -- put the
  # recycled index out of alignment: computing the guard by indexing the
  # row-length stratum vector with a pair-length `duplicated()` reports
  # "a.b.c" AND "z.w", sending the caller to rename a value that is fine.
  cts3 <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-05", "2024-06-06"
    )),
    day_type = c("a", "a", "a.b", "a.b", "z", "z"),
    component = c("b.c", "b.c", "c", "c", "w", "w"),
    count = c(5L, 6L, 7L, 8L, 9L, 10L),
    stringsAsFactors = FALSE
  )
  cal3 <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-07",
      "2024-06-03", "2024-06-04", "2024-06-08",
      "2024-06-05", "2024-06-06", "2024-06-09"
    )),
    day_type = c("a", "a", "a", "a.b", "a.b", "a.b", "z", "z", "z"),
    stringsAsFactors = FALSE
  )
  err <- tryCatch(
    suppressWarnings(as_hybrid_svydesign(
      cts3,
      frame_col = "component",
      calendar = cal3,
      fraction = list(`b.c` = c(a = 0.5), c = c(`a.b` = 0.5), w = c(z = 0.5)),
      trips_disjoint = TRUE
    )),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "a\\.b\\.c")
  expect_false(grepl("z\\.w", err))

  # A dot that cannot collide is still allowed: the guard refuses ambiguity,
  # not dots.
  cts_ok <- make_counts()
  cts_ok$component <- ifelse(cts_ok$component == "access", "b.c", "d")
  design <- as_hybrid_svydesign(
    cts_ok,
    frame_col = "component",
    calendar = make_calendar(),
    fraction = list(`b.c` = fractions$access, d = fractions$roving),
    trips_disjoint = TRUE
  )
  expect_s3_class(design, "creel_hybrid_svydesign")
})

test_that("HYBR-31: fraction entries that name no frame are refused", {
  # An entry for a frame that is not in the data is a typo or a frame that has
  # since been filtered out. Ignored silently, the caller believes a fraction
  # was applied that never was.
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = c(fractions, list(baot = c(weekday = 0.9, weekend = 0.9))),
      trips_disjoint = TRUE
    ),
    "baot"
  )

  # A frame named twice would silently use the first entry and lose the rest.
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = list(
        access = fractions$access,
        roving = fractions$roving,
        access = c(weekday = 0.9, weekend = 0.9)
      ),
      trips_disjoint = TRUE
    ),
    "more than once"
  )

  # A stratum named twice inside one frame's vector is the same failure one
  # level down: the lookup takes the first match, so the later entry is lost.
  expect_error(
    as_hybrid_svydesign(
      make_counts(),
      frame_col = "component",
      calendar = make_calendar(),
      fraction = list(
        access = c(weekday = 0.5, weekend = 0.5, weekday = 0.9),
        roving = fractions$roving
      ),
      trips_disjoint = TRUE
    ),
    "repeated stratum names"
  )
})

test_that("HYBR-32: a frame takes its own fraction whatever the labels contain", {
  # The fraction was looked up on a key pasted from the frame and the stratum.
  # Any separator that paste uses is a character a caller's label may contain,
  # and a carriage return is exactly what a messy import leaves behind: frame
  # "b" at stratum "c\ra" and frame "b\rc" at stratum "a" pasted to one key
  # under sep = "\r", so the second frame silently took the first's fraction --
  # weight 3 where 6 was owed, no error and no warning. The two hybrid strata
  # differ ("c\ra.b" vs "a.b\rc"), so the ambiguity guard does not see this.
  cr <- "\r"
  s1 <- paste0("c", cr, "a")
  f2 <- paste0("b", cr, "c")

  cts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c(s1, s1, "a", "a"),
    component = c("b", "b", f2, f2),
    count = c(5L, 6L, 7L, 8L),
    stringsAsFactors = FALSE
  )
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-05",
      "2024-06-03", "2024-06-04", "2024-06-06"
    )),
    day_type = c(s1, s1, s1, "a", "a", "a"),
    stringsAsFactors = FALSE
  )
  frac <- list(c(0.5), c(0.25))
  names(frac) <- c("b", f2)
  names(frac[[1]]) <- s1
  names(frac[[2]]) <- "a"

  des <- suppressWarnings(as_hybrid_svydesign(
    cts,
    frame_col = "component",
    calendar = cal,
    fraction = frac,
    trips_disjoint = TRUE
  ))

  # Two sampled days of three population days in each stratum, so the day
  # expansion is 3/2 for both and the frames differ only in their fraction.
  expect_equal(
    des$variables$weight,
    (1 / c(0.5, 0.5, 0.25, 0.25)) * (3 / 2)
  )
})
