# Phase 85: Mark-Recapture Harvest Estimators - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-04
**Phase:** 085-mark-recapture
**Areas discussed:** Schnabel input contract, estimate_mr_harvest() coupling, Output tibble structure, Petersen m ≥ 7 guard

---

## Schnabel Input Contract

| Option | Description | Selected |
|--------|-------------|----------|
| Parallel vectors | Same M/n/m args as Chapman/Petersen; scalar for single-occasion, vector for Schnabel | ✓ |
| Data frame / tibble | `data` arg with columns M/n/m; tidyverse style but inconsistent with scalar path | |

**User's choice:** Parallel vectors (Recommended)

### Schnabel Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Unequal vector lengths | Always an error — included in guard suite | auto |
| Fewer than 2 occasions | k < 2 with method = "schnabel" → abort | auto |
| First M != 0 | Enforce or document? | |
| You decide | Claude picks validation checks from Schnabel formula requirements | ✓ |

**User's choice:** You decide — Claude uses standard mathematical guards.

---

## estimate_mr_harvest() Coupling

| Option | Description | Selected |
|--------|-------------|----------|
| creel_estimates object | Takes result from estimate_angler_n(); auto-extracts N_hat/se_N | ✓ |
| Bare scalars | N_hat, se_N, harvest_rate — standalone but requires manual extraction | |

**User's choice:** creel_estimates object (Recommended)

### harvest_rate uncertainty

| Option | Description | Selected |
|--------|-------------|----------|
| Scalar rate only | harvest_rate is a scalar; N_hat uncertainty only in delta propagation | ✓ |
| Optional se_rate | Two-source delta method; NULL fallback to N_hat-only | |

**User's choice:** Scalar rate only (Recommended) — se_rate propagation deferred to future milestone.

---

## Output Tibble Structure

### estimate_angler_n()

| Option | Description | Selected |
|--------|-------------|----------|
| Single N_hat row | parameter = "N_hat", estimate, se, ci_lower, ci_upper | ✓ |
| N_hat + diagnostics | Additional rows for f (recapture fraction), R (recaptures used) | |

**User's choice:** Single N_hat row (Recommended)

### estimate_mr_harvest()

| Option | Description | Selected |
|--------|-------------|----------|
| Single harvest row | parameter = "total_harvest", estimate, se, ci_lower, ci_upper | ✓ |
| Harvest + N_hat rows | Carries N_hat through but duplicates data already in angler_n result | |

**User's choice:** Single harvest row (Recommended)

---

## Petersen m ≥ 7 Guard

| Option | Description | Selected |
|--------|-------------|----------|
| Hard abort | cli_abort() with suggestion to use method = "chapman" | ✓ |
| Warning + proceed | cli_warn() then continue; allows override but complicates tests | |
| You decide | Claude picks enforcement based on existing MR-04 abort convention | |

**User's choice:** Hard abort (Recommended)

---

## Claude's Discretion

- Schnabel validation guards beyond unequal-length and k < 2 checks (e.g., m[k] > min(M[k], n[k]), non-positive values)
- File placement: R/creel-estimates-mark-recapture.R
- method string values stored in creel_estimates objects
- variance_method string values per estimator

## Deferred Ideas

- Harvest-rate SE propagation (two-source delta method for estimate_mr_harvest()) — future milestone
- Jolly-Seber open-population estimator (MR-F01) — requires new S3 class, deferred from v1.6.0
