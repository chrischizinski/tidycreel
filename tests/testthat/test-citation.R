test_that("citation('tidycreel') returns a non-empty result", {
  cit <- citation("tidycreel")
  expect_true(length(cit) >= 1)
  expect_s3_class(cit, "bibentry")
})

test_that("citation('tidycreel') contains correct author family name", {
  cit <- citation("tidycreel")
  authors <- format(cit$author)
  expect_true(any(grepl("Chizinski", authors, ignore.case = TRUE)))
})

test_that("citation('tidycreel') contains package URL", {
  cit <- citation("tidycreel")
  cit_text <- format(cit, style = "text")
  expect_true(any(grepl("chrischizinski/tidycreel", cit_text, ignore.case = TRUE)))
})
