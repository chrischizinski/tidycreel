# tidycreel Ground-Up Integration: Quick Reference

## 🎯 One-Page Cheat Sheet

### Core Philosophy
**ONE function for variance. Features built-in, not bolted on. Divergence impossible.**

---

## 🏗️ Architecture

```
Estimator (built-in params)
    ↓
tc_compute_variance() [CORE ENGINE]
    ↓
Survey Package
```

---

## 🔧 Key Functions

| Function | Purpose |
|----------|---------|
| `tc_compute_variance()` | THE variance function (use in ALL estimators) |
| `tc_decompose_variance()` | Variance component decomposition |
| `tc_design_diagnostics()` | Design quality assessment |

---

## 📝 Standard Estimator Pattern

```r
estimator_name <- function(
  ...,                              # Existing params
  variance_method = "survey",       # NEW
  decompose_variance = FALSE,       # NEW
  design_diagnostics = FALSE,       # NEW
  n_replicates = 1000              # NEW
) {

  # 1. Input validation (unchanged)
  # 2. Data preparation (unchanged)
  # 3. Design construction (unchanged)

  # 4. CORE: Use variance engine
  variance_result <- tc_compute_variance(
    design = design_eff,
    response = "response_var",
    method = variance_method,
    by = by_all,
    conf_level = conf_level,
    n_replicates = n_replicates,
    calculate_deff = TRUE
  )

  # 5. Build output
  out <- tibble(
    ...,
    estimate = variance_result$estimate,
    se = variance_result$se,
    ci_low = variance_result$ci_lower,
    ci_high = variance_result$ci_upper,
    deff = variance_result$deff,
    method = "method_name"
  )

  # 6. Optional decomposition
  if (decompose_variance) {
    variance_result$decomposition <- tc_decompose_variance(...)
  }

  # 7. Optional diagnostics
  if (design_diagnostics) {
    variance_result$diagnostics <- tc_design_diagnostics(...)
  }

  # 8. Add variance_info
  out$variance_info <- list(variance_result)

  return(out)
}
```

---

## 🚫 What's BANNED

| Pattern | Status |
|---------|--------|
| `*-integration.R` files | ❌ BANNED |
| `*-enhanced.R` files | ❌ BANNED |
| `*-wrapper.R` files | ❌ BANNED |
| `add_enhanced_*()` functions | ❌ BANNED |
| `enhance_*()` functions | ❌ BANNED |
| Parallel implementations | ❌ BANNED |
| Direct `survey::svytotal()` in estimators | ❌ BANNED |

---

## ✅ What's REQUIRED

| Pattern | Status |
|---------|--------|
| Use `tc_compute_variance()` | ✅ REQUIRED |
| Built-in parameters | ✅ REQUIRED |
| `variance_info` list-column | ✅ REQUIRED |
| `deff` column | ✅ REQUIRED |
| Backward compatibility | ✅ REQUIRED |

---

## 🛠️ Essential Commands

```bash
# Check compliance
bash scripts/check-architecture.sh

# Install protection
cp scripts/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Run tests
Rscript -e 'devtools::test()'

# Update docs
Rscript -e 'devtools::document()'

# Cleanup (AFTER rebuild complete)
bash scripts/cleanup-patches.sh
```

---

## 📚 Key Documents

| Document | When to Use |
|----------|-------------|
| `ARCHITECTURAL_STANDARDS.md` | **Read FIRST** - The rules |
| `ESTIMATOR_REBUILD_GUIDE.md` | Rebuilding estimators |
| `PREVENTING_DIVERGENCE_SUMMARY.md` | Understanding protection |
| `INTEGRATION_COMPLETE_SUMMARY.md` | Big picture overview |
| `FUTURE_ENHANCEMENTS.md` | surveytable & roadmap |

---

## 🔄 Rebuilding Workflow

```bash
# 1. Read the guide
cat ESTIMATOR_REBUILD_GUIDE.md

# 2. Copy original to *-REBUILT.R
cp R/estimator.R R/estimator-REBUILT.R

# 3. Edit following template
# ... edit R/estimator-REBUILT.R ...

# 4. Test
Rscript -e 'testthat::test_file("tests/testthat/test-estimator.R")'

# 5. Compare old vs new
# result_old <- original(...)
# result_new <- rebuilt(...)
# all.equal(result_old$estimate, result_new$estimate)

# 6. Replace original
mv R/estimator-REBUILT.R R/estimator.R

# 7. Check compliance
bash scripts/check-architecture.sh

# 8. Commit
git add R/estimator.R
git commit -m "refactor: rebuild estimator with native survey integration"
```

---

## ✅ Progress Checklist

### Infrastructure ✅
- [x] Core variance engine
- [x] Variance decomposition
- [x] Survey diagnostics
- [x] Enforcement tools
- [x] Documentation

### Estimators
- [x] est_effort.instantaneous (proof of concept)
- [x] est_effort.progressive
- [x] est_effort.aerial
- [ ] est_effort.busroute_design
- [ ] aggregate_cpue
- [ ] est_cpue
- [ ] est_total_harvest

### Cleanup
- [ ] Replace all REBUILT files with originals
- [ ] Run cleanup script
- [ ] Update NAMESPACE
- [ ] Run all tests
- [ ] Final compliance check

---

## 🚨 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Banned file pattern detected" | Rename file (remove -integration, -enhanced, etc.) |
| "Function doesn't use tc_compute_variance" | Replace direct survey calls with tc_compute_variance() |
| "Pre-commit hook blocks commit" | Run `bash scripts/check-architecture.sh` to see violations |
| "Results don't match original" | Check that default parameters match original behavior |

---

## 💡 Remember

1. **ONE variance function**: `tc_compute_variance()`
2. **Built-in not bolted-on**: Parameters, not wrappers
3. **Replace don't add**: No parallel versions
4. **Test backward compat**: Default behavior unchanged
5. **Enforce automatically**: Pre-commit hook protects architecture

---

## 📞 Quick Help

**Rebuilding**: `ESTIMATOR_REBUILD_GUIDE.md`
**Standards**: `ARCHITECTURAL_STANDARDS.md`
**Check**: `bash scripts/check-architecture.sh`
**Test**: `Rscript -e 'devtools::test()'`

---

**Print this page and keep it handy while rebuilding!** 🎯
