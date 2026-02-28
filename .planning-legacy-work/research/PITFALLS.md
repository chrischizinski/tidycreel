# Pitfalls Research: R Package Legacy Code Removal

**Domain:** R package maintenance - removing deprecated functions and archived code
**Researched:** 2026-01-27
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: NAMESPACE Desynchronization After Removing @export Tags

**What goes wrong:**
When you remove deprecated functions that have `@export` tags, running `devtools::document()` or `roxygen2::roxygenize()` may fail before regenerating NAMESPACE, leaving orphaned exports that reference non-existent functions. This creates a chicken-and-egg problem where the package can't be loaded to regenerate documentation because the NAMESPACE is broken.

**Why it happens:**
roxygen2 parses NAMESPACE during documentation generation. If the NAMESPACE references functions that no longer exist in R/ code, the package can't load, preventing NAMESPACE regeneration. This is especially common when removing multiple deprecated functions at once.

**How to avoid:**
1. **Manual NAMESPACE cleanup first**: Before running `devtools::document()`, manually edit NAMESPACE to remove the exports for deprecated functions you're deleting
2. **Delete one function at a time**: Remove one deprecated function, regenerate NAMESPACE, verify R CMD check passes, then proceed to the next
3. **Use the two-step approach**: First comment out the function body but keep `@export`, regenerate NAMESPACE to verify, then delete the entire function

**Warning signs:**
- `devtools::document()` errors with "object 'function_name' not found"
- `R CMD check` fails with NAMESPACE errors before you can regenerate docs
- `devtools::load_all()` fails due to missing exported functions

**Phase to address:**
Phase 1 (Preparation) - Must be handled correctly before any function removal

---

### Pitfall 2: Breaking Internal Function Calls

**What goes wrong:**
You remove a deprecated exported function, but internal package functions still call it. Since the function is exported, internal code may use it without explicit package prefix (`package:::`), causing silent breakage that only appears when the function is called.

**Why it happens:**
In R packages, exported functions are available both to users AND to internal code. Developers may assume only user code calls deprecated functions, missing internal dependencies. Grep searches for the function name may miss it if called via `do.call()` or computed strings.

**How to avoid:**
1. **Comprehensive code search**: Use `Grep` tool to search entire R/ directory for function name references, including:
   - Direct calls: `function_name(`
   - String references: `"function_name"`
   - Dynamic calls: `do.call`, `match.fun`, `get()`
2. **Check test files**: Search `tests/testthat/` for any tests calling the deprecated function
3. **Check examples and vignettes**: Search `man/`, `vignettes/`, `README.md` for usage examples
4. **Run tests BEFORE removal**: Ensure full test suite passes as baseline

**Warning signs:**
- Functions work in interactive testing but fail in specific scenarios
- Tests fail with "could not find function" errors after removal
- Examples in documentation stop working

**Phase to address:**
Phase 1 (Preparation) - Must identify all references before deletion

---

### Pitfall 3: Orphaned Test Files for Removed Functions

**What goes wrong:**
Test files continue testing deprecated functions that have been removed, causing test suite failures. Worse, you might delete tests that actually test shared functionality, accidentally reducing coverage of active code paths.

**Why it happens:**
Test file naming conventions (`test-function-name.R`) don't always map 1:1 to implementation files. A test file for `estimate_effort()` might also test helper functions or shared code paths used by the new `est_effort()` function. Blindly deleting test files based on name creates coverage gaps.

**How to avoid:**
1. **Audit test files first**: Read test file contents before deleting - what does it actually test?
2. **Check for shared helpers**: Look for tests of internal functions that both old and new APIs use
3. **Run coverage before and after**: Use `covr::package_coverage()` to compare coverage metrics
4. **Verify no coverage regression**: New API functions should maintain or exceed old coverage levels
5. **For deprecated stubs that just error**: Keep minimal tests that verify the error message, then remove only when function is deleted

**Warning signs:**
- Code coverage percentage drops after cleanup
- Specific code paths in new functions become untested
- R CMD check shows "Examples with CPU time > 2.5 times elapsed time" (may indicate missing tests)

**Phase to address:**
Phase 2 (Testing) - Must verify coverage before and after deletion

---

### Pitfall 4: Git History Contamination from old_code/ Directory

**What goes wrong:**
You delete `old_code/` directory but it remains in git history. If old_code/ contained sensitive data, credentials, or very large files, the repository remains bloated and may expose sensitive information even after directory deletion.

**Why it happens:**
Git tracks history forever. `git rm -r old_code/` removes the directory from the working tree and commits that removal, but all previous commits still contain the files. For packages never released, this is usually fine. But if old_code/ was accidentally committed with sensitive data, simple deletion doesn't help.

**How to avoid:**
1. **For normal cleanup (no sensitive data)**: Just use `git rm -r old_code/` and commit - this is sufficient for unreleased packages
2. **Verify no sensitive data first**: Check old_code/ contents for API keys, passwords, credentials, personal data
3. **If sensitive data found**: Must use `git filter-branch` or `BFG Repo-Cleaner` to rewrite history (complex, requires force-push)
4. **Add to .gitignore AFTER removal**: Prevent accidental re-addition by adding `old_code/` to `.gitignore`
5. **For collaborative repos**: Communicate with all contributors before rewriting history

**Warning signs:**
- `.git` directory is larger than expected for project size
- Old credentials or API keys found in old_code/
- Multiple developers have cloned the repository (history rewrite requires coordination)

**Phase to address:**
Phase 3 (Cleanup) - Handle during old_code/ directory removal

---

### Pitfall 5: S3 Method Registration Issues

**What goes wrong:**
When removing functions, you might have S3 methods that were registered via `@export`. roxygen2 7.3+ warns about S3 methods missing `@export` tags, but may generate incorrect NAMESPACE directives on first run if NAMESPACE file doesn't exist. This causes subtle method dispatch failures.

**Why it happens:**
S3 methods must be **registered** (not exported in the traditional sense), but roxygen2 uses `@export` for registration. When you remove deprecated generics or methods, the NAMESPACE needs `S3method()` directives, not `export()` directives. roxygen2 can generate wrong directives if NAMESPACE is missing/corrupted.

**How to avoid:**
1. **Check for S3 methods**: Look for functions like `function.class` naming pattern
2. **Verify NAMESPACE directives**: After regeneration, check that S3 methods use `S3method(generic, class)` not `export(function.class)`
3. **Two-pass regeneration**: If NAMESPACE is corrupted, run `roxygen2::roxygenize()` twice - first run may generate wrong directives, second run corrects them
4. **For deprecated S3 methods**: Remove `@export` tag and the method definition together
5. **Check print/plot methods**: These are often S3 methods that get forgotten

**Warning signs:**
- NAMESPACE has `export(print.myclass)` instead of `S3method(print, myclass)`
- Generic methods don't dispatch correctly after cleanup
- roxygen2 warnings about "S3 methods should be exported with @export"

**Phase to address:**
Phase 1 (Preparation) - Check during NAMESPACE regeneration planning

---

### Pitfall 6: Undocumented Internal Functions Warning

**What goes wrong:**
After removing deprecated functions, R CMD check produces "Undocumented code objects" WARNING because internal helper functions used by both old and new APIs are now exposed in NAMESPACE without documentation.

**Why it happens:**
When deprecated wrappers are removed, their helpers may become the only remaining NAMESPACE entry for internal functions. If those helpers were never documented (because they were internal), R CMD check complains. This is especially common if the deprecated function was exported but called unexported helpers.

**How to avoid:**
1. **Audit helper functions**: Identify all functions called by deprecated code
2. **Check if helpers are exported**: Look for `@export` tags on helper functions
3. **Document or un-export helpers**:
   - If helper should be public: Add proper `@title`, `@description`, `@param`, `@return` documentation
   - If helper should be internal: Remove `@export` tag or add `@keywords internal`
4. **Run R CMD check frequently**: Catch documentation issues early

**Warning signs:**
- R CMD check WARNING: "Undocumented code objects: 'helper_function'"
- Functions in NAMESPACE lack corresponding .Rd files in man/
- `devtools::check()` documentation section shows warnings

**Phase to address:**
Phase 1 (Preparation) - Identify documentation needs before function removal

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip running R CMD check after each removal | Faster iteration | Accumulates errors that are harder to debug later | Never - always run check after each change |
| Remove functions without checking internal calls | Feels complete quickly | Silent runtime failures in untested code paths | Never - always grep for references first |
| Delete test files by name matching | Cleans up test directory | May remove tests for shared functionality | Only if you've read the test file contents first |
| Manually edit NAMESPACE instead of regenerating | Avoids roxygen2 issues | NAMESPACE diverges from @export tags, confusing future maintainers | Only temporarily during roxygen2 chicken-egg problems |
| Commit old_code/ deletion without reviewing contents | Quick cleanup | Risk of deleting important historical context or exposing sensitive data | Only after verifying no sensitive data exists |
| Skip updating .Rbuildignore | No immediate impact | old_code/ remnants may appear in built package tarball | Never - always update .Rbuildignore during cleanup |

## Integration Gotchas

Common mistakes when removing deprecated code that interfaces with other systems.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| roxygen2 NAMESPACE generation | Removing functions before running document() causes load failures | Manually edit NAMESPACE to remove exports BEFORE deleting function code |
| devtools::check() | Running check without regenerating docs first | Always `devtools::document()` then `devtools::check()` in sequence |
| testthat tests | Assuming test file names map 1:1 to function names | Read test file contents to understand what's actually being tested |
| Git history | Using `git rm` and assuming sensitive data is gone | For sensitive data, must use git filter-branch or BFG Repo-Cleaner |
| covr test coverage | Not establishing baseline coverage before removals | Run `covr::package_coverage()` before and after to verify no regression |
| .Rbuildignore | Forgetting to add old_code/ to ignore patterns | Add `^old_code$` to .Rbuildignore when removing old_code/ directory |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Running full test suite after every small change | Slow iteration during cleanup | Use `devtools::test_active_file()` for individual test files, full suite only before commit | Not a performance trap for this project - test suites should always be run |
| Not using `devtools::load_all()` before check | Repeated `R CMD check` runs take 2-5 minutes each | Use `load_all()` for quick iteration, `check()` for final validation | When making many small changes - check is too slow for iteration |
| Git operations on large old_code/ directory | `git status` and `git add` become slow | Remove old_code/ in single atomic commit, don't iterate on partial removals | If old_code/ is >100MB (not applicable here - only 192KB) |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Leaving API keys or credentials in old_code/ directory | Sensitive data remains in git history forever | Audit old_code/ for sensitive patterns before deletion; use `git filter-branch` if found |
| Removing authentication/validation from deprecated wrappers | New code paths might lack security checks that old wrappers provided | Verify new API functions have same validation logic as deprecated ones |
| Deleting functions that enforce data access controls | Internal callers may bypass controls if wrapper is removed | Check if deprecated functions enforced permissions/quotas/limits |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **NAMESPACE regeneration**: Often missing verification that exports were actually removed - verify with `devtools::document()` and manual inspection
- [ ] **Test coverage maintenance**: Often missing coverage comparison - verify with `covr::package_coverage()` before and after
- [ ] **Internal reference cleanup**: Often missing checks for internal calls - verify with `Grep` search across R/, tests/, man/, vignettes/
- [ ] **.Rbuildignore update**: Often missing old_code/ pattern - verify old_code/ doesn't appear in `R CMD build` tarball
- [ ] **Git ignore patterns**: Often missing .gitignore entry to prevent re-adding - verify old_code/ won't be accidentally committed again
- [ ] **Documentation cross-references**: Often missing updates to vignettes/README that mention old functions - verify with grep for function names in docs
- [ ] **NEWS.md entry**: Often missing changelog entry for removal - verify breaking changes are documented (if package was released)

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Broken NAMESPACE from premature deletion | LOW | 1. Restore function from git history<br>2. Manually edit NAMESPACE to remove export<br>3. Run `devtools::document()`<br>4. Delete function again<br>5. Verify NAMESPACE is clean |
| Missing internal function calls | MEDIUM | 1. Check test failures for "could not find function" errors<br>2. Restore deleted function temporarily<br>3. Update internal calls to use new API<br>4. Run tests to verify fix<br>5. Remove deprecated function again |
| Lost test coverage | HIGH | 1. Run `covr::package_coverage()` to identify gaps<br>2. Restore deleted test file from git history<br>3. Extract tests for shared functionality<br>4. Migrate extracted tests to new API test files<br>5. Verify coverage restored |
| Git history with sensitive data | HIGH | 1. Use `git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch old_code/sensitive_file.R' --prune-empty --tag-name-filter cat -- --all`<br>2. Force-push to remote (WARNING: breaks all clones)<br>3. Notify all collaborators to re-clone<br>4. Add sensitive patterns to .gitignore |
| S3 method dispatch broken | MEDIUM | 1. Check NAMESPACE for `export(print.class)` patterns<br>2. Manually edit to `S3method(print, class)`<br>3. Run `roxygen2::roxygenize()` again<br>4. If wrong directives persist, delete NAMESPACE and regenerate from scratch |
| Undocumented functions warning | LOW | 1. Identify warning from R CMD check output<br>2. Add `@keywords internal` to function roxygen block<br>3. Or add full documentation with `@title`, `@description`, etc.<br>4. Run `devtools::document()` to regenerate |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| NAMESPACE desynchronization | Phase 1 (Preparation) | Manual NAMESPACE edit before deletion, followed by successful `devtools::document()` |
| Breaking internal calls | Phase 1 (Preparation) | Grep search shows no references to deprecated functions in R/ directory |
| Orphaned test files | Phase 2 (Testing) | `covr::package_coverage()` shows no coverage regression |
| Git history contamination | Phase 3 (Cleanup) | Verify old_code/ contains no sensitive data before `git rm` |
| S3 method registration | Phase 1 (Preparation) | NAMESPACE contains only `S3method()` directives, no `export()` for methods |
| Undocumented functions | Phase 1 (Preparation) | R CMD check passes with no "Undocumented code objects" warnings |

## tidycreel-Specific Considerations

Based on the project context, here are package-specific issues to watch for:

### Already Avoided
- **No backward compatibility concerns**: Package never publicly released, so no users to migrate
- **No deprecation cycle needed**: Can delete functions immediately without warnings
- **Existing test coverage**: Comprehensive test suite already in place to catch breakage

### Still Risky
- **Three deprecated functions**: `estimate_effort()`, `estimate_cpue()`, `estimate_harvest()` - all must be removed together as they're in same file
- **Survey design complexity**: Functions interact with complex `survey::svydesign()` objects - ensure new API functions handle all cases old ones did
- **Helper function `create_survey_design()`**: Located in same file as deprecated functions - verify it's not called by old APIs only
- **NAMESPACE has 96 entries**: Large NAMESPACE means higher risk of missing an orphaned export

### Recommended Approach
1. **Pre-removal audit**: Search codebase for all three deprecated function names
2. **Verify test baseline**: Run full test suite and R CMD check before any changes
3. **Manual NAMESPACE edit**: Remove exports for `estimate_effort`, `estimate_cpue`, `estimate_harvest` from NAMESPACE
4. **Delete deprecated stubs**: Remove the three functions (lines 13-37 of R/estimators.R)
5. **Regenerate NAMESPACE**: Run `devtools::document()` to verify regeneration works
6. **Verify tests pass**: Run `devtools::test()` and `devtools::check()`
7. **Remove old_code/ directory**: After function removal is verified working
8. **Coverage check**: Run `covr::package_coverage()` to ensure no regression

## Sources

**Official R Package Development Documentation:**
- [R Packages (2e): Lifecycle](https://r-pkgs.org/lifecycle.html) - Best practices for deprecation and removal
- [rOpenSci Packages: Package Evolution](https://devguide.ropensci.org/maintenance_evolution.html) - Guidelines for changing code in packages
- [Bioconductor: Deprecation Guidelines](https://contributions.bioconductor.org/deprecation.html) - Formal deprecation process

**roxygen2 and NAMESPACE:**
- [roxygen2: Managing Imports and Exports](https://roxygen2.r-lib.org/articles/namespace.html) - NAMESPACE generation mechanics
- [R-hub Blog: Internal Functions in R Packages](https://blog.r-hub.io/2019/12/12/internal-functions/) - Best practices for internal vs exported functions
- [roxygen2 Issue #1144](https://github.com/r-lib/roxygen2/issues/1144) - NAMESPACE regeneration chicken-and-egg problem
- [roxygen2 Issue #1613](https://github.com/r-lib/roxygen2/issues/1613) - S3 method export directive issues

**lifecycle Package:**
- [lifecycle Package Documentation](https://lifecycle.r-lib.org/articles/communicate.html) - Official deprecation workflow (not needed for unreleased packages, but good reference)
- [Posit Community: When to Remove Deprecated Functions](https://forum.posit.co/t/when-can-i-remove-a-deprecated-function-from-a-package/9707) - Community guidance

**Git History Management:**
- [Git Documentation: git-rm](https://git-scm.com/docs/git-rm) - Official git rm documentation
- [30 Seconds of Code: Purge File from Git History](https://www.30secondsofcode.org/git/s/purge-file/) - Git filter-branch usage

**Test Coverage:**
- [covr Package Documentation](https://covr.r-lib.org/) - Test coverage tools for R

---
*Pitfalls research for: tidycreel R package legacy code removal*
*Researched: 2026-01-27*
*Confidence: HIGH - Based on official R package development documentation, roxygen2 official docs, and community best practices*
