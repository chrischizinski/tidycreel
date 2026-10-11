# Read CRAN's own check results for tidycreel and write a report.
#
#   Rscript scripts/cran-checks.R [report.md]
#
# Prints "problems=true" or "problems=false" as its last line (for
# $GITHUB_OUTPUT) and writes the report when there are problems.
#
# CRAN re-checks every package on its ~13 flavours as R-devel and the
# dependencies move. A failure there arrives as an email with a deadline,
# usually about two weeks, after which the package can be archived. Run weekly
# by .github/workflows/cran-checks.yaml so a deadline is an issue in the repo,
# not only a message in one inbox.

pkg <- Sys.getenv("CRAN_CHECKS_PACKAGE", "tidycreel")  # override only to test the report
report <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(report)) report <- "cran-checks-report.md"
options(repos = c(CRAN = "https://cloud.r-project.org"))

results <- tools::CRAN_check_results()
mine <- results[results$Package == pkg, c("Flavor", "Version", "Status"), drop = FALSE]
if (!nrow(mine)) stop(pkg, " has no CRAN check results; is it still on CRAN?")

bad <- mine[mine$Status != "OK", , drop = FALSE]

# "Additional issues" (sanitizers, M1mac, noSuggests, ...) are listed apart
# from the flavour table and can carry a deadline of their own.
issues <- tools::CRAN_check_issues()
issues <- issues[issues$Package == pkg, , drop = FALSE]

db <- tools::CRAN_package_db()
deadline <- db$Deadline[db$Package == pkg]
deadline <- if (length(deadline) && !is.na(deadline[1])) deadline[1] else NA

problems <- nrow(bad) > 0L || nrow(issues) > 0L || !is.na(deadline)

if (problems) {
  url <- sprintf("https://cran.r-project.org/web/checks/check_results_%s.html", pkg)
  lines <- c(
    sprintf("CRAN's check results for %s %s are not all OK.", pkg, mine$Version[1]),
    "",
    if (!is.na(deadline)) c(sprintf("**CRAN deadline: %s.** The package can be archived after it.", deadline), ""),
    sprintf("Full results: %s", url),
    ""
  )
  if (nrow(bad)) {
    lines <- c(lines, "| Flavour | Status |", "|---|---|",
               sprintf("| %s | %s |", bad$Flavor, bad$Status), "")
  }
  if (nrow(issues)) {
    lines <- c(lines, "Additional issues:", "",
               sprintf("- %s", apply(issues[, setdiff(names(issues), "Package"), drop = FALSE], 1,
                                     paste, collapse = " ")), "")
  }
  lines <- c(lines, "Opened by .github/workflows/cran-checks.yaml (weekly). It updates this issue while the problems last; close it once CRAN shows OK.")
  writeLines(lines, report)
  cat(lines, sep = "\n")
} else {
  cat(sprintf("%s %s: OK on all %d flavours, no additional issues, no deadline.\n",
              pkg, mine$Version[1], nrow(mine)))
}
cat(sprintf("problems=%s\n", tolower(problems)))
