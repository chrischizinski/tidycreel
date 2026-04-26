# Tests for standardize_species() ----

make_interviews <- function() {
  data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
    species = c("walleye", "Largemouth Bass", "yellow perch"),
    kept = c(2L, 1L, 3L),
    stringsAsFactors = FALSE
  )
}

# Input validation ------------------------------------------------------------

test_that("SPSZ-01: errors when data is not a data frame", {
  expect_error(
    standardize_species(list(species = "walleye")),
    class = "rlang_error"
  )
})

test_that("SPSZ-02: errors when species_col not found", {
  expect_error(
    standardize_species(make_interviews(), species_col = "fish"),
    class = "rlang_error"
  )
})

test_that("SPSZ-03: errors when species_col is not a scalar string", {
  expect_error(
    standardize_species(make_interviews(), species_col = c("a", "b")),
    class = "rlang_error"
  )
})

test_that("SPSZ-04: errors on unsupported lookup system", {
  expect_error(
    standardize_species(make_interviews(), lookup = "FishBase"),
    class = "rlang_error"
  )
})

# Return structure ------------------------------------------------------------

test_that("SPSZ-05: returns a data frame", {
  res <- standardize_species(make_interviews())
  expect_s3_class(res, "data.frame")
})

test_that("SPSZ-06: appends species_code column", {
  res <- standardize_species(make_interviews())
  expect_true("species_code" %in% names(res))
})

test_that("SPSZ-07: row count is unchanged", {
  df <- make_interviews()
  res <- standardize_species(df)
  expect_equal(nrow(res), nrow(df))
})

test_that("SPSZ-08: original species column preserved by default", {
  res <- standardize_species(make_interviews())
  expect_true("species" %in% names(res))
})

test_that("SPSZ-09: keep_original = FALSE drops species column", {
  res <- standardize_species(make_interviews(), keep_original = FALSE)
  expect_false("species" %in% names(res))
})

# Matching logic --------------------------------------------------------------

test_that("SPSZ-10: exact common name match (lowercase)", {
  df <- data.frame(species = "walleye", stringsAsFactors = FALSE)
  res <- standardize_species(df)
  expect_equal(res$species_code, "WAE")
})

test_that("SPSZ-11: case-insensitive common name match", {
  df <- data.frame(species = "Largemouth Bass", stringsAsFactors = FALSE)
  res <- standardize_species(df)
  expect_equal(res$species_code, "LMB")
})

test_that("SPSZ-12: known AFS code passthrough (exact)", {
  df <- data.frame(species = "WAE", stringsAsFactors = FALSE)
  res <- standardize_species(df)
  expect_equal(res$species_code, "WAE")
})

test_that("SPSZ-13: known AFS code passthrough (lowercase input)", {
  # lowercase code is normalised to uppercase via toupper() before matching
  df <- data.frame(species = "wae", stringsAsFactors = FALSE)
  res <- standardize_species(df)
  expect_equal(res$species_code, "WAE")
})

test_that("SPSZ-14: alias match (fuzzy = TRUE default)", {
  df <- data.frame(species = "steelhead", stringsAsFactors = FALSE)
  res <- standardize_species(df)
  expect_equal(res$species_code, "RBT")
})

test_that("SPSZ-15: fuzzy = FALSE skips alias match", {
  df <- data.frame(species = "steelhead", stringsAsFactors = FALSE)
  res <- suppressWarnings(standardize_species(df, fuzzy = FALSE))
  expect_true(is.na(res$species_code))
})

test_that("SPSZ-16: unmatched species returns NA", {
  df <- data.frame(species = "unknown fish xyz", stringsAsFactors = FALSE)
  res <- suppressWarnings(standardize_species(df))
  expect_true(is.na(res$species_code))
})

test_that("SPSZ-17: unmatched species triggers a warning", {
  df <- data.frame(species = "unknown fish xyz", stringsAsFactors = FALSE)
  expect_warning(standardize_species(df))
})

test_that("SPSZ-18: NA in species column propagates as NA code", {
  df <- data.frame(
    species = c("walleye", NA_character_),
    stringsAsFactors = FALSE
  )
  res <- standardize_species(df)
  expect_equal(res$species_code[1], "WAE")
  expect_true(is.na(res$species_code[2]))
})

test_that("SPSZ-19: multiple species in one call resolved correctly", {
  df <- data.frame(
    species = c("walleye", "smallmouth bass", "steelhead", "northern pike"),
    stringsAsFactors = FALSE
  )
  res <- standardize_species(df)
  expect_equal(res$species_code, c("WAE", "SMB", "RBT", "NOP"))
})

test_that("SPSZ-20: lookup = 'afs' (lowercase) accepted", {
  df <- data.frame(species = "walleye", stringsAsFactors = FALSE)
  res <- standardize_species(df, lookup = "afs")
  expect_equal(res$species_code, "WAE")
})

# Edge cases ------------------------------------------------------------------

test_that("SPSZ-21: single-row data frame works", {
  df <- data.frame(species = "bluegill", stringsAsFactors = FALSE)
  res <- standardize_species(df)
  expect_equal(res$species_code, "BLG")
})

test_that("SPSZ-22: all-NA species column produces all-NA codes", {
  df <- data.frame(
    species = rep(NA_character_, 3L),
    stringsAsFactors = FALSE
  )
  res <- standardize_species(df)
  expect_true(all(is.na(res$species_code)))
})

test_that("SPSZ-23: custom species_col name works", {
  df <- data.frame(
    spp = c("walleye", "bluegill"),
    stringsAsFactors = FALSE
  )
  res <- standardize_species(df, species_col = "spp")
  expect_equal(res$species_code, c("WAE", "BLG"))
})

test_that("SPSZ-24: whitespace in species name is trimmed", {
  df <- data.frame(species = "  walleye  ", stringsAsFactors = FALSE)
  res <- standardize_species(df)
  expect_equal(res$species_code, "WAE")
})

test_that("SPSZ-25: other columns in data frame are preserved", {
  df <- make_interviews()
  res <- standardize_species(df)
  expect_true("kept" %in% names(res))
  expect_equal(res$kept, df$kept)
})
