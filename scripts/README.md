# tidycreel Scripts

This directory contains utility scripts for maintaining architectural standards and managing the survey integration rebuild.

## Scripts

### `check-architecture.sh`
**Purpose**: Verify architectural compliance

**Usage**:
```bash
bash scripts/check-architecture.sh
```

**What it checks**:
- No banned file naming patterns (`*-integration.R`, `*-enhanced.R`, etc.)
- No banned function patterns (`add_enhanced_*`, `enhance_*`, etc.)
- Estimators use `tc_compute_variance()`
- Core infrastructure files exist
- Documentation is present
- Old patch files status

**When to run**:
- Before committing changes
- After modifying estimator functions
- As part of CI/CD pipeline

**Exit codes**:
- `0`: All checks passed (may have warnings)
- `1`: Checks failed with errors

---

### `cleanup-patches.sh`
**Purpose**: Delete old patch/integration files after rebuild is complete

**Usage**:
```bash
bash scripts/cleanup-patches.sh
```

**⚠️ WARNING**: This script DELETES files. Only run after:
1. All estimators have been rebuilt with native integration
2. All tests pass
3. Results have been validated

**What it deletes**:
- `R/survey-enhanced-integration.R`
- `R/estimators-integration.R`
- `R/survey-internals-integration.R`
- All other patch/integration files
- Old demo files
- Old planning documents

**Interactive**: Requires confirmation before deleting

---

### `pre-commit-hook`
**Purpose**: Git pre-commit hook to enforce architectural standards

**Installation**:
```bash
cp scripts/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**What it does**:
- Runs before every `git commit`
- Checks staged files for architectural violations
- Blocks commits that violate standards
- Provides clear error messages

**Checks performed**:
- Banned file naming patterns in staged files
- Banned function patterns in staged changes
- Estimators using core variance engine (warning only)

**To bypass** (not recommended):
```bash
git commit --no-verify
```

---

## Quick Start

### Initial Setup
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Install pre-commit hook
cp scripts/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Run initial compliance check
bash scripts/check-architecture.sh
```

### During Development
```bash
# Before committing
bash scripts/check-architecture.sh

# Commits will automatically be checked by pre-commit hook
git commit -m "your message"
```

### After Completing Rebuild
```bash
# Verify all estimators are rebuilt
bash scripts/check-architecture.sh

# Run tests
Rscript -e 'devtools::test()'

# If all looks good, cleanup old patches
bash scripts/cleanup-patches.sh

# Verify clean architecture
bash scripts/check-architecture.sh

# Commit the cleanup
git add .
git commit -m "chore: remove old patch files after ground-up rebuild"
```

---

## Architectural Standards

All scripts enforce the standards defined in `ARCHITECTURAL_STANDARDS.md`:

### ✅ REQUIRED
- All variance calculations use `tc_compute_variance()`
- Features built-in to estimator functions (no wrappers)
- Core infrastructure files present
- Proper naming conventions

### ❌ BANNED
- File names: `*-integration.R`, `*-enhanced.R`, `*-wrapper.R`, `*-patch.R`
- Functions: `add_enhanced_*`, `enhance_*`, wrapper patterns
- Parallel implementations
- Direct survey package calls (should use core engine)

---

## Troubleshooting

### "Banned file naming pattern detected"
**Cause**: File name contains forbidden patterns
**Fix**: Rename file to follow standards (e.g., `my-feature-integration.R` → `my-feature.R`)

### "Banned function pattern detected"
**Cause**: Code contains wrapper functions
**Fix**: Rebuild function with built-in features instead of wrappers

### "Estimator doesn't use tc_compute_variance"
**Cause**: Estimator directly calls survey package instead of using core engine
**Fix**: Rebuild estimator to use `tc_compute_variance()`

### "Old patch files still exist"
**Cause**: Patch files haven't been cleaned up yet
**Fix**:
- If rebuild is complete: Run `bash scripts/cleanup-patches.sh`
- If rebuild is in progress: This is expected, continue rebuilding

---

## CI/CD Integration

These scripts can be integrated into GitHub Actions:

```yaml
# .github/workflows/architectural-compliance.yml
name: Architectural Compliance
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check architecture
        run: bash scripts/check-architecture.sh
```

---

## Contributing

When contributing to tidycreel:

1. **Install pre-commit hook**: `cp scripts/pre-commit-hook .git/hooks/pre-commit`
2. **Check compliance**: Run `bash scripts/check-architecture.sh` before committing
3. **Follow standards**: Read `ARCHITECTURAL_STANDARDS.md`
4. **Test changes**: Run `Rscript -e 'devtools::test()'`

---

## Support

For questions about architectural standards or scripts:
- See: `ARCHITECTURAL_STANDARDS.md`
- See: `GROUND_UP_INTEGRATION_DESIGN.md`
- See: `GROUND_UP_IMPLEMENTATION_SUMMARY.md`
