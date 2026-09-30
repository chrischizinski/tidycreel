# Guarded CRAN submission. Run in an INTERACTIVE R session:
#
#   source("scripts/cran-submit.R")
#   cran_submit("~/Dev/tidycreel-submit", dry_run = TRUE)   # checks only
#   cran_submit("~/Dev/tidycreel-submit")                    # checks, then submits
#
# WHY THIS EXISTS
#
# 8.0.0 was first uploaded through the CRAN web form with a one-line comment
# saying "Details are in cran-comments.md". That file is .Rbuildignore'd, so
# the reviewer never saw the notes it pointed to. devtools::submit_cran() sends
# the whole of cran-comments.md as the comment, but it only WARNS when the file
# is missing and then submits an empty comment, and it builds from whatever
# path it is given -- including a development checkout of main.
#
# This wrapper refuses unless:
#   - the checkout is on a `cran-*` branch whose name carries the DESCRIPTION
#     version (cran-8.0.0 <-> 8.0.0), with no uncommitted changes, and at the
#     same commit as origin;
#   - the version is not a development version (x.y.z.9000);
#   - cran-comments.md exists, is not empty, and names the version.
# It then prints the exact text CRAN will receive and asks for confirmation
# before calling devtools::submit_cran(), which asks its own questions too.

cran_submit <- function(path = "~/Dev/tidycreel-submit", dry_run = FALSE) {
  path <- normalizePath(path, mustWork = TRUE)
  git <- function(...) {
    out <- suppressWarnings(system2("git", c("-C", shQuote(path), ...), stdout = TRUE, stderr = TRUE))
    # No %||%: it is base R only from 4.4.
    status <- attr(out, "status")
    if (!is.null(status) && status != 0L) stop("git ", paste(c(...), collapse = " "), " failed:\n", paste(out, collapse = "\n"), call. = FALSE)
    out
  }
  refuse <- function(...) stop("Refusing to submit: ", ..., call. = FALSE)

  branch <- git("rev-parse", "--abbrev-ref", "HEAD")
  if (!grepl("^cran-", branch)) {
    refuse("'", path, "' is on branch '", branch, "', not a cran-* release branch. ",
           "Never submit from main or a feature branch.")
  }
  # Untracked files count too: submit_cran() builds from the directory, so an
  # untracked file that is not .Rbuildignore'd would enter the tarball.
  # Gitignored files are not listed and need no check.
  if (length(git("status", "--porcelain")) > 0L) {
    refuse("'", path, "' has uncommitted or untracked files.")
  }
  git("fetch", "--quiet", "origin", branch)
  head <- git("rev-parse", "HEAD")
  remote <- git("rev-parse", paste0("origin/", branch))
  if (!identical(head, remote)) {
    refuse("HEAD ", substr(head, 1, 8), " differs from origin/", branch, " ", substr(remote, 1, 8), ".")
  }

  version <- unname(read.dcf(file.path(path, "DESCRIPTION"), fields = "Version")[1, 1])
  if (grepl("[.]9[0-9]{3,}$", version)) {
    refuse("DESCRIPTION has a development version (", version, ").")
  }
  if (!identical(sub("^cran-", "", branch), version)) {
    refuse("branch '", branch, "' does not match DESCRIPTION version ", version, ".")
  }

  cc_path <- file.path(path, "cran-comments.md")
  if (!file.exists(cc_path)) refuse("cran-comments.md is missing; CRAN would receive an empty comment.")
  comments <- paste(readLines(cc_path, warn = FALSE), collapse = "\n")
  if (!nzchar(trimws(comments))) refuse("cran-comments.md is empty.")
  # The exact version, not a substring: "8.0.0" must not match "18.0.0".
  version_rx <- paste0("(?<![0-9.])", gsub(".", "\\.", version, fixed = TRUE), "(?![0-9]|[.][0-9])")
  if (!grepl(version_rx, comments, perl = TRUE)) {
    refuse("cran-comments.md never mentions version ", version, "; is it current?")
  }

  cat(strrep("=", 72), "\n",
      "This is the EXACT comment CRAN will receive (all of cran-comments.md):\n",
      strrep("=", 72), "\n", comments, "\n", strrep("=", 72), "\n", sep = "")
  cat("Package ", version, " from ", path, "\nBranch ", branch, " at ", substr(head, 1, 8), "\n", sep = "")

  if (dry_run) {
    message("Dry run: every check passed. Nothing was submitted.")
    return(invisible(TRUE))
  }
  if (!interactive()) refuse("run this in an interactive R session; submit_cran() asks questions.")
  if (utils::menu(c("Yes, the comment above is complete and current", "No"),
                  title = "Submit with this comment?") != 1L) {
    message("Not submitted.")
    return(invisible(FALSE))
  }
  devtools::submit_cran(path)
}
