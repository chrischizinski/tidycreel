## Submission

tidycreel 7.0.0 — first CRAN submission.

## Test environments

- macOS 26.6.2 (local), R 4.6.1
- ubuntu-latest, macOS-latest, windows-latest (GitHub Actions), R release

## R CMD check results

0 errors | 0 warnings | 1 note

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Christopher Chizinski <cchizinski2@unl.edu>'

New submission
```

The note is the expected new-submission note. No other notes, warnings or
errors are raised.

An earlier run of this check also reported redirecting URLs
(`chrischizinski.github.io` -> `chrischizinski.com`), following a move of the
package website to a custom domain. Every affected reference has been updated
to the destination URL and re-verified as returning 200.

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

- Some examples are wrapped in `\dontrun{}` where they would require a database
  connection or a network endpoint that is not available on a check machine.
