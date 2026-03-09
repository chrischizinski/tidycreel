# Tests for add_sections() — Phase 39

# --- Shared fixtures -----------------------------------------------------------

make_base_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"
    )),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
}

make_sections_df <- function() {
  data.frame(
    section = c("North Inlet", "Main Basin", "South Outlet"),
    description = c("Tributary inlet", "Open water", "Dam outlet"),
    area_ha = c(45.0, 820.0, 12.0),
    shoreline_km = c(8.2, 62.1, 3.4),
    stringsAsFactors = FALSE
  )
}

# --- Happy path ----------------------------------------------------------------

test_that("add_sections() returns a creel_design", {
  design <- make_base_design()
  secs <- make_sections_df()

  result <- add_sections(design, secs, section_col = section) # nolint: object_usage_linter

  expect_s3_class(result, "creel_design")
})

test_that("add_sections() stores sections data frame on design$sections", {
  design <- make_base_design()
  secs <- make_sections_df()

  result <- add_sections(design, secs, section_col = section) # nolint: object_usage_linter

  expect_false(is.null(result$sections))
  expect_equal(nrow(result$sections), 3L)
})

test_that("add_sections() stores resolved section_col name", {
  design <- make_base_design()
  secs <- make_sections_df()

  result <- add_sections(design, secs, section_col = section) # nolint: object_usage_linter

  expect_equal(result$section_col, "section")
})

test_that("add_sections() stores optional description_col name", {
  design <- make_base_design()
  secs <- make_sections_df()

  result <- add_sections(design, secs,
    section_col     = section, # nolint: object_usage_linter
    description_col = description # nolint: object_usage_linter
  )

  expect_equal(result$section_description_col, "description")
})

test_that("add_sections() stores optional area_col name", {
  design <- make_base_design()
  secs <- make_sections_df()

  result <- add_sections(design, secs,
    section_col = section, # nolint: object_usage_linter
    area_col    = area_ha # nolint: object_usage_linter
  )

  expect_equal(result$section_area_col, "area_ha")
})

test_that("add_sections() stores optional shoreline_col name", {
  design <- make_base_design()
  secs <- make_sections_df()

  result <- add_sections(design, secs,
    section_col   = section, # nolint: object_usage_linter
    shoreline_col = shoreline_km # nolint: object_usage_linter
  )

  expect_equal(result$section_shoreline_col, "shoreline_km")
})

test_that("add_sections() preserves immutability — original design unchanged", {
  design <- make_base_design()
  secs <- make_sections_df()

  add_sections(design, secs, section_col = section) # nolint: object_usage_linter

  expect_null(design$sections)
  expect_null(design$section_col)
})

test_that("add_sections() works without optional columns", {
  design <- make_base_design()
  secs <- data.frame(
    section = c("A", "B"),
    stringsAsFactors = FALSE
  )

  expect_no_error(
    add_sections(design, secs, section_col = section) # nolint: object_usage_linter
  )
})

# --- Validation errors ---------------------------------------------------------

test_that("add_sections() errors when design is not creel_design", {
  expect_error(
    add_sections(list(), data.frame(section = "A"), section_col = section), # nolint: object_usage_linter
    regexp = "creel_design"
  )
})

test_that("add_sections() errors when sections is not a data frame", {
  design <- make_base_design()

  expect_error(
    add_sections(design, c("A", "B"), section_col = section), # nolint: object_usage_linter
    regexp = "data frame"
  )
})

test_that("add_sections() errors on duplicate section names", {
  design <- make_base_design()
  secs <- data.frame(
    section = c("A", "A", "B"),
    stringsAsFactors = FALSE
  )

  expect_error(
    add_sections(design, secs, section_col = section), # nolint: object_usage_linter
    regexp = "duplicate"
  )
})

test_that("add_sections() errors when sections already registered", {
  design <- make_base_design()
  secs <- make_sections_df()

  design2 <- add_sections(design, secs, section_col = section) # nolint: object_usage_linter

  expect_error(
    add_sections(design2, secs, section_col = section), # nolint: object_usage_linter
    regexp = "already"
  )
})

test_that("add_sections() errors when area_col is non-positive", {
  design <- make_base_design()
  secs <- data.frame(
    section = c("A", "B"),
    area_ha = c(10.0, -5.0),
    stringsAsFactors = FALSE
  )

  expect_error(
    add_sections(design, secs,
      section_col = section, # nolint: object_usage_linter
      area_col    = area_ha # nolint: object_usage_linter
    ),
    regexp = "positive"
  )
})

test_that("add_sections() errors when shoreline_col is non-positive", {
  design <- make_base_design()
  secs <- data.frame(
    section = c("A", "B"),
    shoreline_km = c(5.0, 0.0),
    stringsAsFactors = FALSE
  )

  expect_error(
    add_sections(design, secs,
      section_col   = section, # nolint: object_usage_linter
      shoreline_col = shoreline_km # nolint: object_usage_linter
    ),
    regexp = "positive"
  )
})

# --- Section validation in add_counts() ----------------------------------------

make_design_with_sections <- function() {
  design <- make_base_design()
  secs <- make_sections_df()
  add_sections(design, secs, section_col = section) # nolint: object_usage_linter
}

test_that("add_counts() passes when all section values are registered", {
  design <- make_design_with_sections()

  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    section = c("North Inlet", "Main Basin", "North Inlet", "South Outlet"),
    count = c(10L, 20L, 15L, 8L),
    stringsAsFactors = FALSE
  )

  expect_no_error(add_counts(design, counts))
})

test_that("add_counts() errors on unregistered section value in counts", {
  design <- make_design_with_sections()

  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekday"),
    section = c("North Inlet", "NRTH"), # "NRTH" not registered
    count = c(10L, 20L),
    stringsAsFactors = FALSE
  )

  expect_error(
    add_counts(design, counts),
    regexp = "NRTH"
  )
})

test_that("add_counts() skips section validation when no sections registered", {
  design <- make_base_design() # no add_sections() call

  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekday"),
    count = c(10L, 20L),
    stringsAsFactors = FALSE
  )

  expect_no_error(add_counts(design, counts))
})

# --- Section validation in add_interviews() ------------------------------------

make_design_with_sections_and_counts <- function() { # nolint: object_length_linter
  design <- make_design_with_sections()

  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    section = c("North Inlet", "Main Basin", "North Inlet", "South Outlet"),
    count = c(10L, 20L, 15L, 8L),
    stringsAsFactors = FALSE
  )
  add_counts(design, counts) # nolint: object_usage_linter
}

test_that("add_interviews() passes when all section values are registered", {
  design <- make_design_with_sections_and_counts()

  interviews <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekday"),
    section = c("North Inlet", "Main Basin"),
    catch_total = c(3L, 1L),
    hours_fished = c(2.0, 3.5),
    catch_kept = c(1L, 0L),
    trip_status = c("complete", "complete"),
    stringsAsFactors = FALSE
  )

  expect_no_error(
    suppressWarnings(
      add_interviews(design, interviews, # nolint: object_usage_linter
        catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
        harvest = catch_kept, trip_status = trip_status # nolint: object_usage_linter
      )
    )
  )
})

test_that("add_interviews() errors on unregistered section value", {
  design <- make_design_with_sections_and_counts()

  interviews <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekday"),
    section = c("North Inlet", "MIAN"), # "MIAN" not registered
    catch_total = c(3L, 1L),
    hours_fished = c(2.0, 3.5),
    catch_kept = c(1L, 0L),
    trip_status = c("complete", "complete"),
    stringsAsFactors = FALSE
  )

  expect_error(
    suppressWarnings(
      add_interviews(design, interviews, # nolint: object_usage_linter
        catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
        harvest = catch_kept, trip_status = trip_status # nolint: object_usage_linter
      )
    ),
    regexp = "MIAN"
  )
})
