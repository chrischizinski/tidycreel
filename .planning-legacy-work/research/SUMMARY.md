# Research Summary: Safe Legacy Code Removal from tidycreel

**Domain:** R Package Maintenance - Deprecated Function and Archive Removal
**Researched:** 2026-01-27
**Overall confidence:** HIGH

## Executive Summary

Safe code removal from R packages follows a **phased, checkpoint-driven approach** to prevent breakage. The tidycreel package contains three deprecated function stubs (`estimate_effort()`, `estimate_cpue()`, `estimate_harvest()`) in `R/estimators.R` that need removal, plus ~187k lines of archived code in `old_code/` directory. The package was never publicly released, eliminating backward compatibility concerns and allowing clean removal without deprecation warnings.

Research reveals that R package code removal follows a dependency-ordered sequence: remove NAMESPACE exports first (making functions internal-only), then remove function definitions, then remove archived code, and finally update documentation. Each phase requires mandatory verification via R CMD check and the test suite before proceeding. This "progressive restriction" pattern allows easy rollback if issues are discovered, since each phase is independently verifiable.

The key architectural insight is that **code removal is the inverse of code addition**: just as you would build a feature incrementally with tests at each step, you remove code incrementally with verification at each step. The tidycreel package's strong test coverage (testthat edition 3) and architectural compliance tests provide excellent safety nets for this removal work.

## Key Findings

**Stack:** R package development tools (roxygen2, devtools, testthat) provide built-in support for safe code removal through NAMESPACE auto-generation and comprehensive checking.

**Architecture:** Four-phase removal sequence (NAMESPACE exports → Function stubs → Archived code → Documentation) with mandatory checkpoints prevents cascading breakage.

**Critical pitfall:** Skipping checkpoints between phases makes it impossible to isolate the cause of breakage, forcing either time-consuming debugging or complete rollback.

## Implications for Roadmap

Based on research, suggested phase structure:

### 1. **Phase 1: Remove NAMESPACE Exports** (Low Risk)
   - Addresses: Making deprecated functions internal-only
   - Avoids: Breaking tests or user code (functions still exist, just not exported)
   - **Verification:** R CMD check + test suite
   - **Rollback:** Simple (re-add `@export` tags, regenerate NAMESPACE)
   - **Duration:** ~30 minutes

### 2. **Phase 2: Remove Function Stubs** (Medium Risk)
   - Addresses: Deleting deprecated function definitions from R/estimators.R
   - Avoids: Breaking internal code or tests that reference these functions
   - **Verification:** R CMD check + test suite + search for references
   - **Rollback:** Moderate (restore file from git)
   - **Duration:** ~1 hour (includes thorough reference checking)

### 3. **Phase 3: Remove Archived Code** (Low Risk)
   - Addresses: Deleting old_code/ directory (~187k lines)
   - Avoids: Breaking documentation references to archived examples
   - **Verification:** R CMD check + search for doc references
   - **Rollback:** Simple (restore directory from git)
   - **Duration:** ~30 minutes

### 4. **Phase 4: Update Documentation** (Low Risk)
   - Addresses: Cleaning NEWS.md, README, vignettes
   - Avoids: Documenting code that might need rollback
   - **Verification:** R CMD check --as-cran + vignette build
   - **Rollback:** Simple (restore docs from git)
   - **Duration:** ~1 hour

### Phase Ordering Rationale

**Why exports before functions:**
- Removing exports first prevents new usage while keeping functions available for debugging
- If Phase 2 breaks something, you can rollback to Phase 1 state (internal functions) rather than starting over
- Aligns with "progressive restriction" pattern from research

**Why archived code before documentation:**
- Archived code removal is independent of current code (can't break package)
- Doing it before documentation allows documentation to reflect final state
- If doc updates reference archived code, easier to see the dependency

**Why documentation last:**
- Code changes must be verified stable before documenting them
- Avoids documenting changes that get rolled back
- Allows NEWS.md to accurately summarize all changes in one entry

## Research Flags for Phases

### Phase 1: Standard Removal (No Research Needed)
- roxygen2 export removal is well-documented
- Process is: remove `@export` tags → run `devtools::document()`
- Unlikely to encounter issues

### Phase 2: Needs Reference Checking (Minimal Research)
- Must verify no tests/vignettes call deprecated functions
- Search pattern: `grep -r "estimate_effort\|estimate_cpue\|estimate_harvest" tests/ vignettes/`
- If found: Update to current API or delete obsolete tests
- Unlikely to need deeper research unless unexpected references found

### Phase 3: Standard Removal (No Research Needed)
- Directory deletion is straightforward
- Git history preserves archived code
- Unlikely to encounter issues

### Phase 4: Standard Documentation (No Research Needed)
- Update NEWS.md, verify README/vignettes
- Standard package maintenance task
- Unlikely to encounter issues

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Removal Sequence | HIGH | Based on official R package documentation and CRAN best practices |
| Verification Checkpoints | HIGH | R CMD check and testthat are standard tools with clear success criteria |
| Rollback Strategies | HIGH | Git provides clear restoration points for each phase |
| tidycreel-Specific Impact | HIGH | Deprecated stubs clearly identified in R/estimators.R, no complex dependencies |

## Critical Success Factors

### What Makes This Removal Safe

1. **Package never released:** No external users to break, no backward compatibility concerns
2. **Clear migration path:** New API (`est_*` functions) already exists and is documented
3. **Comprehensive tests:** Test suite will catch breakage immediately
4. **Architectural compliance tests:** Verify core patterns remain intact
5. **Strong git discipline:** Each phase can be committed independently with clear rollback points

### What Could Go Wrong (and Mitigations)

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Tests reference deprecated functions | Medium | Medium | Pre-check with grep, update tests to current API |
| Vignettes use deprecated examples | Low | Medium | Pre-check with grep, update vignettes to current API |
| Internal code calls deprecated functions | Very Low | High | Pre-check with grep, should be caught by Phase 1 tests |
| Documentation has broken links | Low | Low | Check during Phase 3, update in Phase 4 |

## Gaps to Address

### Identified During Research

1. **Test coverage of deprecated functions:** Need to verify if any tests specifically validate deprecated function behavior
   - **Action:** Run `grep -r "estimate_effort\|estimate_cpue\|estimate_harvest" tests/testthat/`
   - **If found:** Decide whether to update tests to current API or delete as obsolete

2. **Vignette examples:** Need to verify no vignettes demonstrate deprecated API
   - **Action:** Run `grep -r "estimate_effort\|estimate_cpue\|estimate_harvest" vignettes/`
   - **If found:** Update examples to use current API (`est_effort`, `est_cpue`, `est_catch`)

3. **Helper function usage:** `create_survey_design()` in R/estimators.R may be unused after deprecated function removal
   - **Action:** Run `grep -r "create_survey_design" R/` to check usage
   - **If unused:** Remove in Phase 2 along with deprecated functions
   - **If used:** Keep it

### Not Blocking Removal

- **old_code/ reference documentation:** Low priority - git history is sufficient
- **Deprecation warnings:** Not needed - package never released
- **Migration vignettes:** Not needed - comprehensive getting-started vignettes already exist with current API

## Ready for Roadmap

Research complete. The removal sequence is well-defined with clear verification checkpoints and rollback strategies. Each phase is independently valuable:

- **Phase 1** prevents new usage of deprecated functions (user-facing improvement)
- **Phase 2** removes dead code from package (maintainer-facing improvement)
- **Phase 3** reduces repository size and confusion (contributor-facing improvement)
- **Phase 4** ensures documentation accuracy (user-facing improvement)

All four phases can be completed in a single work session (~3-4 hours total) or split across multiple sessions with git commits after each verified phase. The work is low-risk due to comprehensive test coverage and clear rollback strategies.

## Sources

### Official R Package Documentation
- [When can I remove a deprecated function from a package? - Posit Community](https://forum.posit.co/t/when-can-i-remove-a-deprecated-function-from-a-package/9707)
- [Communicate lifecycle changes in your functions - lifecycle package](https://cran.r-project.org/web/packages/lifecycle/vignettes/communicate.html)
- [Lifecycle stages - lifecycle package](https://cran.r-project.org/web/packages/lifecycle/vignettes/stages.html)
- [Managing imports and exports • roxygen2](https://roxygen2.r-lib.org/articles/namespace.html)
- [Appendix A — R CMD check – R Packages (2e)](https://r-pkgs.org/R-CMD-check.html)

### Package Evolution Best Practices
- [rOpenSci | Package evolution - changing stuff in your package](https://ropensci.org/blog/2017/01/05/package-evolution/)
- [Writing R Extensions - CRAN](https://cran.r-project.org/doc/manuals/r-release/R-exts.html)

### Code Quality and Maintenance
- [Automatic Code Cleaning in R with Rclean - rOpenSci](https://ropensci.org/blog/2020/04/21/rclean/)
- [Self-admitted technical debt in R: detection and causes - Automated Software Engineering](https://link.springer.com/article/10.1007/s10515-022-00358-6)
- [Build Code Needs Maintenance Too: MSR 2025](https://2025.msrconf.org/details/msr-2025-technical-papers/13/Build-Scripts-Need-Maintenance-Too-A-Study-on-Refactoring-and-Technical-Debt-in-Buil)

---
*Research summary for: tidycreel legacy constructor removal*
*Researched: 2026-01-27*
