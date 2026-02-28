# Stack Research: R Package Legacy Code Removal

**Domain:** R package development - deprecated function removal
**Researched:** 2026-01-27
**Confidence:** HIGH

## Recommended Stack

### Core Development Tools

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| R | >= 4.1.0 | Base environment | Package DESCRIPTION requirement; stable API |
| roxygen2 | 7.3.2 | Documentation & NAMESPACE generation | Current stable; auto-regenerates NAMESPACE on document() |
| devtools | 2.4.5 | Development workflow | Current stable; provides check(), document(), load_all() |
| usethis | 3.1.0 | Workflow automation | Current stable; package setup and configuration |
| testthat | 3.3.2 | Unit testing framework | Latest (Jan 2026); ensures test coverage maintained |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| lifecycle | Latest (CRAN) | Deprecation lifecycle management | ONLY if backward compatibility needed (NOT for unreleased packages) |
| cli | Current | User-facing messages | Already in tidycreel Imports; use for informative errors |
| covr | Latest (CRAN) | Test coverage reporting | Verify test coverage unchanged after removal |
| rcmdcheck | Latest (CRAN) | Programmatic R CMD check | CI/CD workflows (optional for local dev) |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| RStudio | IDE with package support | Built-in shortcuts: Ctrl/Cmd+Shift+E (check), Ctrl/Cmd+Shift+T (test), Ctrl/Cmd+Shift+D (document) |
| git | Version control | For cleaning old_code/ directory and tracking deletions |
| R CMD check | Package validation | Gold standard; devtools::check() wraps this |

## Installation

```bash
# Core development tools (if not already installed)
R -e "install.packages(c('roxygen2', 'devtools', 'usethis', 'testthat', 'covr'))"

# lifecycle package - NOT needed for unreleased packages
# Only install if adding backward compatibility warnings to released packages
# R -e "install.packages('lifecycle')"
```

## Workflow Commands for Legacy Code Removal

### Phase 1: Pre-Removal Verification

```r
# 1. Check current package state
devtools::document()           # Regenerate docs and NAMESPACE
devtools::check()              # Baseline - should pass with 0 errors, 0 warnings
devtools::test()               # Baseline test coverage

# 2. Check test coverage before removal
covr::package_coverage()       # Record current coverage %
```

### Phase 2: Code Removal

**For unreleased packages (tidycreel's case):**
- SKIP lifecycle stages (deprecate_soft/warn/stop)
- Direct deletion is safe - no users to break
- Remove files, remove @export tags, regenerate NAMESPACE

```r
# Manual steps:
# 1. Delete R/zzz-compat-stubs.R (or remove deprecated functions from it)
# 2. Remove estimate_effort(), estimate_cpue(), estimate_harvest() from R/estimators.R
# 3. Remove @export tags for deprecated functions
# 4. Delete old_code/ directory: unlink("old_code", recursive = TRUE)

# Then regenerate:
devtools::document()           # Removes exports from NAMESPACE
```

### Phase 3: NAMESPACE Cleanup

roxygen2 automatically cleans NAMESPACE when you run `document()`:
- Removes `export()` directives for deleted functions
- Removes unused `importFrom()` statements
- **Caveat:** Only removes what's no longer in @export tags

**Manual NAMESPACE edits are NEVER needed** - roxygen2 manages it completely.

```r
# Verify NAMESPACE is clean
devtools::document()           # Should remove deprecated function exports

# Check for orphaned exports (should be none)
# All exports in NAMESPACE should match @export tags in R/
```

### Phase 4: Verification

```r
# 1. Check package builds and passes R CMD check
devtools::check()              # MUST pass with 0 errors, 0 warnings

# 2. Verify test coverage unchanged
covr::package_coverage()       # Should match or exceed pre-removal coverage

# 3. Test examples still work
devtools::run_examples()       # All examples should run without error

# 4. Build package successfully
devtools::build()              # Creates tar.gz bundle
```

### Phase 5: Git Cleanup

```bash
# Preview what will be removed
git clean -n -d                # Dry run - shows what would be deleted

# Remove old_code/ from git tracking
git rm -r old_code/
git commit -m "Remove legacy code directory"

# Commit function removals
git add R/zzz-compat-stubs.R R/estimators.R NAMESPACE
git commit -m "Remove deprecated estimate_* function stubs

- Remove estimate_effort(), estimate_cpue(), estimate_harvest()
- Remove legacy compatibility stubs
- Regenerate NAMESPACE to remove deprecated exports

Package was never released, so no backward compatibility concerns.
"
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Direct deletion (unreleased) | lifecycle::deprecate_*() | **Only for released packages** - tidycreel is unreleased (0.0.0.9000) |
| roxygen2 NAMESPACE management | Manual NAMESPACE edits | **Never** - manual edits are overwritten by document() |
| devtools::check() | R CMD check directly | When scripting CI/CD; devtools::check() is better for interactive use |
| git rm | Manual file deletion | git rm ensures Git tracks the deletion; manual deletion leaves untracked files |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| lifecycle package | Adds complexity; only needed for released packages with users | Direct deletion for unreleased packages |
| .Deprecated() / .Defunct() | Base R approach; less informative than cli::cli_abort() | Already using cli_abort() in stubs - just delete them |
| Manual NAMESPACE edits | Overwritten by roxygen2::roxygenize() | Let roxygen2 manage NAMESPACE via @export tags |
| Keeping stubs "just in case" | Technical debt; confuses API surface | Delete completely; Git preserves history if needed |

## Stack Patterns by Scenario

### Scenario A: Unreleased Package (tidycreel's case)

**Status:** Version 0.0.0.9000, never on CRAN, no external users

**Approach:**
- Direct deletion of deprecated functions
- No lifecycle warnings needed
- Clean break to new API

**Workflow:**
1. Delete deprecated function code
2. Remove @export tags
3. Run `devtools::document()` to regenerate NAMESPACE
4. Run `devtools::check()` to verify
5. Commit changes

**Rationale:** No backward compatibility burden. Clean API is more valuable than gradual deprecation.

### Scenario B: Released Package with Users

**Status:** Published to CRAN, external users depend on functions

**Approach:**
- Three-stage deprecation (soft → warn → stop → remove)
- Use lifecycle package
- Minimum 18 months (3 release cycles) before removal

**Workflow:**
1. Stage 1 (Release N): Add `lifecycle::deprecate_soft()` with replacement guidance
2. Stage 2 (Release N+1): Change to `lifecycle::deprecate_warn()`
3. Stage 3 (Release N+2): Change to `lifecycle::deprecate_stop()`
4. Stage 4 (Release N+3): Delete function, remove from NAMESPACE

**Rationale:** Gives users time to migrate. Prevents breaking existing code.

### Scenario C: Internal Package (Organization-Scoped)

**Status:** Not on CRAN, but used by other internal projects

**Approach:**
- Coordinate with internal users
- Shorter deprecation timeline (1-2 releases)
- Use lifecycle for visibility, but accelerate removal

**Workflow:**
1. Communicate breaking changes to internal users
2. Add `lifecycle::deprecate_warn()` in one release
3. Remove in next release after confirming no internal usage

**Rationale:** Faster iteration than public packages, but still protect internal consumers.

## Version Compatibility

| Package | Requires | Compatible With | Notes |
|---------|----------|-----------------|-------|
| roxygen2 7.3.2 | R >= 3.6 | devtools 2.4.5, usethis 3.1.0 | Current stable; no breaking changes since 7.0 |
| devtools 2.4.5 | R >= 3.6 | roxygen2 >= 7.0, testthat >= 3.0 | Uncoupled into smaller packages; stable API |
| testthat 3.3.2 | R >= 3.6 | devtools 2.4.5 | Edition 3 (breaking changes from Edition 2, but stable since 3.0) |
| usethis 3.1.0 | R >= 3.6 | devtools >= 2.4 | Workflow automation; stable |

**Critical Compatibility Notes:**
- roxygen2 7.x auto-cleans NAMESPACE (removes old exports) - this is desired behavior
- testthat Edition 3 (set in DESCRIPTION: `Config/testthat/edition: 3`) - tidycreel already uses this
- devtools 2.4+ delegates to specialized packages (roxygen2, testthat, rcmdcheck) - transparent to users

## Verification Checklist for Legacy Code Removal

Before committing removals, verify:

- [ ] `devtools::check()` passes (0 errors, 0 warnings, minimal NOTEs)
- [ ] `devtools::test()` passes (all tests green)
- [ ] `covr::package_coverage()` unchanged or improved
- [ ] `devtools::run_examples()` passes (all examples work)
- [ ] NAMESPACE contains no exports for removed functions
- [ ] No orphaned .Rd files in man/ for removed functions
- [ ] Git tracks deletion (use `git rm` not manual deletion)
- [ ] No references to removed functions in vignettes
- [ ] No references to removed functions in tests
- [ ] README/vignettes updated to remove old API examples

**Automated check script:**
```r
# Run this script to verify clean removal
check_removal <- function() {
  message("1. Documenting...")
  devtools::document()

  message("2. Checking package...")
  check_result <- devtools::check(quiet = TRUE)

  message("3. Running tests...")
  test_result <- devtools::test(quiet = TRUE)

  message("4. Checking coverage...")
  cov <- covr::package_coverage()

  list(
    check = check_result,
    tests = test_result,
    coverage = cov
  )
}
```

## Sources

**HIGH Confidence (Official Documentation & Current Versions):**
- [Tools to Make Developing R Packages Easier - devtools](https://devtools.r-lib.org/)
- [Build and check a package - devtools::check()](https://devtools.r-lib.org/reference/check.html)
- [R Packages (2e) - Fundamental development workflows](https://r-pkgs.org/workflow101.html)
- [Managing imports and exports - roxygen2 NAMESPACE](https://roxygen2.r-lib.org/articles/namespace.html)
- [Changelog - roxygen2](https://roxygen2.r-lib.org/news/index.html)
- [Package 'testthat' - January 11, 2026 Version 3.3.2](https://cran.r-project.org/web/packages/testthat/testthat.pdf)
- [Execute testthat tests in a package - devtools::test()](https://devtools.r-lib.org/reference/test.html)

**MEDIUM Confidence (Community Best Practices, Verified):**
- [Chapter 25 Deprecation Guidelines - Bioconductor](https://contributions.bioconductor.org/deprecation.html)
- [When can I remove a deprecated function from a package? - Posit Community](https://forum.posit.co/t/when-can-i-remove-a-deprecated-function-from-a-package/9707)
- [Package evolution - changing stuff in your package - rOpenSci](https://devguide.ropensci.org/maintenance_evolution.html)
- [Communicate lifecycle changes in your functions - lifecycle package](https://lifecycle.r-lib.org/articles/communicate.html)
- [21 Lifecycle - R Packages (2e)](https://r-pkgs.org/lifecycle.html)

**Tool Versions (Verified via installed packages):**
- roxygen2: 7.3.2 (current)
- devtools: 2.4.5 (current)
- usethis: 3.1.0 (current)
- testthat: 3.3.2 (January 2026 release)

---
*Stack research for: R Package Legacy Code Removal (tidycreel)*
*Researched: 2026-01-27*
*Confidence: HIGH - All tools verified current, workflow tested in R ecosystem*
