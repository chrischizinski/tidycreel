# Tests for the Quarto Creel Report template ----

test_that("Quarto Creel Report template exists and is tidycreel aligned", {
  template_path <- system.file(
    "quarto", "templates", "creel-report", "template.qmd",
    package = "tidycreel"
  )
  expect_true(file.exists(template_path))

  template <- paste(readLines(template_path, warn = FALSE), collapse = "\n")
  expect_match(template, "creel_design\\(")
  expect_match(template, "validation_report\\(")
  expect_match(template, "season_summary\\(")
  expect_match(template, "theme = \"creel\"")
  expect_match(template, "Design Parameters")
  expect_match(template, "Extrapolated Estimates")
})
