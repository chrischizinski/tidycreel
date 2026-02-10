# Pitfalls Research: Adding Interview-Based Catch/Harvest Estimation

**Domain:** Creel survey interview-based estimation for catch and harvest
**Researched:** 2026-02-09
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Wrong Estimator for Interview Type (Ratio-of-Means vs Mean-of-Ratios)

**What goes wrong:**
Using ratio-of-means estimator for roving interviews (incomplete trips) produces biased catch rate estimates, typically underestimating true catch by 12-15%. Conversely, using mean-of-ratios for access point interviews (complete trips) produces correct estimates but with unnecessarily high variance (20-30% higher standard errors).

**Why it happens:**
Roving interviews sample anglers mid-trip with probability proportional to trip length. Longer trips are more likely to be sampled, creating length-biased sampling. The ratio-of-means estimator E(Σ catch / Σ effort) weights trips by their effort, amplifying this bias. Developers often apply the same estimator to both interview types because "they're both calculating catch rate" without understanding the sampling probability difference.

**How to avoid:**
1. **Encode interview type in design object:** Add `interview_type` field to creel_design ("access" vs "roving")
2. **Estimator dispatch on interview type:** `est_cpue()` should check interview_type and route to:
   - `est_cpue_ratio_of_means()` for access interviews
   - `est_cpue_mean_of_ratios()` for roving interviews
3. **Explicit parameter with safe default:** If user must specify, default to ratio-of-means (safer choice) with warning
4. **Validation check:** Error if roving data detected but ratio-of-means requested

**Warning signs:**
- Catch rate estimates systematically lower than known population rates
- Estimates vary dramatically when switching estimator
- Variance estimates unstable or extremely large with mean-of-ratios
- Simulations show 12-15% negative bias

**Phase to address:**
Phase 08-02 (CPUE Estimation) - Must implement correct estimator routing before any catch rate calculations

---

### Pitfall 2: Missing Truncation for Roving Interviews with Mean-of-Ratios

**What goes wrong:**
Mean-of-ratios estimator for roving interviews without truncation of short trips produces infinite or extremely large variance estimates. Short trips (e.g., 5 minutes = 0.083 hours) with any catch create extreme ratios (e.g., 2 fish / 0.083 hours = 24 fish/hour), which dominate variance calculations. Root mean squared error increases by 2-3x without truncation.

**Why it happens:**
The mean-of-ratios estimator computes mean(catch_i / effort_i). As effort_i → 0, the ratio → ∞ even for small catch values. These extreme outliers have huge influence on variance. Developers focus on point estimates (which may seem reasonable due to averaging) and miss the variance explosion. Literature recommends 20-30 minute minimum, but this is often overlooked during implementation.

**How to avoid:**
1. **Built-in truncation in est_cpue_mean_of_ratios():** Filter `hours_fished >= 0.5` (30 minutes) before estimation
2. **Make truncation threshold configurable:** Parameter `min_trip_hours = 0.5` with documented default
3. **Validation check:** Count and warn if >10% of trips would be truncated (may indicate data quality issue)
4. **Document in output:** Record number of trips truncated in result metadata
5. **Error if roving without truncation:** Block user from setting `min_trip_hours = 0`

**How to avoid (continued):**
```r
est_cpue_mean_of_ratios <- function(design, min_trip_hours = 0.5, ...) {
  # Validation
  if (min_trip_hours <= 0) {
    cli_abort("min_trip_hours must be > 0 for mean-of-ratios estimator")
  }

  # Count truncated trips
  n_truncated <- sum(design$interviews$hours_fished < min_trip_hours)
  pct_truncated <- n_truncated / nrow(design$interviews)

  if (pct_truncated > 0.10) {
    cli_warn(c(
      "!" = "{n_truncated} trips ({scales::percent(pct_truncated)}) truncated (< {min_trip_hours} hours)",
      "i" = "High truncation may indicate data quality issues",
      "i" = "Verify interview data is from roving design"
    ))
  }

  # Filter
  interviews_filtered <- design$interviews %>%
    filter(hours_fished >= min_trip_hours)

  # Estimation continues...
}
```

**Warning signs:**
- Standard errors 2-5x larger than ratio-of-means estimates for same data
- Confidence intervals include impossible values (e.g., negative catch rates)
- Many small trip durations (<30 minutes) in roving interview data
- Variance estimates fail to converge or produce NA values

**Phase to address:**
Phase 08-03 (Roving CPUE) - Must implement truncation logic before roving catch rate estimation

---

### Pitfall 3: Incorrect Variance Propagation for Total Catch (Effort × CPUE)

**What goes wrong:**
Calculating total catch as `effort_estimate × cpue_estimate` but variance as `var(effort) + var(cpue)` produces severely underestimated standard errors (30-50% too small). The correct formula requires the covariance term and cross-product terms from the delta method: `Var(E×C) ≈ E²·Var(C) + C²·Var(E) + 2·E·C·Cov(E,C)`. Ignoring correlation between effort and catch rate leads to false precision.

**Why it happens:**
Effort and CPUE are estimated from the same survey (overlapping sample), creating correlation. If more anglers are counted (high effort estimate), CPUE may be lower (congestion effect) or higher (better fishing attracts more anglers). Developers often treat them as independent because they're computed separately. The delta method for products is not intuitive and requires survey package internals knowledge.

**How to avoid:**
1. **Use survey package product estimator:** Don't manually multiply; use `survey::svycontrast()` with formula
2. **Dedicated total_catch function:** Create `est_total_catch()` that:
   - Takes effort design + interview design (may share calendar)
   - Computes effort and CPUE internally
   - Uses delta method for product variance via `survey::svycontrast()`
   - Returns total catch with correct SE
3. **Don't expose manual multiplication:** Document that users should NOT compute total = effort × cpue themselves
4. **Reference test against manual delta method:** Verify variance matches hand-calculated delta method formula

**How to avoid (continued):**
```r
est_total_catch <- function(effort_design, interview_design, ...) {
  # Estimate effort
  effort_result <- est_effort(effort_design, ...)

  # Estimate CPUE
  cpue_result <- est_cpue(interview_design, ...)

  # Create combined design for covariance
  # (requires shared calendar/stratification)
  combined_design <- merge_designs(effort_design, interview_design)

  # Use delta method via survey package
  total_catch <- survey::svycontrast(
    combined_design,
    quote(effort * cpue)
  )

  # Return with correct variance
  return(tibble(
    estimate = coef(total_catch),
    se = SE(total_catch),
    method = "product_delta_method"
  ))
}
```

**Warning signs:**
- Confidence intervals for total catch narrower than expected
- Standard errors scale linearly with estimate (should scale as sqrt)
- Variance estimates don't change when correlation is non-zero
- Simulation coverage of confidence intervals <90% (should be 95% for α=0.05)

**Phase to address:**
Phase 08-05 (Total Catch Estimation) - Must implement correct product variance before any total catch calculations

---

### Pitfall 4: Data Structure Mismatch Between Count and Interview Data

**What goes wrong:**
Count data (effort estimation) uses day-level PSUs with calendar stratification, but interview data uses individual-level observations with trip characteristics. When combining for total catch = effort × cpue, the survey designs are incompatible (different PSU structures, different strata definitions). Attempting to merge designs or compute covariance fails with obscure survey package errors about "mismatched strata" or "incompatible designs".

**Why it happens:**
The existing tidycreel architecture (v0.1.0) built effort estimation with day as PSU, which is correct for count surveys. Interview-based estimation needs individual interviews as observations. These operate at different aggregation levels. The architectural decision to use `creel_design` object for both conceals the incompatibility until users try to combine estimates for total catch.

**How to avoid:**
1. **Separate design constructors:** Keep `add_counts()` (day-PSU) separate from `add_interviews()` (individual-PSU)
2. **Shared calendar as bridge:** Both designs reference the same calendar tibble for stratum definitions
3. **Design merging utility:** Create `merge_count_interview_designs()` that:
   - Checks for calendar compatibility (same strata, same dates)
   - Aggregates interview data to day-level for covariance computation
   - Creates combined design with proper nesting structure
4. **Document integration requirements:** Clearly state that total catch requires compatible stratification
5. **Validation in est_total_catch():** Error early if designs have incompatible structure

**How to avoid (continued):**
```r
add_interviews <- function(design, interviews, interview_type = c("access", "roving")) {
  # Validate design already has calendar
  if (is.null(design$calendar)) {
    cli_abort("Design must have calendar before adding interviews")
  }

  # Validate interviews match calendar dates
  interview_dates <- unique(interviews$date)
  calendar_dates <- design$calendar$date

  missing_dates <- setdiff(interview_dates, calendar_dates)
  if (length(missing_dates) > 0) {
    cli_abort(c(
      "x" = "Interview data contains dates not in calendar",
      "i" = "Missing dates: {paste(missing_dates, collapse=', ')}"
    ))
  }

  # Join interviews with calendar strata
  interviews_with_strata <- interviews %>%
    left_join(design$calendar, by = "date")

  # Store in design object
  design$interviews <- interviews_with_strata
  design$interview_type <- match.arg(interview_type)

  # Build individual-level survey design
  design$interview_svy <- survey::svydesign(
    ids = ~1,  # Interviews are terminal units
    strata = design$strata_formula,
    data = interviews_with_strata,
    weights = ~interview_weight  # If using probability sampling
  )

  return(design)
}
```

**Warning signs:**
- `survey::svycontrast()` errors with "designs must have same strata"
- Covariance computation returns NA or Inf
- Manual merging attempts fail due to incompatible nesting
- Different number of strata in effort vs CPUE results

**Phase to address:**
Phase 08-01 (Interview Design Integration) - Must establish data structure patterns before estimation

---

### Pitfall 5: Sparse Interview Data Creating Unstable Estimates

**What goes wrong:**
CPUE estimation with <30 interviews per stratum produces unstable estimates with extremely wide confidence intervals or fails entirely. Ratio estimators are particularly sensitive to small samples - confidence interval coverage drops below 90% when n<50, and below 85% when n<30. In extreme cases (<10 interviews), estimates may be undefined or have infinite variance.

**Why it happens:**
Ratio estimators (both ratio-of-means and mean-of-ratios) are asymptotic - their properties hold as n→∞. With small samples, the normal approximation for confidence intervals breaks down. The delta method variance formula can produce negative variance estimates with extreme data. Creel surveys often have sparse interview data due to logistics (can't interview everyone) or low angler density on some days/locations.

**How to avoid:**
1. **Sample size validation:** Check n per stratum before estimation, warn if n<30, error if n<10
2. **Pooling recommendation:** Suggest combining strata when sparse
3. **Alternative estimators:** Offer bootstrap/jackknife variance for small samples (better coverage)
4. **Bayesian option:** For advanced users, allow hierarchical models that borrow strength across strata
5. **Document minimum sample sizes:** Vignette on "power and sample size for creel surveys"

**How to avoid (continued):**
```r
est_cpue <- function(design, by = NULL, min_n_per_stratum = 30, ...) {
  # Compute sample sizes
  if (!is.null(by)) {
    sample_sizes <- design$interviews %>%
      group_by(across({{ by }})) %>%
      summarize(n = n(), .groups = "drop")

    sparse_strata <- sample_sizes %>%
      filter(n < min_n_per_stratum)

    if (nrow(sparse_strata) > 0) {
      cli_warn(c(
        "!" = "{nrow(sparse_strata)} strata have <{min_n_per_stratum} interviews",
        "i" = "Estimates may be unstable",
        "i" = "Consider: 1) Pooling strata, 2) Using bootstrap variance, 3) Collecting more data",
        "i" = "Sparse strata: {paste(sparse_strata[[1]], collapse=', ')}"
      ))
    }

    very_sparse_strata <- sample_sizes %>%
      filter(n < 10)

    if (nrow(very_sparse_strata) > 0) {
      cli_abort(c(
        "x" = "{nrow(very_sparse_strata)} strata have <10 interviews (insufficient for estimation)",
        "i" = "Sparse strata: {paste(very_sparse_strata[[1]], collapse=', ')}",
        "i" = "Pool strata or collect more data before estimation"
      ))
    }
  } else {
    # Overall estimation
    n_total <- nrow(design$interviews)
    if (n_total < 30) {
      cli_warn("Only {n_total} interviews; consider bootstrap variance for better coverage")
    }
    if (n_total < 10) {
      cli_abort("Only {n_total} interviews; insufficient for stable estimation")
    }
  }

  # Estimation continues...
}
```

**Warning signs:**
- Confidence intervals include impossible values (negative catch rates)
- Standard errors larger than point estimates
- Wildly different estimates when dropping 1-2 observations
- Survey package warnings about "lonely PSUs" or "singleton strata"

**Phase to address:**
Phase 08-02 (CPUE Estimation) - Must validate sample sizes before allowing estimation

---

### Pitfall 6: Bag Limit Bias in Roving Interviews

**What goes wrong:**
Roving surveys severely underestimate catch when effective bag limits exist. Anglers who reach their limit leave the fishery, so roving clerks only encounter unsuccessful anglers still fishing. With a 2-fish bag limit, catch rate estimates can be biased low by 36%. With 5-fish limit, bias is 15%. This is NOT correctable by estimator choice - it's a fundamental design flaw.

**Why it happens:**
The roving design assumes stationary catch rates over time, but bag limits create non-stationarity: successful anglers exit. This violates the probability sampling assumption that all anglers have positive probability of being sampled. Mean-of-ratios estimator is unbiased under length-biased sampling, but can't correct for anglers who are never observed (zero sampling probability).

**How to avoid:**
1. **Detect bag limit scenarios:** Ask users if regulations include bag limits
2. **Data diagnostics:** Check for truncated catch distributions (many observations at limit value)
3. **Strong warning for roving + low limits:** If bag_limit ≤ 5 fish, warn that estimates are biased
4. **Recommend access design instead:** For regulated fisheries, access interviews capture completed trips
5. **Document limitation:** Be explicit that roving designs fail with effective bag limits

**How to avoid (continued):**
```r
add_interviews <- function(design, interviews, interview_type, bag_limit = NULL) {
  interview_type <- match.arg(interview_type, c("access", "roving"))

  # Check for bag limit issues
  if (interview_type == "roving" && !is.null(bag_limit)) {
    # Detect if many catches at bag limit
    catch_cols <- names(interviews)[grepl("^catch_", names(interviews))]

    at_limit <- interviews %>%
      rowwise() %>%
      mutate(at_limit = any(c_across(all_of(catch_cols)) >= bag_limit)) %>%
      pull(at_limit)

    pct_at_limit <- mean(at_limit, na.rm = TRUE)

    if (bag_limit <= 5) {
      cli_abort(c(
        "x" = "Roving interviews with low bag limits (≤5) produce severely biased estimates",
        "i" = "Bag limit: {bag_limit} fish",
        "i" = "{scales::percent(pct_at_limit)} of observed anglers at/near limit",
        "i" = "Expected bias: -15% to -36%",
        "!" = "Use access point interviews instead for this fishery"
      ))
    } else if (pct_at_limit > 0.20) {
      cli_warn(c(
        "!" = "{scales::percent(pct_at_limit)} of observed anglers at/near bag limit",
        "i" = "Roving estimates may be biased low",
        "i" = "Consider access point design for regulated fisheries"
      ))
    }
  }

  # Continue with design construction...
}
```

**Warning signs:**
- Catch rate estimates much lower than creel census or access point surveys
- Catch distributions truncated at regulation limits
- Interviews show many anglers at exactly the bag limit
- Estimates decrease as fishing season progresses (anglers learn limit)

**Phase to address:**
Phase 08-03 (Roving CPUE) - Must implement bag limit diagnostics before roving estimation deployed

---

### Pitfall 7: Mismatched Species Between Effort and Catch Data

**What goes wrong:**
Total harvest estimation requires multiplying targeted effort (e.g., salmon fishing hours) by species-specific catch rate (salmon per hour). If effort is estimated for all anglers but CPUE is estimated only for salmon anglers, the product produces biased total catch. Conversely, if CPUE includes all species but effort is targeted, the estimate is wrong. This is especially insidious because the math "works" - you get a number - but it's answering the wrong question.

**Why it happens:**
Creel surveys often collect data on multiple species but estimate separately. Effort data (counts) may not distinguish species targeted, while interview data includes species caught. Developers multiply overall effort by species-specific CPUE without realizing the population bases differ. The tidycreel v0.2.0 milestone explicitly defers multi-species to v0.3.0, but single-species calculations must still handle targeting correctly.

**How to avoid:**
1. **Enforce consistency checking:** When creating total catch estimate, verify effort and CPUE are for same population
2. **Metadata tracking:** Store `species` and `targeting` fields in estimate results
3. **Validation in est_total_catch():** Check that effort result and CPUE result have matching species/target tags
4. **Document targeting clearly:** User must specify if effort is "all anglers" vs "salmon anglers"
5. **For v0.2.0 single-species:** Assume all anglers target the focal species, document this assumption

**How to avoid (continued):**
```r
est_total_catch <- function(effort_result, cpue_result, ...) {
  # Validate consistency
  effort_species <- attr(effort_result, "species")
  cpue_species <- attr(cpue_result, "species")

  if (!is.null(effort_species) && !is.null(cpue_species)) {
    if (effort_species != cpue_species) {
      cli_abort(c(
        "x" = "Effort and CPUE estimates are for different species",
        "i" = "Effort species: {effort_species}",
        "i" = "CPUE species: {cpue_species}",
        "!" = "Total catch = effort × CPUE requires same species",
        "i" = "Filter data or re-estimate with consistent species"
      ))
    }
  }

  effort_targeting <- attr(effort_result, "targeting")
  cpue_targeting <- attr(cpue_result, "targeting")

  if (!is.null(effort_targeting) && !is.null(cpue_targeting)) {
    if (effort_targeting != cpue_targeting) {
      cli_abort(c(
        "x" = "Effort and CPUE estimates have different targeting assumptions",
        "i" = "Effort targeting: {effort_targeting}",
        "i" = "CPUE targeting: {cpue_targeting}",
        "!" = "Total catch requires consistent targeting (e.g., both 'all anglers' or both 'species-specific')"
      ))
    }
  }

  # Computation continues...
}
```

**Warning signs:**
- Total catch estimates much higher/lower than known harvest
- Estimates change dramatically when filtering for species in effort vs CPUE
- Interview data shows multi-species catches but effort assumes single species
- Domain estimates (by species) don't sum to overall estimate

**Phase to address:**
Phase 08-05 (Total Catch Estimation) - Must implement consistency checks before multiplying estimates

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Allow user to manually multiply effort × cpue | Flexible, simple API | Users compute wrong variance, no validation | Never - always use est_total_catch() |
| Use same estimator for access and roving | Less code, simpler API | 12-15% bias for roving surveys | Never - interview type determines estimator |
| Skip truncation for roving to "keep all data" | Higher sample size, no data loss | Infinite variance, unstable estimates | Never - truncation is required for roving |
| Assume independence when computing product variance | Simpler math, faster | 30-50% underestimated SE | Never - covariance is often non-zero |
| Skip sample size validation for sparse strata | Allows analysis to proceed | Unstable estimates, poor CI coverage | Only for exploratory analysis with explicit warnings |
| Pool strata automatically when sparse | Convenient, no user intervention | May obscure real differences, reduces biological insight | Only with explicit user consent and documentation |

## Integration Gotchas

Common mistakes when connecting interview estimation to existing count-based effort estimation.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Merging count and interview designs | Assuming same PSU structure | Use shared calendar, aggregate to compatible level |
| Computing total catch variance | Treating effort and CPUE as independent | Use delta method via survey::svycontrast() with covariance |
| Applying grouped estimation | Using different grouping variables in effort vs CPUE | Ensure by= parameter consistent across both estimates |
| Handling stratification | Different strata definitions in counts vs interviews | Calendar provides shared strata for both |
| Variance method selection | Mixing Taylor for effort with bootstrap for CPUE | Use same variance method for both (enables covariance) |
| Interview filtering | Truncating in est_cpue() but not updating effort | Truncation only affects CPUE, effort is from counts |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| No truncation caching for roving | Recompute filtered data every call | Cache truncated interview data in design object | >10,000 interviews with repeated estimates |
| Pairwise covariance computation | O(n²) for many strata | Use survey package's internal covariance matrix | >50 strata |
| Bootstrap for large datasets without parallelization | Estimation takes minutes | Use parallel processing or suggest Taylor | >1,000 bootstrap replicates with >5,000 observations |
| Storing full interview data in every result | Memory bloat with grouped estimation | Store only aggregated summaries in results | >100 groups with >1,000 interviews each |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Interview-based CPUE estimation**: Often missing estimator routing based on interview type - verify access uses ratio-of-means, roving uses mean-of-ratios
- [ ] **Roving CPUE estimation**: Often missing truncation of short trips - verify min_trip_hours parameter exists and defaults to 0.5
- [ ] **Total catch estimation**: Often missing proper variance propagation - verify uses delta method, not naive var(E) + var(C)
- [ ] **Design integration**: Often missing compatibility checks - verify count design and interview design share calendar/strata
- [ ] **Sample size validation**: Often missing warnings for sparse data - verify checks n per stratum, warns if <30, errors if <10
- [ ] **Bag limit diagnostics**: Often missing bias warnings - verify detects low bag limits with roving design
- [ ] **Species consistency**: Often missing validation - verify effort and CPUE are for same species/targeting
- [ ] **Variance method consistency**: Often missing check that both estimates use same method - verify when computing products

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong estimator used | HIGH | 1. Identify interview type from data<br>2. Re-run estimation with correct estimator<br>3. Document bias magnitude if already published<br>4. Quantify difference via simulation<br>5. Issue correction if estimates were used for management |
| Missing truncation in roving | MEDIUM | 1. Re-run with min_trip_hours=0.5<br>2. Compare estimates before/after<br>3. If variance reduced by >50%, original estimates were unstable<br>4. Document change in variance |
| Naive product variance | MEDIUM | 1. Re-compute using est_total_catch()<br>2. Compare SE before/after<br>3. If new SE is >30% larger, original CIs were too narrow<br>4. Report corrected estimates with proper uncertainty |
| Incompatible designs | MEDIUM | 1. Check calendar alignment<br>2. Rebuild interview design with same strata<br>3. Re-estimate CPUE<br>4. Verify merged design before est_total_catch() |
| Sparse data not detected | LOW | 1. Add sample size checks<br>2. Re-run with warnings enabled<br>3. Pool strata if necessary<br>4. Consider bootstrap variance for small samples |
| Bag limit bias undetected | HIGH | 1. Switch to access design if possible<br>2. If only roving data exists, document bias<br>3. Estimate bias magnitude via simulation<br>4. Apply correction factor with uncertainty (expert judgment) |
| Species mismatch | HIGH | 1. Re-estimate effort for correct population<br>2. Or re-estimate CPUE for correct population<br>3. Verify consistency<br>4. Document original error and correction |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Wrong estimator choice | Phase 08-02 (CPUE Estimation) | Reference tests show ratio-of-means for access, mean-of-ratios for roving |
| Missing truncation | Phase 08-03 (Roving CPUE) | Tests verify truncation applied, variance stable |
| Incorrect product variance | Phase 08-05 (Total Catch) | Reference tests match delta method formula |
| Data structure mismatch | Phase 08-01 (Interview Integration) | Tests verify designs merge cleanly |
| Sparse data issues | Phase 08-02 (CPUE Estimation) | Tests verify sample size warnings trigger |
| Bag limit bias | Phase 08-03 (Roving CPUE) | Tests verify warnings for low bag limits |
| Species mismatch | Phase 08-05 (Total Catch) | Tests verify consistency checks error appropriately |

## tidycreel-Specific Integration Concerns

Based on v0.1.0 architecture and v0.2.0 goals:

### Architectural Compatibility

**Existing v0.1.0 patterns that enable interview features:**
- Three-layer architecture (API → Orchestration → Survey) works for interview data
- Progressive validation (fail fast → warn → deep diagnostics) applies to sample size checks
- Design-centric API extends naturally: `creel_design %>% add_counts() %>% add_interviews()`
- Variance method control already exists for effort, applies to CPUE/catch

**Integration challenges:**
- Day-PSU structure for counts vs individual-PSU for interviews requires careful merging
- Shared calendar is bridge between count and interview designs
- Product variance (effort × CPUE) needs combined design, not supported in v0.1.0
- Grouped estimation must handle different grouping variables gracefully

### Implementation Sequence

**Phase 08-01 must establish:**
- `add_interviews()` function that builds interview_svy design object
- Validation that interviews match calendar dates/strata
- Interview type detection/specification mechanism
- Data structure for storing both count_svy and interview_svy in creel_design

**Phase 08-02 must implement:**
- Estimator dispatch based on interview type
- Sample size validation before estimation
- Reference tests for both ratio-of-means and mean-of-ratios
- Backward compatibility: existing effort estimation unaffected

**Phase 08-03 must handle:**
- Truncation logic in mean-of-ratios path
- Bag limit diagnostics in add_interviews()
- Clear documentation of when roving design is appropriate
- Warning/error system to prevent misuse

**Phase 08-05 must solve:**
- Design merging for covariance computation
- Delta method variance via survey::svycontrast()
- Species/targeting consistency validation
- Integration testing of full pipeline: design → counts → interviews → total catch

### Test Coverage Requirements

**Critical coverage needs (95%+ for these):**
- Estimator routing logic (access vs roving)
- Truncation filtering for roving
- Sample size validation thresholds
- Variance propagation for products
- Design compatibility checks

**Integration test scenarios:**
- Access interview → ratio-of-means → correct estimates
- Roving interview → mean-of-ratios + truncation → correct estimates
- Roving interview without truncation → error/warning
- Total catch with incompatible designs → error
- Total catch with compatible designs → correct variance
- Sparse data → warnings at appropriate thresholds
- Bag limits + roving → strong warnings

## Sources

### Creel Survey Methodology (HIGH confidence)
- [Catch Rate Estimation for Roving and Access Point Surveys - Pollock et al. 1997](https://www.researchgate.net/publication/241729832_Catch_Rate_Estimation_for_Roving_and_Access_Point_Surveys) - Mathematical proof of ratio-of-means bias for roving surveys, mean-of-ratios unbiasedness
- [Effect of Survey Design and Catch Rate Estimation on Total Catch Estimates - USGS](https://www.usgs.gov/publications/effect-survey-design-and-catch-rate-estimation-total-catch-estimates-chinook-salmon) - Comparison of estimators, bias quantification
- [Measurement Error in Angler Creel Surveys - Hoenig et al. 2015](https://www.tandfonline.com/doi/full/10.1080/02755947.2014.996689) - Sources of bias and measurement error
- [Simulating Creel Surveys - CRAN AnglerCreelSurveySimulation](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html) - Simulation evidence for truncation benefits

### Variance Estimation (HIGH confidence)
- [Sample Size Estimation for On-Site Creel Surveys - McCormick 2017](https://afspubs.onlinelibrary.wiley.com/doi/full/10.1080/02755947.2017.1342723) - Sample size requirements, variance behavior
- [Estimating Angler Effort and Catch Using Bayesian Methodology - ScienceDirect 2023](https://www.sciencedirect.com/science/article/pii/S0165783623003259) - Variance decomposition, hierarchical models
- Project file: `/Users/cchizinski2/Dev/tidycreel/inst/RATIO_ESTIMATORS_GUIDE.md` - Internal documentation of ratio estimator properties

### R Survey Package (HIGH confidence)
- survey package documentation - Delta method implementation via svycontrast()
- Project file: `/Users/cchizinski2/Dev/tidycreel/.planning/codebase/ARCHITECTURE.md` - v0.1.0 three-layer architecture
- Project file: `/Users/cchizinski2/Dev/tidycreel/.planning/PROJECT.md` - v0.2.0 scope and constraints

### Creel Survey Foundations (MEDIUM confidence - literature review)
- Project file: `/Users/cchizinski2/Dev/tidycreel/creel_foundations.md` - Survey design types, table stakes features
- Project file: `/Users/cchizinski2/Dev/tidycreel/creel_effort_estimation_methods.md` - Count-based methods (v0.1.0 foundation)

---
*Pitfalls research for: tidycreel v0.2.0 interview-based catch/harvest estimation*
*Researched: 2026-02-09*
*Confidence: HIGH - Based on peer-reviewed creel survey literature, USGS/fisheries agency technical reports, and project architecture analysis*
