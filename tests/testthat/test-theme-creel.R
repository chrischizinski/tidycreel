# Tests for theme_creel() and creel_palette()

skip_if_not_installed("ggplot2")

test_that("creel_palette() returns a named palette by default", {
  pal <- creel_palette()
  expect_type(pal, "character")
  expect_true(length(pal) >= 4)
  expect_true(all(c("primary", "link", "accent") %in% names(pal)))
})

test_that("creel_palette(n) returns the requested number of colours", {
  pal <- creel_palette(3)
  expect_length(pal, 3)
  expect_type(pal, "character")
})

test_that("creel_palette() errors on invalid n", {
  expect_error(creel_palette(0), "positive")
  expect_error(creel_palette("3"), "positive")
})

test_that("theme_creel() returns a ggplot theme", {
  th <- theme_creel()
  expect_true(ggplot2::is_theme(th))
})

test_that("theme_creel() can be added to a ggplot object", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    theme_creel()
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("theme_creel() respects custom base size", {
  th <- theme_creel(base_size = 14)
  expect_true(ggplot2::is_theme(th))
})
