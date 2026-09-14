## Submission

tidycreel 7.0.0 — first CRAN submission.

## Test environments

- macOS Tahoe 26.6.2, aarch64-apple-darwin25.4.0 (local), R 4.6.1 (2026-06-24)
- win-builder, R Under development (unstable) (2026-09-13 r90534 ucrt),
  x86_64-w64-mingw32, Windows Server 2022 x64
- ubuntu-latest, macOS-latest, windows-latest (GitHub Actions), R release

## R CMD check results

win-builder (R-devel): 0 errors | 0 warnings | 1 note

Local (`R CMD check --as-cran`, reference manual enabled): 0 errors | 0 warnings
| 2 notes. The second local note is `Skipping checking HTML validation: 'tidy'
doesn't look like recent enough HTML Tidy`, which reflects the HTML Tidy version
on the local machine rather than anything in the package; win-builder reports
`checking HTML version of manual ... OK`.

The remaining note is the CRAN incoming feasibility note, and contains three
things:

```
Maintainer: 'Christopher Chizinski <cchizinski2@unl.edu>'

New submission

Possibly misspelled words in DESCRIPTION:
  Hoenig (13:50)
  Kinloch (15:5)
  McGlennon (15:14)
  Nicoll (15:25)

Found the following (possibly) invalid URLs:
  URL: https://chrischizinski.com/tidycreel/
  URL: https://chrischizinski.com/tidycreel/articles/
    Status: Error
    Message: SSL connect error [chrischizinski.com]:
      Recv failure: Connection was reset
```

**New submission** is expected.

**The four flagged words are author surnames**, from the method references in
`Description`: Hoenig (Hoenig, Jones, Pollock, Robson and Wade 1997) and
Kinloch, McGlennon and Nicoll (Kinloch, McGlennon, Nicoll and Pike 1997). They
are spelled as published.

**The two URLs are reachable and correct.** Both return HTTP 200 from the
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
  pass only, reporting 49s for all 125 example topics together.
