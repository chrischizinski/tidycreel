# 🧭 R Package GitHub Review & CI Guide

This document provides a **GitHub-first code review framework** for R packages.
It emphasizes **API stability, correctness, testing, and documentation** for packages distributed via **GitHub (not CRAN)**.

---

## 🧩 1. Review Prompt (for AI or human reviewers)

> **Review this git diff for an R package, prioritizing GitHub delivery. Focus on:**
>
> 1. **Behavioral changes (user-visible):**
>    - Messages via `cli`, errors via `rlang::abort()`.
>    - Return types stable (`tibble` vs `data.frame`), attributes preserved.
>    - No unexpected side effects (options, RNG, locale, working dir, connections). Use `withr::` guards and `on.exit()`.
>
> 2. **API/contracts:**
>    - Function signatures and defaults consistent (including `...`).
>    - S3/S4/R6/Rcpp compatibility; stable classes.
>    - Deprecations noted in `lifecycle` (no CRAN policy needed).
>
> 3. **Edge cases:**
>    - Handles length-0/1, recycling, NA/NaN/Inf/NULL, factors vs character, UTF-8, `Date`/`POSIXct` + TZ.
>    - Tidy-eval safety (`{{ }}`, quosures).
>    - File paths portable (`normalizePath()`, `tempfile()`).
>
> 4. **Potential bugs/perf:**
>    - Avoid accidental copies (copy-on-modify).
>    - Use preallocation.
>    - `data.table` by-reference (`:=`) vs unintended copies.
>    - Parallel code portable (PSOCK on Windows).
>    - Numeric tolerances appropriate.
>
> 5. **Data flow & state:**
>    - Invariants (classes/attributes) preserved.
>    - `.onLoad`/`.onAttach` do not mutate user state.
>    - Options/env vars namespaced.
>
> 6. **Testing gaps:**
>    - Add/adjust tests for 0/1/NA/factors/TZ/locale/encoding.
>    - Snapshot outputs (CLI, printing).
>    - Error class assertions.
>    - Optional `vdiffr` for plots.
>
> 7. **Docs for GitHub users:**
>    - `roxygen2` docs complete (`@param/@return/@examples/@export`).
>    - `NAMESPACE` regenerated.
>    - **README install section** (`pak`, `remotes`) current.
>    - `NEWS.md` for tag changes.
>    - `pkgdown` builds.
>
> 8. **Repo hygiene:**
>    - Minimal `DESCRIPTION`.
>    - CI green across OSes.
>    - Lints (`lintr`, `styler`) pass.

---

## 🧱 2. Pull Request Template

```md
## Purpose
<!-- One-liner + linked issue -->

## Summary
- [ ] User-visible behavior unchanged OR documented in README/NEWS
- [ ] API changes? If yes: deprecation note + lifecycle tag added

## R Package Review (GitHub focus)
**Behavior**
- [ ] Messages via `cli`; errors via `rlang::abort()`
- [ ] Return type/class stable; attributes preserved
- [ ] No unexpected side effects (options/RNG/locale/wd); guarded by `withr`/`on.exit`

**API / Contracts**
- [ ] Signatures & defaults compatible (incl. `...`)
- [ ] S3/S4/R6 stable; methods registered
- [ ] Rcpp/C: exported symbols consistent; `.Call` args/types OK; PROTECT/UNPROTECT balanced

**Edge Cases**
- [ ] Handles length-0/1, NA/NaN/Inf/NULL, factors/UTF-8, `Date`/`POSIXct`+TZ
- [ ] Tidy-eval safe (`{{ }}`, quosures); explicit name repair
- [ ] Portable file paths; temp files via `tempfile()`

**Perf / Parallel**
- [ ] Avoid accidental copies; preallocate
- [ ] `data.table` by-ref (`:=`) intended; keys/index explicit
- [ ] Parallel portable (PSOCK on Windows); RNG streams controlled

**Tests**
- [ ] Added/updated tests for edge cases above
- [ ] Snapshot/printing tests stable; error classes asserted
- [ ] Plot snapshots via `vdiffr` if applicable

**Docs**
- [ ] roxygen updated (`@param/@return/@examples/@export`)
- [ ] README install instructions updated
- [ ] NEWS.md entry for user-visible changes
- [ ] pkgdown reference doesn’t break

**CI**
- [ ] `devtools::check()` ok
- [ ] GH Actions green (Linux/macOS/Windows)
- [ ] `lintr`/`styler` clean

## Notes
<!-- Gotchas, performance notes, follow-ups -->
```

---

## ⚙️ 3. CI: R-CMD-check Workflow

```yaml
# .github/workflows/check.yaml
name: R-CMD-check
on: [push, pull_request]
jobs:
  check:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        r: ['release']
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
        with: { r-version: ${{ matrix.r }} }
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: |
            any::rcmdcheck
            any::testthat
            any::lintr
            any::styler
          needs: check
      - name: Lint
        run: Rscript -e "lintr::lint_package()"
      - name: Style (dry-run)
        run: Rscript -e "styler::style_dir(dry = TRUE)"
      - name: Check
        env:
          _R_CHECK_FORCE_SUGGESTS_: false
          R_DEFAULT_INTERNET_TIMEOUT: 20
          LC_ALL: C.UTF-8
        run: Rscript -e "rcmdcheck::rcmdcheck(error_on='warning', check_dir='check')"
      - name: Upload check results on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with: { name: r-cmd-check-results, path: check }
```

---

## 🌐 4. pkgdown to GitHub Pages

```yaml
# .github/workflows/pkgdown.yaml
name: pkgdown
on:
  push:
    branches: [main]
jobs:
  pkgdown:
    runs-on: ubuntu-latest
    permissions: { contents: write, pages: write, id-token: write }
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
        with: { extra-packages: any::pkgdown, needs: website }
      - name: Build site
        run: Rscript -e "pkgdown::build_site_github_pages(new_process=FALSE, install=TRUE)"
      - name: Deploy to gh-pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs
```

---

## 🚀 5. GitHub Release (Tag-Driven)

```yaml
# .github/workflows/release.yaml
name: Release
on:
  push:
    tags: ['v*.*.*']
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
      - name: Build source tarball
        run: R CMD build .
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: '*.tar.gz'
          generate_release_notes: true
```

---

## 📦 6. README Install Example

```r
# install.packages("pak") # if needed
pak::pak("your-org/yourpkg")        # main branch
# or pinned tag:
pak::pak("your-org/yourpkg@v1.2.3")

# remotes alternative:
# remotes::install_github("your-org/yourpkg")
```

---

## 🧹 7. Repo Hygiene Notes

- **Badges:** GitHub Actions (check), pkgdown site, optional coverage badge.
- **Code style:** Use `lintr` and `styler`; consider pre-commit hooks.
- **Versioning:** Semantic tags (`vX.Y.Z`) power releases and NEWS.
- **Dependencies:** Keep `Imports` minimal; heavy optional packages in `Suggests`.
- **Windows note:** If using Rcpp, mention RTools link in README.

---

✅ **Purpose:** Encourage clean, well-tested, documented, and GitHub-ready R packages with stable APIs and reproducible builds.
