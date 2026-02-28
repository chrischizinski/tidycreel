# Feature Research: R Package Deprecated Function Removal

**Domain:** R Package Maintenance - Deprecated Function Cleanup
**Researched:** 2026-01-27
**Confidence:** HIGH

## Feature Landscape

### Essential Tasks (Must Do for Removal to be Complete)

These tasks are non-negotiable. Missing any of these means the deprecation removal is incomplete or will break the package.

| Task | Why Required | Complexity | Notes |
|------|--------------|------------|-------|
| Remove deprecated function code from R/ | Functions must be physically removed from codebase | LOW | Remove `estimate_effort()`, `estimate_cpue()`, `estimate_harvest()` from R/estimators.R (lines 13-37) |
| Remove @export tags for deprecated functions | Prevents roxygen2 from adding functions to NAMESPACE | LOW | Already correctly done - no @export tags on deprecated stubs |
| Regenerate NAMESPACE with roxygen2 | Updates NAMESPACE to remove deprecated exports | LOW | `devtools::document()` or `roxygen2::roxygenise()` |
| Update NEWS.md | Documents breaking change for users | LOW | Add removal notice under current version |
| Verify no internal package usage | Ensure no other package code calls deprecated functions | MEDIUM | Grep codebase for `estimate_(effort\|cpue\|harvest)` calls |
| R CMD check passes | Validates package structure is sound | MEDIUM | Must run without ERRORS, minimize WARNINGS/NOTES |

### Verification Tasks (Ensure Nothing Broke)

These tasks validate that the removal didn't break existing functionality.

| Task | Why Important | Complexity | Notes |
|------|---------------|------------|-------|
| Run full test suite | Catches functionality regressions | LOW | `devtools::test()` or `testthat::test_dir("tests/testthat")` |
| Check vignettes build | Ensures documentation examples still work | MEDIUM | `devtools::build_vignettes()` |
| Verify documentation builds | Confirms no broken cross-references | LOW | `devtools::document()` should complete without errors |
| Test installation from source | Validates package can be installed cleanly | LOW | `devtools::install()` or `R CMD INSTALL` |
| NAMESPACE consistency check | Ensures exports match actual functions | LOW | Compare NAMESPACE exports to actual exported functions |
| Check for orphaned .Rd files | Documentation files without corresponding functions | LOW | Look in man/ for estimate_*.Rd files |

### Cleanup Tasks (Nice-to-Have Polish)

These improve code quality but aren't strictly required for the deprecation removal.

| Task | Value Proposition | Complexity | Notes |
|------|-------------------|------------|-------|
| Delete old_code/ directory | Removes cruft, reduces repository size | LOW | Contains 7 legacy .R files from original implementation |
| Remove unused helper functions | Simplifies codebase if `create_survey_design()` is orphaned | MEDIUM | Check if any code calls this helper after deprecated functions removed |
| Update README examples | Ensures users see current API patterns | LOW | Verify no examples use deprecated functions |
| Clean up .gitignore | Remove entries for deleted directories | LOW | Remove old_code/ entry if present |
| Update pkgdown reference | Organize function reference without deprecated items | LOW | Check _pkgdown.yml doesn't list deprecated functions |

## Task Dependencies

```
[Remove deprecated code]
    └──requires──> [Verify no internal usage]
                       └──requires──> [Regenerate NAMESPACE]
                                          └──requires──> [R CMD check]

[Update NEWS.md] ──parallel to──> [Remove deprecated code]

[Cleanup old_code/] ──independent of──> [Remove deprecated code]

[Test suite] ──after──> [Regenerate NAMESPACE]
[Vignettes build] ──after──> [Regenerate NAMESPACE]
```

### Dependency Notes

- **Must verify no internal usage BEFORE removing code:** If other package functions call the deprecated functions, they'll break. The grep search shows only the deprecated stubs themselves and one vignette mention (which is documentation, not code).
- **Regenerate NAMESPACE immediately after code removal:** This ensures the NAMESPACE is in sync with the code before running R CMD check.
- **R CMD check is the gate:** Nothing should be committed until R CMD check passes cleanly.
- **old_code/ cleanup is independent:** Can be done before, during, or after the main removal.

## Task Prioritization Matrix

| Task | User Value | Implementation Cost | Priority |
|------|------------|---------------------|----------|
| Remove deprecated code | HIGH | LOW | P1 |
| Verify no internal usage | HIGH | LOW | P1 |
| Regenerate NAMESPACE | HIGH | LOW | P1 |
| R CMD check passes | HIGH | MEDIUM | P1 |
| Update NEWS.md | HIGH | LOW | P1 |
| Run test suite | HIGH | LOW | P1 |
| Check vignettes build | MEDIUM | MEDIUM | P2 |
| Delete old_code/ | MEDIUM | LOW | P2 |
| Verify documentation builds | MEDIUM | LOW | P2 |
| Test installation | MEDIUM | LOW | P2 |
| NAMESPACE consistency | MEDIUM | LOW | P2 |
| Check orphaned .Rd files | LOW | LOW | P2 |
| Remove unused helpers | LOW | MEDIUM | P3 |
| Update README examples | MEDIUM | LOW | P3 |
| Clean .gitignore | LOW | LOW | P3 |
| Update pkgdown reference | LOW | LOW | P3 |

**Priority key:**
- P1: Must complete for removal (blocking)
- P2: Should complete for quality (recommended)
- P3: Nice to have for polish (optional)

## R Package Ecosystem Context

### Standard Deprecation Lifecycle (R Best Practice)

R packages typically follow a three-release cycle for deprecation:

1. **Deprecation Phase (Release N):** Function marked deprecated with `.Deprecated()`, warns but still works
2. **Defunct Phase (Release N+1):** Function marked defunct with `.Defunct()`, errors immediately
3. **Removal Phase (Release N+2):** Function completely removed from package

**tidycreel's status:** The deprecated functions already error (via `cli::cli_abort()`), indicating they're in the defunct phase. Complete removal is the next step.

### NAMESPACE Management

R uses the NAMESPACE file to control which functions are exported (user-visible) and imported (from dependencies). Modern R packages use roxygen2 to generate NAMESPACE automatically:

- `@export` tag: Adds function to NAMESPACE exports
- `@importFrom pkg function`: Adds import from dependency
- **Critical:** NAMESPACE must match actual code or R CMD check fails

**tidycreel's approach:** Uses roxygen2 (confirmed by RoxygenNote: 7.3.2 in DESCRIPTION). The deprecated function stubs have `@export` tags (lines 13, 22, 30 in R/estimators.R), so they're currently exported in NAMESPACE (lines 30-32). Removing the functions requires regenerating NAMESPACE.

### R CMD check Requirements

R CMD check validates package structure and catches common errors:

- **Undocumented exports:** Functions in NAMESPACE without .Rd files (ERROR)
- **Objects in NAMESPACE not in package:** Exports that don't exist (ERROR)
- **Unused imports:** Packages in DESCRIPTION not used in code (NOTE)
- **Missing cross-references:** Links to non-existent functions (WARNING)

**Relevant to removal:** Removing deprecated functions without regenerating NAMESPACE will cause "objects in NAMESPACE not in package" ERROR.

## Known Anti-Patterns

### Anti-Pattern 1: Remove Code But Not NAMESPACE Exports

**Why Problematic:** R CMD check will fail with "object 'estimate_effort' is not exported by 'namespace:tidycreel'" because NAMESPACE still lists the function but it doesn't exist.

**Instead:** Always regenerate NAMESPACE immediately after removing @export tags or function code.

### Anti-Pattern 2: Delete Functions Without Checking Internal Usage

**Why Problematic:** If other package code calls the deprecated functions (even internal calls), those will break at runtime.

**Instead:** Grep the entire codebase for usage before removal. For tidycreel, the grep results show no internal usage (only the deprecated stubs themselves and one vignette mention).

### Anti-Pattern 3: Skip Documentation Cleanup

**Why Problematic:** Orphaned .Rd files or broken cross-references cause R CMD check WARNINGS. Documentation can reference deprecated functions via `\link{}`.

**Instead:** Check man/ directory for estimate_*.Rd files and search all .Rd files for cross-references to removed functions.

### Anti-Pattern 4: Forget to Update NEWS.md

**Why Problematic:** Users upgrading the package have no record that functions were removed, leading to confusion and support burden.

**Instead:** Document the removal in NEWS.md with migration guidance (tidycreel's NEWS.md already has deprecation notice; needs removal notice).

## Project-Specific Findings

### Current State Analysis

**Deprecated functions in R/estimators.R:**
- `estimate_effort()` (lines 13-19): Error stub with migration message
- `estimate_cpue()` (lines 22-28): Error stub with migration message
- `estimate_harvest()` (lines 31-37): Error stub with migration message

**NAMESPACE exports (lines 30-32):**
```
export(estimate_cpue)
export(estimate_effort)
export(estimate_harvest)
```

**old_code/ directory:**
Contains 7 legacy files from pre-refactor implementation:
- CreelAnalysisFunctions.R (43k)
- CreelAnalysisFunctionsCJCEDits.R (57k)
- CreelApiHelper.R (5.1k)
- CreelConfigCheck.R (12k)
- CreelDataAccess.R (57k)
- CreelDataAccess_CJCedits.R (6.5k)
- CreelEnvSetup.R (6.9k)

**NEWS.md entry:** Already documents deprecation (lines 11-12): "estimate_effort(), estimate_cpue(), estimate_harvest() now error with guidance to the new APIs."

**Internal usage:** Grep found no internal calls to deprecated functions outside the deprecated stubs themselves. One vignette mention (survey_creel_terms.Rmd line 139) is in documentation context only.

### Tidycreel-Specific Tasks

| Task | Specific Action | Completion Criteria |
|------|-----------------|---------------------|
| Remove stubs | Delete lines 13-37 from R/estimators.R | Functions not present in file |
| Regenerate NAMESPACE | Run `devtools::document()` | NAMESPACE lines 30-32 removed |
| Update NEWS.md | Add "Complete removal of estimate_effort(), estimate_cpue(), estimate_harvest()" under current version | Entry present in NEWS.md |
| Delete old_code/ | `rm -rf old_code/` | Directory does not exist |
| Check vignette | Update survey_creel_terms.Rmd line 139 if needed | No references to removed functions |
| R CMD check | `devtools::check()` | 0 ERRORS, 0 WARNINGS |

## MVP Definition

### Must Complete (Atomic Commit)

The minimum viable removal - these must happen together in a single commit:

- [ ] Verify no internal usage (grep check)
- [ ] Remove deprecated function stubs from R/estimators.R
- [ ] Regenerate NAMESPACE via `devtools::document()`
- [ ] Update NEWS.md with removal notice
- [ ] R CMD check passes with 0 ERRORS, 0 WARNINGS
- [ ] Full test suite passes

### Should Add Immediately After (Same PR)

Polish tasks that complete the cleanup:

- [ ] Delete old_code/ directory
- [ ] Verify vignettes build successfully
- [ ] Check for orphaned .Rd files in man/

### Can Defer (Future Cleanup)

Nice-to-have improvements that don't block the removal:

- [ ] Remove `create_survey_design()` helper if unused
- [ ] Update README examples
- [ ] Clean .gitignore entries
- [ ] Update pkgdown reference organization

## Quality Gates

### Pre-Commit Checklist

Before committing the removal:

- [ ] Grep confirms no internal package code calls deprecated functions
- [ ] R/estimators.R no longer contains deprecated stubs
- [ ] `devtools::document()` completed successfully
- [ ] NAMESPACE regenerated (inspect file to confirm)
- [ ] NEWS.md updated with removal notice
- [ ] `devtools::test()` passes all tests
- [ ] `devtools::check()` shows 0 ERRORS, 0 WARNINGS
- [ ] Package installs successfully

### Post-Removal Validation

After committing, verify:

- [ ] Git status shows expected changed files (R/estimators.R, NAMESPACE, NEWS.md, old_code/ removed)
- [ ] Vignettes build without errors
- [ ] No orphaned .Rd files in man/
- [ ] Documentation builds cleanly

## Sources

### Official R Documentation (HIGH confidence)
- [Bioconductor Deprecation Guidelines](https://contributions.bioconductor.org/deprecation.html) - Standard three-release cycle
- [rOpenSci Package Evolution Guide](https://devguide.ropensci.org/maintenance_evolution.html) - When to remove deprecated functions
- [R Packages (2e): R CMD Check Appendix](https://r-pkgs.org/R-CMD-check.html) - Check requirements
- [Writing R Extensions Manual](https://cran.r-project.org/doc/manuals/r-release/R-exts.html) - Official NAMESPACE documentation

### Community Best Practices (MEDIUM confidence)
- [Posit Community: When to Remove Deprecated Functions](https://forum.posit.co/t/when-can-i-remove-a-deprecated-function-from-a-package/9707) - 18-month deprecation cycle discussion
- [lifecycle Package Documentation](https://lifecycle.r-lib.org/articles/communicate.html) - Modern deprecation workflows

### Roxygen2 Documentation (HIGH confidence)
- [roxygen2 Changelog](https://roxygen2.r-lib.org/news/index.html) - NAMESPACE regeneration improvements
- [Get Started with roxygen2](https://cran.r-project.org/web/packages/roxygen2/vignettes/roxygen2.html) - Documentation generation

---
*Feature research for: tidycreel deprecated function removal*
*Researched: 2026-01-27*
*Project-specific findings based on codebase inspection*
