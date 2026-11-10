# GH #482: `%||%` is used throughout R/ but came from base R, which exports it
# only since 4.4.0. DESCRIPTION promises R >= 4.1.0, where every path reaching
# it failed with "could not find function". It must come from the package's
# imports (rlang supplies it on every R version), not from base. A current R
# cannot show the failure directly, so this checks where the name resolves.

test_that("%||% is imported, not taken from base R (#482)", {
  imports <- parent.env(asNamespace("tidycreel"))
  expect_true(exists("%||%", envir = imports, inherits = FALSE))
})
