## Resubmission

This is a resubmission of tidycreel 8.0.0, a new package.

The pretest on 2026-09-30 reported `Overall checktime 21 min > 10 min` on
r-devel-windows-x86_64, 14 min of it in tests. The tests now run a core subset
of 8 files (647 tests) covering the main workflow, unless `NOT_CRAN` is
`"true"`; the full suite (6,815 tests) still runs in GitHub Actions and
`devtools::test()`. Locally the test step fell from 203 s to 20 s. On
win-builder R-devel the overall check time is now 317 s (tests 65 s; win-builder, 2026-09-30).
No package code changed.

The earlier review of 7.0.0 asked for two changes, both made in 8.0.0:
commented-out code in examples is now executed code, and `print()` for the
`validate_incomplete_trips()` result restores `par()` with `on.exit()`. A test
guards both.

## Test environments

- local: macOS 26.6.2 (aarch64), R 4.6.1
- win-builder: R Under development (unstable) (2026-09-29 r90598 ucrt)
- GitHub Actions: ubuntu, macOS and Windows, R release

## R CMD check results

0 errors | 0 warnings | 1 note

* New submission.

  Possibly misspelled words in DESCRIPTION: Hoenig, Kinloch, McGlennon, Nicoll.
  These are author surnames from the two method references in `Description`,
  spelled as published.

## Notes

* The repository contains a companion package, `tidycreel.connect`, in a
  subdirectory. It is excluded via `.Rbuildignore`, is not part of this
  submission, and is deliberately absent from `Suggests`; the vignette that
  describes it sets `eval = FALSE` throughout.
* `inst/calamus-2016/` is a small (~32 KB) reference dataset from a completed
  2016 creel survey, used as the end-to-end validation fixture for the tests.
* One `\donttest{}` block wraps an lme4 bootstrap example, for runtime only.

## Reverse dependencies

There are no reverse dependencies; this is a new package.
