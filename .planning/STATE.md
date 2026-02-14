# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-14)

**Core value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals
**Current focus:** v0.3.0 Incomplete Trips & Validation

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements for v0.3.0
Last activity: 2026-02-14 — Milestone v0.3.0 started

Progress: [░░░░░░░░░░░░░░░░░░░░] 0% (requirements definition)

## Accumulated Context

### Research Summary (v0.3.0 Planning Session)

**Key findings from literature and Colorado C-SAP:**
- Roving-access design (counts + complete trips only) is scientifically validated approach (Pollock et al.)
- Colorado C-SAP uses ONLY complete trips for estimation, requires ≥10% complete trip interviews
- Pooling complete + incomplete trips is statistically invalid (different sampling probabilities)
- Mean-of-ratios with truncation (20-30 min threshold) can work for incomplete trips BUT requires validation
- Incomplete trip interviews suffer from length-of-stay bias (longer trips oversampled)
- Nonstationary catch rates (catch rate changes during trip) cause bias in incomplete trip estimates

**Decision for v0.3.0:**
- Default to complete trips only (follows Colorado C-SAP best practice)
- Support incomplete trip estimation as diagnostic/research mode with clear warnings
- Never auto-pool complete + incomplete (scientifically invalid)

### Pending Todos

- #1: Simulation study for complete vs. incomplete trip pooling bias (post-v0.3.0)

### Blockers/Concerns

None currently.
