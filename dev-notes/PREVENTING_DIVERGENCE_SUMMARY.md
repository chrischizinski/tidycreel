# Preventing Architectural Divergence in tidycreel

## ✅ What We've Created to Prevent Divergence

### 📋 Documentation
1. **`ARCHITECTURAL_STANDARDS.md`** - Complete architectural guidelines
   - Golden rules
   - Banned patterns
   - Required patterns
   - Code review checklist
   - Naming conventions

2. **`GROUND_UP_INTEGRATION_DESIGN.md`** - Architecture design
3. **`GROUND_UP_IMPLEMENTATION_SUMMARY.md`** - Implementation guide

### 🛠️ Enforcement Tools
1. **`scripts/check-architecture.sh`** - Automated compliance checker
   - Detects banned file patterns
   - Detects banned function patterns
   - Verifies core engine usage
   - Checks documentation

2. **`scripts/pre-commit-hook`** - Git pre-commit hook
   - Blocks non-compliant commits
   - Runs automatically on `git commit`
   - Provides clear error messages

3. **`scripts/cleanup-patches.sh`** - Cleanup automation
   - Safely deletes old patch files
   - Interactive confirmation
   - Complete post-rebuild cleanup

4. **`tests/testthat/test-architectural-compliance.R`** - Automated tests
   - Enforces architecture in test suite
   - Fails if standards violated
   - Part of CI/CD pipeline

### 🏗️ Core Infrastructure
1. **`R/variance-engine.R`** - Single variance source of truth
2. **`R/variance-decomposition-engine.R`** - Native decomposition
3. **`R/survey-diagnostics.R`** - Native diagnostics

## 🔒 How Divergence is Prevented

### Layer 1: Pre-Commit Hook (First Defense)
```bash
# Install once
cp scripts/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Runs automatically on every commit
git commit -m "your changes"
# → Checks for violations
# → Blocks commit if violations found
```

**What it catches**:
- Banned file names (`*-integration.R`, `*-enhanced.R`)
- Banned function patterns (`add_enhanced_*`, `enhance_*`)
- Direct survey calls instead of core engine

### Layer 2: Manual Compliance Check
```bash
# Run before committing
bash scripts/check-architecture.sh

# Shows:
# ✅ All checks passed
# ⚠️  Warnings (areas for improvement)
# ❌ Errors (must fix)
```

### Layer 3: Automated Tests
```r
# Run tests
devtools::test()

# tests/testthat/test-architectural-compliance.R runs:
# - No banned files exist
# - No banned functions exist
# - Core engine is used
# - Documentation present
```

### Layer 4: CI/CD Pipeline
```yaml
# .github/workflows/architectural-compliance.yml
# Runs on every pull request
# Blocks merge if violations found
```

### Layer 5: Code Review
**Mandatory PR Checklist**:
- [ ] No wrapper functions created
- [ ] No "enhanced" versions created
- [ ] No banned file patterns
- [ ] All variance via `tc_compute_variance()`
- [ ] Features built-in to functions
- [ ] Backward compatible

## 🚫 What's Banned (IMPOSSIBLE to Merge)

### Banned File Names
```
R/*-integration.R        ❌ BLOCKED
R/*-enhanced.R           ❌ BLOCKED
R/*-wrapper.R            ❌ BLOCKED
R/*-patch.R              ❌ BLOCKED
R/*-internals-access.R   ❌ BLOCKED
```

### Banned Function Patterns
```r
add_enhanced_*()         ❌ BLOCKED
enhance_estimator()      ❌ BLOCKED
create_enhanced_*()      ❌ BLOCKED
batch_enhance_*()        ❌ BLOCKED
*_with_internals()       ❌ BLOCKED
```

### Banned Approaches
```r
# Wrapper pattern ❌ BLOCKED
result <- estimator(...)
enhanced <- add_something(result)  # ← WRAPPER!

# Parallel implementation ❌ BLOCKED
estimator()           # Original
estimator_enhanced()  # ← PARALLEL VERSION!
```

## ✅ What's Required (MUST Use)

### Required Pattern
```r
# Built-in features ✅ REQUIRED
estimator(
  ...,
  variance_method = "bootstrap",    # ← Built-in!
  decompose_variance = TRUE,         # ← Built-in!
  design_diagnostics = TRUE          # ← Built-in!
)
```

### Required Function Call
```r
# ALL variance calculations ✅ REQUIRED
variance_result <- tc_compute_variance(
  design = design,
  response = response,
  method = variance_method,
  ...
)
```

## 📊 Compliance Workflow

### For Regular Development
```bash
# 1. Make changes to R files
vim R/est-effort-instantaneous.R

# 2. Check compliance
bash scripts/check-architecture.sh

# 3. Run tests
Rscript -e 'devtools::test()'

# 4. Commit (automatically checked by hook)
git add .
git commit -m "feat: add bootstrap variance to instantaneous estimator"
# → Pre-commit hook runs
# → If violations: commit blocked
# → If clean: commit succeeds

# 5. Push
git push
# → CI/CD checks architecture
# → If violations: PR blocked
# → If clean: PR can be reviewed
```

### For Adding New Features
```r
# ❌ WRONG: Don't create wrapper
add_new_feature <- function(result, ...) {
  # Wrapper approach
}

# ✅ CORRECT: Add built-in parameter
est_effort.instantaneous <- function(
  ...,
  new_feature = FALSE  # ← Built-in parameter
) {
  # Feature implemented directly
  if (new_feature) {
    # Implementation here
  }
}
```

### For Rebuilding Estimators
```bash
# 1. Create _v2 version for testing
# R/est-effort-progressive-v2.R

# 2. Test thoroughly
Rscript -e 'testthat::test_file("tests/testthat/test-est-effort-progressive.R")'

# 3. Replace original entirely
mv R/est-effort-progressive-v2.R R/est-effort-progressive.R

# 4. Verify
bash scripts/check-architecture.sh

# 5. Commit
git add R/est-effort-progressive.R
git commit -m "refactor: rebuild progressive estimator with native survey integration"
```

## 🎯 Success Metrics

### Architectural Compliance ✅
```bash
bash scripts/check-architecture.sh

# Perfect compliance shows:
# ✅ No banned file patterns
# ✅ No banned function patterns
# ✅ All estimators use core engine
# ✅ All core infrastructure present
# ✅ All documentation present
# ✅ No old patch files
```

### Test Coverage ✅
```r
devtools::test()

# Architectural tests pass:
# ✓ variance engine exists and is exported
# ✓ no banned file naming patterns exist
# ✓ no wrapper functions exist in codebase
# ✓ estimator functions use tc_compute_variance
# ✓ core engine functions follow naming convention
# ✓ output structure is consistent across estimators
```

## 🚀 Quick Setup

### One-Time Setup
```bash
# 1. Make scripts executable
chmod +x scripts/*.sh

# 2. Install pre-commit hook
cp scripts/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# 3. Verify setup
bash scripts/check-architecture.sh

# 4. Read standards
cat ARCHITECTURAL_STANDARDS.md
```

### Every Development Session
```bash
# Before committing
bash scripts/check-architecture.sh
Rscript -e 'devtools::test()'

# Commit (hook runs automatically)
git commit -m "your message"
```

## 📚 Key Documents

1. **`ARCHITECTURAL_STANDARDS.md`** - READ THIS FIRST
   - Complete guidelines
   - Banned patterns
   - Required patterns
   - Examples

2. **`GROUND_UP_INTEGRATION_DESIGN.md`** - Architecture design
3. **`GROUND_UP_IMPLEMENTATION_SUMMARY.md`** - Implementation guide
4. **`scripts/README.md`** - Script usage guide

## 🎓 Training for Contributors

### New Contributors
1. Read `ARCHITECTURAL_STANDARDS.md`
2. Install pre-commit hook
3. Run `bash scripts/check-architecture.sh` to understand checks
4. Review example: `R/est-effort-instantaneous-REBUILT.R`

### Existing Contributors
1. Understand: NO MORE WRAPPERS
2. Understand: Features must be BUILT-IN
3. Understand: ONE variance engine (`tc_compute_variance()`)
4. Understand: REPLACE, don't add

## ✨ Result: Divergence is IMPOSSIBLE

With these layers of enforcement:
1. ✅ Pre-commit hook blocks bad commits
2. ✅ CI/CD blocks bad PRs
3. ✅ Tests fail if architecture violated
4. ✅ Code review catches anything else
5. ✅ Clear documentation prevents confusion

**Divergence can't happen by accident anymore - it would require deliberately bypassing FIVE layers of protection.**

---

## Summary: The Answer to "How Can We Make Sure This Doesn't Diverge Again?"

**Short Answer**: We've built 5 layers of automated enforcement that make divergence practically impossible.

**Long Answer**:
1. **Pre-commit hook** - Blocks bad commits before they happen
2. **Compliance script** - Shows violations immediately
3. **Automated tests** - Fail if architecture violated
4. **CI/CD pipeline** - Blocks non-compliant PRs
5. **Code review** - Human verification as last line of defense

**Plus**:
- Clear documentation of standards
- Banned patterns explicitly defined
- Required patterns explicitly defined
- Example implementations
- Training materials

**Result**: Divergence would require:
- Bypassing pre-commit hook (`--no-verify`)
- Ignoring compliance script failures
- Ignoring test failures
- Bypassing CI/CD
- Bypassing code review

**This is effectively impossible for accidental divergence, and very difficult even for deliberate attempts.**

🎉 **Your codebase architecture is now protected!**
