# Guards for two CRAN policies that R CMD check --as-cran does not test.
#
# CRAN's manual review of 7.0.0 returned the package for both:
#
# 1. Commented-out code in examples. CRAN runs examples to check they still
#    work; a commented-out line is never run, so it can rot unnoticed.
# 2. Changing the user's par(), options() or working directory without
#    restoring it. A function must register on.exit() on the very next line;
#    an example must save the old value and put it back.
#
# Neither check, win-builder, lintr nor code review caught these, so they are
# pinned here. Both scans read package SOURCE (man/, R/), which is absent under
# R CMD check, so they skip there and run under devtools::test() and CI.

pkg_root <- function() {
  path <- normalizePath(testthat::test_path("."), mustWork = FALSE)
  for (i in seq_len(10L)) {
    if (file.exists(file.path(path, "DESCRIPTION"))) {
      return(path)
    }
    parent <- dirname(path)
    if (parent == path) {
      break
    }
    path <- parent
  }
  NULL
}

# Calls that change session state CRAN asks packages to leave alone.
state_setters <- c("par", "options", "setwd", "Sys.setenv", "Sys.setlocale")
setter_pattern <- paste0(
  "(^|[^A-Za-z0-9_.])(graphics::)?(",
  paste(gsub(".", "\\.", state_setters, fixed = TRUE), collapse = "|"),
  ")\\("
)

# The runnable code of an Rd file's \examples, one element per line.
example_lines <- function(rd_file) {
  out <- tempfile(fileext = ".R")
  on.exit(unlink(out), add = TRUE)
  tools::Rd2ex(rd_file, out, commentDontrun = FALSE, commentDonttest = FALSE)
  if (!file.exists(out)) {
    return(character())
  }
  lines <- readLines(out, warn = FALSE)
  # Rd2ex writes a "### Name:/Title:/..." header; it is not example code.
  lines[!grepl("^###", lines)]
}

# A comment line is commented-out code when its text parses as R and contains
# a call, an assignment, a pipe or a `$` access. Prose rarely parses at all,
# and a bare word that parses (e.g. "# design") is not flagged.
commented_code <- function(lines) {
  is_comment <- grepl("^\\s*#", lines)
  body <- sub("^\\s*#+\\s?", "", lines)
  looks_like_code <- grepl(
    "[A-Za-z0-9_.]\\(|\\b(if|for|while|function)\\s*\\(|<-|\\|>|%>%|\\$",
    body
  )
  parses <- vapply(body, function(b) {
    nzchar(trimws(b)) &&
      !inherits(try(parse(text = b), silent = TRUE), "try-error")
  }, logical(1), USE.NAMES = FALSE)
  # Half-code comments such as "x$estimate approximately equals y" do not
  # parse, but open with an `object$field` access that prose never does.
  starts_with_access <- grepl("^[A-Za-z_.][A-Za-z0-9_.]*\\$[A-Za-z_.]", body)
  lines[is_comment & ((looks_like_code & parses) | starts_with_access)]
}

# Setter calls in example code that are not restored. Only the pattern
# `old <- setter(...)` followed later by `setter(old)` counts as restored.
unrestored_example_setters <- function(lines) {
  code <- lines[!grepl("^\\s*#", lines)]
  hits <- grep(setter_pattern, code)
  bad <- character()
  for (i in hits) {
    line <- sub("\\s*#.*$", "", code[i]) # judge the code, not a trailing comment
    if (grepl("on\\.exit\\(", line)) next # on.exit(par(old)) is the restore
    m <- regmatches(line, regexec(
      "^\\s*([A-Za-z_.][A-Za-z0-9_.]*)\\s*<-\\s*(graphics::)?([A-Za-z.]+)\\(",
      line
    ))[[1]]
    if (length(m) == 0L) {
      # Either a restore call itself, or an uncaptured change.
      if (!grepl("\\(\\s*[A-Za-z_.][A-Za-z0-9_.]*\\s*\\)\\s*$", line)) {
        bad <- c(bad, code[i])
      }
      next
    }
    restore <- paste0("(graphics::)?", gsub(".", "\\.", m[4], fixed = TRUE),
                      "\\(\\s*", gsub(".", "\\.", m[2], fixed = TRUE), "\\s*\\)")
    later <- if (i < length(code)) code[(i + 1L):length(code)] else character()
    if (!any(grepl(restore, later))) {
      bad <- c(bad, code[i])
    }
  }
  bad
}

# Setter calls in function code whose next code line is not on.exit().
unguarded_function_setters <- function(lines) {
  is_code <- !grepl("^\\s*#", lines) & nzchar(trimws(lines))
  code_idx <- which(is_code)
  bad <- character()
  for (k in seq_along(code_idx)) {
    line <- lines[code_idx[k]]
    code_part <- sub("#.*$", "", line)
    # on.exit(par(old)) is the restore, not a change.
    if (!grepl(setter_pattern, code_part) || grepl("on\\.exit\\(", code_part)) next
    nxt <- if (k < length(code_idx)) lines[code_idx[k + 1L]] else ""
    if (!grepl("on\\.exit\\(", nxt)) {
      bad <- c(bad, line)
    }
  }
  bad
}

test_that("detectors catch the defects CRAN returned 7.0.0 for", {
  # Each fixture is the defect as it shipped. A guard that passes a clean
  # tree proves nothing unless it also fails on the thing it guards against.
  expect_length(commented_code(c(
    "# site_table <- get_site_contributions(result)",
    "# table(design$interviews$day_type)",
    "# total_catch$estimates$estimate approximately equals effort_est * cpue_est"
  )), 3L)
  expect_length(commented_code("# if (x) y"), 1L)
  expect_length(commented_code(c(
    "# Estimate total catch",
    "# Discrete strategy: T = 10 h, tau = 2 h -> k = 5 valid start times",
    "# design"
  )), 0L)

  expect_length(unrestored_example_setters(
    "options(tidycreel.equivalence_threshold = 0.15)"
  ), 1L)
  expect_length(unrestored_example_setters(c(
    "old <- options(tidycreel.equivalence_threshold = 0.15)",
    "x <- 1"
  )), 1L)
  expect_length(unrestored_example_setters(c(
    "old <- options(tidycreel.equivalence_threshold = 0.15)",
    "options(old)"
  )), 0L)
  # A trailing comment, or restoring through on.exit(), is still a restore.
  expect_length(unrestored_example_setters(c(
    "old <- options(tidycreel.equivalence_threshold = 0.15)",
    "options(old) # put the threshold back"
  )), 0L)
  expect_length(unrestored_example_setters(c(
    "old <- par(mar = c(1, 1, 1, 1))",
    "on.exit(par(old), add = TRUE)"
  )), 0L)

  expect_length(unguarded_function_setters(c(
    "  graphics::par(mar = c(5, 5, 4, 2) + 0.1)",
    "  x_range <- range(1)"
  )), 1L)
  expect_length(unguarded_function_setters(c(
    "  old <- setwd(tempdir())",
    "  on.exit(setwd(old), add = TRUE)"
  )), 0L)
  # getOption() reads, it does not set.
  expect_length(unguarded_function_setters(
    "  x <- getOption(\"tidycreel.min_complete_pct\", 0.10)"
  ), 0L)
})

test_that("no example contains commented-out code", {
  root <- pkg_root()
  skip_if(is.null(root) || !dir.exists(file.path(root, "man")),
          "Package source (man/) not available")

  rd_files <- list.files(file.path(root, "man"), "\\.Rd$", full.names = TRUE)
  expect_gt(length(rd_files), 50L) # the scan must reach the real help pages

  found <- unlist(lapply(rd_files, function(f) {
    hits <- commented_code(example_lines(f))
    if (length(hits)) paste0(basename(f), ": ", trimws(hits)) else character()
  }))
  expect(
    length(found) == 0L,
    paste0(
      "Commented-out code in examples (CRAN policy). Make it run, or ",
      "rewrite it as prose:\n", paste(found, collapse = "\n")
    )
  )
})

test_that("examples restore any par(), options() or working directory they change", {
  root <- pkg_root()
  skip_if(is.null(root) || !dir.exists(file.path(root, "man")),
          "Package source (man/) not available")

  rd_files <- list.files(file.path(root, "man"), "\\.Rd$", full.names = TRUE)
  found <- unlist(lapply(rd_files, function(f) {
    hits <- unrestored_example_setters(example_lines(f))
    if (length(hits)) paste0(basename(f), ": ", trimws(hits)) else character()
  }))
  expect(
    length(found) == 0L,
    paste0(
      "Examples change session state without restoring it. Use ",
      "`old <- options(...)` then `options(old)`:\n",
      paste(found, collapse = "\n")
    )
  )
})

test_that("functions register on.exit() immediately after changing session state", {
  root <- pkg_root()
  skip_if(is.null(root) || !dir.exists(file.path(root, "R")),
          "Package source (R/) not available")

  r_files <- list.files(file.path(root, "R"), "\\.R$", full.names = TRUE)
  found <- unlist(lapply(r_files, function(f) {
    hits <- unguarded_function_setters(readLines(f, warn = FALSE))
    if (length(hits)) paste0(basename(f), ": ", trimws(hits)) else character()
  }))
  expect(
    length(found) == 0L,
    paste0(
      "par()/options()/setwd()/Sys.setenv() without an on.exit() on the next ",
      "line (CRAN policy):\n", paste(found, collapse = "\n")
    )
  )
})
