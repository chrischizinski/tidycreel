# R Package GitHub Review Prompt

> **Review this git diff for an R package, prioritizing GitHub delivery.
> Focus on:**
>
> 1.  **Behavioral changes (user-visible):**
>     - Messages via `cli`, errors via
>       [`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html).
>     - Return types stable (`tibble` vs `data.frame`), attributes
>       preserved.
>     - No unexpected side effects (options, RNG, locale, working dir,
>       connections). Use `withr::` guards and
>       [`on.exit()`](https://rdrr.io/r/base/on.exit.html).
> 2.  **API/contracts:**
>     - Function signatures and defaults consistent (including `...`).
>     - S3/S4/R6/Rcpp compatibility; stable classes.
>     - Deprecations noted in `lifecycle` (no CRAN policy needed).
> 3.  **Edge cases:**
>     - Handles length-0/1, recycling, NA/NaN/Inf/NULL, factors vs
>       character, UTF-8, `Date`/`POSIXct` + TZ.
>     - Tidy-eval safety (`{{ }}`, quosures).
>     - File paths portable
>       ([`normalizePath()`](https://rdrr.io/r/base/normalizePath.html),
>       [`tempfile()`](https://rdrr.io/r/base/tempfile.html)).
> 4.  **Potential bugs/perf:**
>     - Avoid accidental copies (copy-on-modify).
>     - Use preallocation.
>     - `data.table` by-reference (`:=`) vs unintended copies.
>     - Parallel code portable (PSOCK on Windows).
>     - Numeric tolerances appropriate.
> 5.  **Data flow & state:**
>     - Invariants (classes/attributes) preserved.
>     - `.onLoad`/`.onAttach` do not mutate user state.
>     - Options/env vars namespaced.
> 6.  **Testing gaps:**
>     - Add/adjust tests for 0/1/NA/factors/TZ/locale/encoding.
>     - Snapshot outputs (CLI, printing).
>     - Error class assertions.
>     - Optional `vdiffr` for plots.
> 7.  **Docs for GitHub users:**
>     - `roxygen2` docs complete (`@param/@return/@examples/@export`).
>     - `NAMESPACE` regenerated.
>     - **README install section** (`pak`, `remotes`) current.
>     - `NEWS.md` for tag changes.
>     - `pkgdown` builds.
> 8.  **Repo hygiene:**
>     - Minimal `DESCRIPTION`.
>     - CI green across OSes.
>     - Lints (`lintr`, `styler`) pass.
