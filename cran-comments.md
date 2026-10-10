## Submission

This is a patch release, 8.0.1, submitted shortly after 8.0.0 was published
(2026-10-10) because it fixes estimates that were wrong.

For aerial survey designs, `estimate_total_catch()`, `estimate_total_harvest()`
and `estimate_total_release()` multiplied the catch rate by the raw
instantaneous count instead of by effort in angler-hours, so every aerial total
was too small by `h_open * angler_ratio / visibility_correction` (a factor of 14
on the package's example data). `estimate_effort(by = )` on an aerial design
also ignored `by`. Both are fixed, with tests that fail on 8.0.0. Nothing else
changed.

## Test environments

- local: macOS 26.6.2 (aarch64), R 4.6.1
- win-builder: R-devel (to be run before submission)
- GitHub Actions: ubuntu, macOS and Windows, R release

## R CMD check results

0 errors | 0 warnings | 1 note

* Days since last update: 0. This patch fixes wrong aerial-survey totals in
  8.0.0; see above.

## Notes

* The repository contains a companion package, `tidycreel.connect`, in a
  subdirectory. It is excluded via `.Rbuildignore`, is not part of this
  submission, and is deliberately absent from `Suggests`; the vignette that
  describes it sets `eval = FALSE` throughout.
* `inst/calamus-2016/` is a small (~32 KB) reference dataset from a completed
  2016 creel survey, used as the end-to-end validation fixture for the tests.
* One `\donttest{}` block wraps an lme4 bootstrap example, for runtime only.

## Reverse dependencies

There are no reverse dependencies.
