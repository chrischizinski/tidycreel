## Resubmission (check time)

The pretest of 8.0.0 on 2026-09-30 reported `Overall checktime 21 min > 10 min`
on r-devel-windows-x86_64, mainly from `checking tests ... [14m]`.

The tests now run a core subset unless the `NOT_CRAN` environment variable is
`"true"`. The subset is 8 test files (647 tests) covering the main workflow:
design construction, counts, interviews, effort, catch rate and total catch,
plus the CRAN policy guard. Locally the test step fell from 203 s to 20 s
under `R CMD check --as-cran`, about a 90% reduction. The full suite (6,815
tests) still runs on every push in GitHub Actions and in `devtools::test()`,
both of which set `NOT_CRAN=true`. A test fails if any name in the subset stops
matching a test file, so the subset cannot silently shrink.

No package code changed; only `tests/testthat.R`, one new test file and the CI
workflows. The version stays 8.0.0 because 8.0.0 was not published.

## Resubmission

This is a resubmission of tidycreel, first submitted as 7.0.0 on 2026-09-14.
The version is now 8.0.0 rather than 7.0.1 because the development changes
merged since 7.0.0 include a breaking change (`estimate_effort_aerial_glmm()`
now reports a total across sampled days rather than a single-day mean, see
NEWS), and the package follows semantic versioning. tidycreel has not been
published on CRAN, so no CRAN user sees the jump.

The review of 7.0.0 asked for two changes, both made:

- **Commented-out code in examples.** Ten commented-out lines across four help
  pages (`estimate_harvest_rate`, `estimate_total_catch`,
  `estimate_total_harvest`, `get_site_contributions`) are now executed code.
  `get_site_contributions()` had no runnable example at all and now has one
  built on a small bus-route design; the note below that every exported
  function has a runnable example was not true of the previous submission and
  is true now.
- **Changing the user's `par()` / `options()`.** `print()` for the
  `validate_incomplete_trips()` result set `par(mar = ...)` without restoring
  it; it now saves the old value and calls `on.exit()` on the next line. The
  `validate_incomplete_trips()` example, and a vignette chunk, set an option
  and now restore it with `old <- options(...)` / `options(old)`. The package
  never calls `setwd()`.

A test now scans every example for commented-out code and every function for
`par()`, `options()`, `setwd()`, `Sys.setenv()` or `Sys.setlocale()` calls not
followed by `on.exit()`, so neither can recur unnoticed.

## Submission

tidycreel 8.0.0 — first CRAN release (resubmission of 7.0.0).

## Test environments

- macOS Tahoe 26.6.2, aarch64-apple-darwin25.4.0 (local), R 4.6.1 (2026-06-24)
- win-builder, R Under development (unstable) (2026-09-25 r90590 ucrt),
  x86_64-w64-mingw32
- ubuntu-latest, macOS-latest, windows-latest (GitHub Actions), R release

## R CMD check results

win-builder (R-devel): 0 errors | 0 warnings | 1 note

Local (`R CMD check --as-cran`, reference manual enabled): 0 errors | 0 warnings
| 2 notes. The second local note is `Skipping checking HTML validation: 'tidy'
doesn't look like recent enough HTML Tidy`, which reflects the HTML Tidy version
on the local machine rather than anything in the package; win-builder reports
`checking HTML version of manual ... OK`.

The remaining note is the CRAN incoming feasibility note. On this submission's
win-builder run it contains two things:

```
Maintainer: 'Christopher Chizinski <cchizinski2@unl.edu>'

New submission

Possibly misspelled words in DESCRIPTION:
  Hoenig (13:50)
  Kinloch (15:5)
  McGlennon (15:14)
  Nicoll (15:25)
```

**New submission** is expected.

**The four flagged words are author surnames**, from the method references in
`Description`: Hoenig (Hoenig, Jones, Pollock, Robson and Wade 1997) and
Kinloch, McGlennon and Nicoll (Kinloch, McGlennon, Nicoll and Pike 1997). They
are spelled as published.

**No URLs are flagged on this run.** The 7.0.0 win-builder run flagged two, the
package site `https://chrischizinski.com/tidycreel/` and its article index,
with `SSL connect error ... Connection was reset`; the explanation is kept in
case the note recurs.
The two URLs are reachable and correct. Both return HTTP 200 from the
maintainer's network over TLS 1.2 and TLS 1.3, with a valid Let's Encrypt
certificate and a plain libcurl user agent, and `R CMD check --as-cran` run
locally raises no URL complaint at all. The host is GitHub Pages serving a
custom domain, and the connection reset appears specific to the network path
between the win-builder machine and that host: every request from win-builder
failed, including the first, rather than degrading part way through as
rate-limiting would.

An earlier run of this check reported the same error for 25 URLs on that host.
The README previously linked each published article page individually; because
those vignettes ship in the tarball, it now names them as `vignette()` calls
instead, which work from an installed package without a network. What remains is
the package URL in `DESCRIPTION` and a single link to the article index.

`urlchecker::url_check()` additionally reports errors on four publisher DOI
links in vignettes and NEWS — `10.1002/nafm.10010`, `10.1002/nafm.10038` and
`10.1139/f58-003` return 403, and `10.1590/S1519-69842010005000010` returns 502.
These are anti-bot responses from the publishers rather than broken links: all
four DOIs resolve through the Crossref API to the expected articles, and
`R CMD check --as-cran` does not flag them.

## Notes for the reviewer

- The repository contains a companion package, `tidycreel.connect`, in a
  subdirectory. It is excluded from the build via `.Rbuildignore` and is not
  part of this submission; no file from it appears in the tarball. The vignette
  `tidycreel-connect.Rmd` describes that package for users who need database
  and API ingestion, but sets `eval = FALSE` throughout and never loads it, so
  it builds without the package present. `tidycreel.connect` is therefore
  deliberately absent from `Suggests`.

- `inst/calamus-2016/` contains a small (~32 KB) reference dataset from a
  completed 2016 creel survey, used as the package's end-to-end validation
  fixture. It is the basis of the numbers asserted in the test suite.

- Every exported function has a runnable example and nothing is wrapped in
  `\dontrun{}`. Examples that need a suggested package are guarded with
  `@examplesIf rlang::is_installed(...)` (`estimate_effort_aerial_glmm()` needs
  lme4; `summarize_by_county()` needs zipcodeR), and one dataset help page
  guards a GLMM workflow the same way. A single `\donttest{}` block wraps an
  lme4 bootstrap in `estimate_effort_aerial_glmm()`, purely for runtime; it
  needs no resource the example cannot reach. It is exercised locally, where
  `R CMD check --as-cran` runs both passes — `checking examples` in 19s and
  `checking examples with --run-donttest` in 21s. win-builder runs the ordinary
  pass only, reporting 55s for all 125 example topics together.
