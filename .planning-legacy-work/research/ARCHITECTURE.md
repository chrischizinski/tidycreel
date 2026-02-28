# Architecture Research: Safe Code Removal from R Packages

**Domain:** R Package Maintenance - Legacy Code Removal
**Researched:** 2026-01-27
**Confidence:** HIGH

## Standard Architecture for Safe Code Removal

### Removal Sequence Pattern

Safe code removal follows a **dependency-ordered sequence** to prevent breakage:

```
┌─────────────────────────────────────────────────────────────┐
│                    PHASE 1: EXPORTS                          │
│  Remove deprecated function exports from NAMESPACE          │
│  (Functions still exist but are internal-only)              │
├─────────────────────────────────────────────────────────────┤
│                    PHASE 2: FUNCTION STUBS                   │
│  Remove deprecated function definitions from R/ files        │
│  (Functions no longer exist in package)                     │
├─────────────────────────────────────────────────────────────┤
│                    PHASE 3: ARCHIVED CODE                    │
│  Remove archived code directories (old_code/, backups/)     │
│  (Historical reference code removed)                        │
├─────────────────────────────────────────────────────────────┤
│                    PHASE 4: DOCUMENTATION                    │
│  Clean up references in NEWS.md, README, vignettes          │
│  (User-facing docs updated)                                 │
└─────────────────────────────────────────────────────────────┘
```

### Why This Order?

1. **NAMESPACE first**: Removing exports prevents new usage while functions still exist (rollback-friendly)
2. **Function code second**: Once exports are gone and tested, remove implementations
3. **Archived code third**: Only after active code is clean, remove historical reference
4. **Documentation last**: Update user-facing materials after code changes are stable

## Verification Checkpoints

Each phase has mandatory verification before proceeding to next phase.

### Checkpoint 1: After NAMESPACE Cleanup

| Check | Command | Success Criteria |
|-------|---------|------------------|
| **R CMD check** | `devtools::check()` | 0 errors, 0 warnings |
| **Load package** | `devtools::load_all()` | Loads without errors |
| **Test suite** | `devtools::test()` | All tests pass |
| **NAMESPACE validity** | Inspect `NAMESPACE` file | No deprecated function exports present |

**What to verify:**
- Deprecated functions (`estimate_effort`, `estimate_cpue`, `estimate_harvest`) are NOT in NAMESPACE exports
- All current API functions (`est_effort`, `est_cpue`, `est_catch`) ARE still exported
- No "object not found" errors from test suite
- No "undefined exports" warnings from R CMD check

**Rollback strategy if failed:**
```r
# Restore @export tags to deprecated functions
# Re-run devtools::document()
# Investigate why removal broke tests
```

### Checkpoint 2: After Function Stub Removal

| Check | Command | Success Criteria |
|-------|---------|------------------|
| **R CMD check** | `devtools::check()` | 0 errors, 0 warnings |
| **NAMESPACE regeneration** | `devtools::document()` | No deprecated exports created |
| **Code references** | `grep -r "estimate_effort\\|estimate_cpue\\|estimate_harvest" R/` | No references to removed functions |
| **Test suite** | `devtools::test()` | All tests still pass |

**What to verify:**
- Functions `estimate_effort()`, `estimate_cpue()`, `estimate_harvest()` no longer exist in `R/estimators.R`
- Helper function `create_survey_design()` removal validated (if it was only used by deprecated functions)
- No test files call deprecated functions
- NAMESPACE still contains all current API exports

**Rollback strategy if failed:**
```r
# Restore function definitions from git
git checkout HEAD -- R/estimators.R
# Run devtools::document() and retest
```

### Checkpoint 3: After Archived Code Removal

| Check | Command | Success Criteria |
|-------|---------|------------------|
| **Directory gone** | `ls old_code/` | Directory does not exist |
| **R CMD check** | `devtools::check()` | Still passes (archived code doesn't affect package) |
| **Git status** | `git status` | old_code/ listed as deleted |
| **Package size** | Compare `.tar.gz` size | Package size reduced |

**What to verify:**
- `old_code/` directory completely removed
- No broken references in documentation pointing to old_code examples
- Package still builds and checks cleanly

**Rollback strategy if failed:**
```bash
# Restore old_code directory from git if needed for reference
git checkout HEAD -- old_code/
# But this should not affect R CMD check
```

### Checkpoint 4: After Documentation Cleanup

| Check | Command | Success Criteria |
|-------|---------|------------------|
| **NEWS.md accuracy** | Review NEWS.md | No mentions of removed functions as current API |
| **README accuracy** | Review README.md | No examples using removed functions |
| **Vignette accuracy** | Build vignettes | No errors, no deprecated function calls |
| **R CMD check --as-cran** | `devtools::check(cran = TRUE)` | 0 errors, 0 warnings, 0 notes |

**What to verify:**
- NEWS.md documents the removal in appropriate version section
- README examples use current API only (`est_*` functions)
- Vignettes render without errors
- No "undocumented code objects" notes from R CMD check

## Component Responsibilities

### R/estimators.R (Primary Target)

| Component | Current State | After Removal |
|-----------|---------------|---------------|
| `estimate_effort()` | Deprecated stub (lines 13-19) | REMOVED |
| `estimate_cpue()` | Deprecated stub (lines 22-28) | REMOVED |
| `estimate_harvest()` | Deprecated stub (lines 31-37) | REMOVED |
| `est_effort()` | Current API (lines 86-141) | RETAINED |
| `create_survey_design()` | Helper (lines 144-171) | EVALUATE - remove if unused by current API |

**Implementation note:** Lines 13-37 contain three deprecated stub functions that immediately abort with migration messages. These are the **primary removal targets**.

### NAMESPACE (Secondary Target)

| Export | Current State | After Removal |
|--------|---------------|---------------|
| `export(estimate_effort)` | Line 31 | REMOVED |
| `export(estimate_cpue)` | Line 30 | REMOVED |
| `export(estimate_harvest)` | Line 32 | REMOVED |
| All other exports | Lines 1-97 | RETAINED |

**Implementation note:** NAMESPACE is auto-generated by roxygen2. Removal happens by:
1. Deleting `#' @export` tags from function roxygen comments
2. Running `devtools::document()` to regenerate NAMESPACE

### old_code/ Directory (Tertiary Target)

| File | Size | Purpose | Action |
|------|------|---------|--------|
| `CreelAnalysisFunctions.R` | 43k | Historical analysis code | DELETE |
| `CreelAnalysisFunctionsCJCEDits.R` | 57k | Historical edited version | DELETE |
| `CreelApiHelper.R` | 5.1k | Historical API helpers | DELETE |
| `CreelConfigCheck.R` | 12k | Historical config code | DELETE |
| `CreelDataAccess.R` | 57k | Historical data access code | DELETE |
| `CreelDataAccess_CJCedits.R` | 6.5k | Historical edited version | DELETE |
| `CreelEnvSetup.R` | 6.9k | Historical environment setup | DELETE |
| **Total** | **~187k** | Historical archive | **DELETE ENTIRE DIRECTORY** |

**Rationale for deletion:**
- None of these files are referenced by current package code
- All are dated 2024-2025, representing superseded approaches
- Git history preserves this code if needed for reference
- Keeping archived code confuses contributors about what's current

## Safe Removal Sequence (Step-by-Step)

### Phase 1: Remove NAMESPACE Exports

**Objective:** Make deprecated functions internal-only (not exported to users)

**Steps:**
1. Open `R/estimators.R`
2. Locate the three deprecated functions: `estimate_effort()`, `estimate_cpue()`, `estimate_harvest()`
3. Remove the `#' @export` roxygen tag from each function's documentation block
4. Run `devtools::document()` to regenerate NAMESPACE
5. Verify NAMESPACE no longer contains `export(estimate_effort)`, `export(estimate_cpue)`, `export(estimate_harvest)`
6. **CHECKPOINT 1**: Run R CMD check and test suite

**Expected outcome:** Functions still exist in package but are not accessible to users via `tidycreel::estimate_effort()` notation.

**Rollback if needed:** Add `#' @export` tags back and re-run `devtools::document()`

### Phase 2: Remove Function Stubs

**Objective:** Delete deprecated function definitions from package source

**Steps:**
1. **Pre-verification:**
   ```r
   # Ensure no current code calls these functions
   grep -r "estimate_effort\\|estimate_cpue\\|estimate_harvest" R/ --exclude=estimators.R
   # Should return no results
   ```

2. Open `R/estimators.R`
3. Delete lines 13-37 (the three deprecated stub functions)
4. Evaluate `create_survey_design()` helper (lines 144-171):
   - Search for usage: `grep -r "create_survey_design" R/`
   - If only used by deprecated functions, delete it too
   - If used elsewhere, keep it
5. Run `devtools::document()` to ensure NAMESPACE stays clean
6. **CHECKPOINT 2**: Run R CMD check and test suite

**Expected outcome:** Deprecated functions no longer exist in package. Attempting to call them results in "object not found" error.

**Rollback if needed:**
```bash
git checkout HEAD -- R/estimators.R
devtools::document()
```

### Phase 3: Remove Archived Code

**Objective:** Delete `old_code/` directory and its contents

**Steps:**
1. **Pre-verification:**
   ```r
   # Ensure no documentation references old_code examples
   grep -r "old_code" vignettes/ README.md CONTRIBUTING.md
   # Should return no results or only historical mentions
   ```

2. Delete the directory:
   ```bash
   rm -rf old_code/
   ```

3. Verify deletion:
   ```bash
   ls old_code/  # Should fail with "No such file or directory"
   ```

4. **CHECKPOINT 3**: Run R CMD check (should still pass - archived code doesn't affect package)

**Expected outcome:** Package size reduced by ~187k lines of historical code. Git history preserves the code.

**Rollback if needed:**
```bash
git checkout HEAD -- old_code/
```

### Phase 4: Clean Documentation

**Objective:** Update user-facing documentation to reflect removal

**Steps:**
1. **Update NEWS.md:**
   ```markdown
   # tidycreel (development version)

   ## Breaking Changes

   * Removed deprecated function stubs `estimate_effort()`, `estimate_cpue()`,
     and `estimate_harvest()`. These functions have been superseded by the
     survey-first API (`est_effort()`, `est_cpue()`, `est_catch()`) and were
     never part of a public release. See vignettes for migration examples.

   ## Internal Changes

   * Removed `old_code/` directory containing ~187k lines of historical code.
     Git history preserves this code for reference.
   ```

2. **Verify README.md:**
   - Search for any examples using deprecated functions
   - Replace with current API examples if found
   - Ensure "Getting Started" uses `est_*` functions only

3. **Verify vignettes:**
   ```r
   # Build all vignettes to check for deprecated function usage
   devtools::build_vignettes()
   ```
   - If any vignette references deprecated functions, update to current API
   - Check rendered output for broken examples

4. **CHECKPOINT 4**: Run `devtools::check(cran = TRUE)` for final validation

**Expected outcome:** All documentation reflects current API only. No mentions of removed functions except in NEWS.md removal notice.

## Architectural Patterns for Safe Removal

### Pattern 1: Progressive Export Restriction

**What:** Remove public access before removing code

**When to use:** When functions are already marked deprecated and have replacements

**Trade-offs:**
- **Pro:** Allows rollback if breaking changes discovered
- **Pro:** Users can't accidentally use deprecated functions during transition
- **Con:** Extra step vs. removing everything at once

**Example:**
```r
# Step 1: Function exists but is internal-only (not exported)
estimate_effort <- function(...) {
  cli::cli_abort("Use est_effort() instead")
}

# Step 2: Function removed entirely
# (nothing - function deleted from file)
```

**Why this works:** If removing the function breaks something, you can quickly restore it as internal-only to debug, without re-exposing it to users.

### Pattern 2: Checkpoint-Driven Removal

**What:** Mandatory verification after each phase before proceeding

**When to use:** Any multi-step code removal process

**Trade-offs:**
- **Pro:** Catches breakage early (isolates cause to specific phase)
- **Pro:** Clear rollback points
- **Con:** More time-consuming than bulk removal

**Example:**
```r
# After each phase:
devtools::check()        # R CMD check
devtools::test()         # Test suite
devtools::load_all()     # Package loading
git status               # Verify expected changes only
```

**Why this works:** If Phase 2 breaks tests but Phase 1 didn't, you know Phase 2 caused the breakage, not something earlier.

### Pattern 3: Archived Code Quarantine

**What:** Keep archived code in separate directory, remove only after current code is stable

**When to use:** When old implementations might be needed for reference

**Trade-offs:**
- **Pro:** Historical reference available during migration
- **Pro:** Can compare old vs. new implementations
- **Con:** Takes up repository space
- **Con:** Can confuse contributors about what's current

**Example:**
```
R/
  estimators.R          # Current implementation
  est-effort-*.R        # Current implementation
old_code/
  CreelAnalysis*.R      # Historical implementation (DELETE LAST)
```

**Why this works:** Git already preserves history, so after current code is proven stable, archived code is redundant. Remove it last to avoid distracting from main removal work.

### Pattern 4: Documentation-Last Cleanup

**What:** Update user-facing docs only after code changes are verified

**When to use:** Always - don't update docs until code is stable

**Trade-offs:**
- **Pro:** Docs stay accurate during development
- **Pro:** Avoids documenting changes that get rolled back
- **Con:** Requires remembering to update docs at end

**Example:**
```
# WRONG ORDER:
1. Update README to remove deprecated examples
2. Remove deprecated functions
3. Tests break, rollback
4. README now inaccurate!

# CORRECT ORDER:
1. Remove deprecated functions
2. Verify with checkpoints
3. THEN update README
```

**Why this works:** If you have to rollback code changes, you don't have to also rollback documentation changes.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Bulk Deletion Without Checkpoints

**What people do:** Delete all deprecated code (exports, functions, archived files) in one commit

**Why it's wrong:**
- If tests break, can't isolate which deletion caused it
- Makes rollback difficult (restore everything or nothing)
- Violates architectural standard of checkpoint-driven work

**Do this instead:** Follow phased removal with checkpoints after each phase

### Anti-Pattern 2: Removing Documentation First

**What people do:** Update README/NEWS before removing code, to "document intent"

**Why it's wrong:**
- If code removal breaks and needs rollback, docs are now inaccurate
- Creates window where docs don't match code
- R CMD check may complain about documented objects not existing

**Do this instead:** Code changes first, documentation updates last (after verification)

### Anti-Pattern 3: Skipping R CMD Check Between Phases

**What people do:** Remove exports, remove functions, remove archived code all in sequence without running `devtools::check()` between steps

**Why it's wrong:**
- Can't isolate which phase broke the package
- May not discover breakage until much later
- Wastes time debugging when cause is unclear

**Do this instead:** Run `devtools::check()` and `devtools::test()` after EVERY phase

### Anti-Pattern 4: Deleting Functions Still Referenced in Tests

**What people do:** Remove deprecated functions without checking if tests call them

**Why it's wrong:**
- Tests break with "object not found" errors
- May indicate tests were validating deprecated behavior
- Forces unplanned test updates during "simple" removal

**Do this instead:**
```r
# Before removing functions, search for references:
grep -r "estimate_effort" tests/
grep -r "estimate_cpue" tests/
grep -r "estimate_harvest" tests/

# If found, either:
# - Update tests to use current API (est_effort, est_cpue, est_catch)
# - Delete obsolete tests that only validated deprecated behavior
```

### Anti-Pattern 5: Removing Archived Code That's Referenced in Docs

**What people do:** Delete `old_code/` directory without checking for documentation links

**Why it's wrong:**
- Broken links in vignettes or README
- Examples that reference old_code files fail to run
- R CMD check may fail on vignette build

**Do this instead:**
```r
# Before deleting old_code/, search for references:
grep -r "old_code" vignettes/ README.md CONTRIBUTING.md

# Update or remove any references found
```

## Integration Points

### External Dependencies (R Package Ecosystem)

| Dependency | Integration Pattern | Notes for Removal |
|------------|---------------------|-------------------|
| **roxygen2** | `@export` tags control NAMESPACE | Remove `@export` → `devtools::document()` → NAMESPACE regenerated |
| **testthat** | Test suite validates package | Must pass after each phase |
| **devtools** | `check()`, `test()`, `document()` | Core tools for verification checkpoints |
| **survey** | Current API dependency | Not affected by deprecated function removal |
| **cli** | Error messaging | Used in deprecated stubs - can keep or remove with stubs |

**Critical integration:** roxygen2 auto-generates NAMESPACE. Manual NAMESPACE edits will be overwritten. Always remove `@export` tags from source and regenerate.

### Internal Boundaries (Within tidycreel Package)

| Boundary | Communication | Removal Considerations |
|----------|---------------|------------------------|
| **Deprecated API ↔ Current API** | None (deprecated stubs just abort) | Safe to remove - no calls from deprecated to current |
| **Estimators ↔ Variance Engine** | `tc_compute_variance()` | Not affected by deprecated function removal |
| **Tests ↔ Functions** | Direct function calls | CRITICAL: Must verify no tests call deprecated functions |
| **Vignettes ↔ Functions** | Example code | CRITICAL: Must verify no vignettes use deprecated functions |
| **old_code/ ↔ R/** | None (archived code is isolated) | Safe to remove - no references from current code |

**Critical boundary:** Tests and vignettes may reference deprecated functions in examples. Must search and update before removal.

## Rollback Strategy

### If Checkpoint 1 Fails (After NAMESPACE Cleanup)

**Symptoms:**
- R CMD check fails with "undefined exports"
- Tests fail with "object not found" for exported function
- Package won't load

**Diagnosis:**
```r
# Check NAMESPACE diff
git diff NAMESPACE

# Check what was removed
grep "export(estimate" NAMESPACE  # Should be empty after removal
```

**Rollback:**
```r
# Restore @export tags in R/estimators.R
# Add back above each deprecated function:
#' @export

# Regenerate NAMESPACE
devtools::document()

# Verify restoration
grep "export(estimate" NAMESPACE  # Should show exports
```

**Root cause investigation:**
- Were any current functions accidentally unmarked for export?
- Did test suite rely on deprecated function being exported?

### If Checkpoint 2 Fails (After Function Stub Removal)

**Symptoms:**
- R CMD check fails with "object not found"
- Tests fail when calling removed functions
- NAMESPACE regeneration creates unexpected exports

**Diagnosis:**
```r
# Check what code still references removed functions
grep -r "estimate_effort\|estimate_cpue\|estimate_harvest" R/ tests/

# Check function diff
git diff R/estimators.R
```

**Rollback:**
```bash
# Restore function definitions
git checkout HEAD -- R/estimators.R

# Regenerate documentation
devtools::document()

# Re-test
devtools::test()
```

**Root cause investigation:**
- Which tests were calling removed functions?
- Update tests to use current API (`est_*` functions) before re-attempting removal
- Were the functions used by other internal functions?

### If Checkpoint 3 Fails (After Archived Code Removal)

**Symptoms:**
- Documentation build fails referencing old_code examples
- Links broken in vignettes or README

**Note:** R CMD check should NOT fail from old_code removal (it's not part of package structure)

**Diagnosis:**
```r
# Check for references to old_code
grep -r "old_code" vignettes/ README.md CONTRIBUTING.md

# Check vignette build
devtools::build_vignettes()
```

**Rollback:**
```bash
# Restore old_code directory
git checkout HEAD -- old_code/
```

**Root cause investigation:**
- Which documentation files reference old_code?
- Remove or update those references before re-attempting removal

### If Checkpoint 4 Fails (After Documentation Cleanup)

**Symptoms:**
- R CMD check fails with documentation errors
- Vignettes don't build
- Examples in README fail

**Diagnosis:**
```r
# Build vignettes to see errors
devtools::build_vignettes()

# Check R CMD check output
devtools::check(cran = TRUE)
```

**Rollback:**
```bash
# Restore documentation files
git checkout HEAD -- NEWS.md README.md vignettes/
```

**Root cause investigation:**
- Did documentation updates reference non-existent functions?
- Were examples updated to use correct current API?

## tidycreel-Specific Considerations

### Current Architecture Constraints

Based on `ARCHITECTURAL_STANDARDS.md`:

1. **Single Source of Truth**: All variance calculations use `tc_compute_variance()`
   - **Impact on removal:** Deprecated functions don't call variance engine, so removal is safe

2. **No Wrapper Functions**: Features built-in to estimators
   - **Impact on removal:** Deprecated stubs are NOT wrappers (they just abort), safe to remove

3. **Replace, Don't Add**: When rebuilding, replace original
   - **Impact on removal:** This removal is cleanup from previous replace operation (old API replaced with new)

### Test Suite Coverage

Package has comprehensive test coverage (testthat edition 3):
- `test-architectural-compliance.R`: Enforces variance engine usage
- `test-estimators-enhanced.R`: Tests enhanced features
- `test-estimators-integration.R`: Tests integration points

**Critical check before removal:**
```r
# Search test files for deprecated function usage
grep -r "estimate_effort\|estimate_cpue\|estimate_harvest" tests/testthat/

# If found in test-estimators-*.R files:
# - These may be testing deprecated functions
# - Update to test current API (est_effort, est_cpue, est_catch)
# - Or delete tests that only validated deprecated behavior
```

### Vignette Considerations

Package has comprehensive vignettes demonstrating workflows:
- `getting-started.Rmd`
- `effort_design_based.Rmd`
- `survey_creel_terms.Rmd`

**Critical check before removal:**
```r
# Search vignettes for deprecated function usage
grep -r "estimate_effort\|estimate_cpue\|estimate_harvest" vignettes/

# Build vignettes to verify no errors
devtools::build_vignettes()
```

### Branch Context

Working on `phase2/remove-legacy-constructors` branch:
- Branch name suggests this is Phase 2 of a larger refactoring
- Phase 1 likely introduced new API (`est_*` functions)
- Phase 2 is cleanup (remove old API)
- Merge to `main` is goal after cleanup complete

**Implication:** This removal should be final - no planned deprecation cycle since package never released.

## Sources

### R Package Management
- [When can I remove a deprecated function from a package? - Posit Community](https://forum.posit.co/t/when-can-i-remove-a-deprecated-function-from-a-package/9707)
- [Communicate lifecycle changes in your functions - lifecycle package](https://cran.r-project.org/web/packages/lifecycle/vignettes/communicate.html)
- [rOpenSci | Package evolution - changing stuff in your package](https://ropensci.org/blog/2017/01/05/package-evolution/)
- [Lifecycle stages - lifecycle package](https://cran.r-project.org/web/packages/lifecycle/vignettes/stages.html)

### R CMD Check and NAMESPACE
- [Appendix A — R CMD check – R Packages (2e)](https://r-pkgs.org/R-CMD-check.html)
- [Managing imports and exports • roxygen2](https://roxygen2.r-lib.org/articles/namespace.html)
- [Writing R Extensions - CRAN](https://cran.r-project.org/doc/manuals/r-release/R-exts.html)

### Code Cleanup and Security
- [Automatic Code Cleaning in R with Rclean - rOpenSci](https://ropensci.org/blog/2020/04/21/rclean/)
- [Detecting Security Vulnerabilities in R Packages - Jumping Rivers](https://www.jumpingrivers.com/blog/r-package-vulnerabilities-security/)

### Technical Debt Research
- [Self-admitted technical debt in R: detection and causes - Automated Software Engineering](https://link.springer.com/article/10.1007/s10515-022-00358-6)
- [Build Code Needs Maintenance Too: A Study on Refactoring and Technical Debt in Build Systems - MSR 2025](https://2025.msrconf.org/details/msr-2025-technical-papers/13/Build-Scripts-Need-Maintenance-Too-A-Study-on-Refactoring-and-Technical-Debt-in-Buil)

---
*Architecture research for: tidycreel legacy code removal*
*Researched: 2026-01-27*
*Confidence: HIGH - Based on official R package documentation and CRAN best practices*
