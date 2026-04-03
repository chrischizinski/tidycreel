---
phase: 59-community-health-files
plan: "02"
subsystem: community
tags: [contributing, documentation, github-discussions, reprex, issue-templates]
dependency_graph:
  requires: []
  provides: [CONTRIBUTING.md contributor guidance]
  affects: [community onboarding]
tech_stack:
  added: []
  patterns: [GitHub Discussions for questions, structured issue forms for bugs/features, reprex for bug reports]
key_files:
  created: []
  modified:
    - CONTRIBUTING.md
decisions:
  - Getting Help moved to top of CONTRIBUTING.md so first-time visitors see it before technical standards
  - reprex code example uses tidycreel function call with NA data to model a realistic minimal bug report
metrics:
  duration: "68s"
  completed: "2026-04-02"
  tasks_completed: 1
  files_modified: 1
---

# Phase 59 Plan 02: CONTRIBUTING.md Community Guidance Summary

CONTRIBUTING.md rewritten to direct questions to GitHub Discussions and explain issue filing, reprex writing, and PR submission with tidycreel coding standards preserved.

## What Was Built

Rewrote `CONTRIBUTING.md` (189 lines -> 233 lines) to serve external contributors end-to-end:

- **Getting Help** section moved to the top (before Development Principles) with the full URL https://github.com/chrischizinski/tidycreel/discussions and a clear statement that how-to questions go to Discussions, not Issues
- **Filing Issues** section added between Getting Help and Development Principles, with two subsections:
  - *Bug Reports*: explains the structured form fields (survey type, version, expected vs actual, reprex), includes a self-contained R code example showing `library(tidycreel)`, minimal data, the failing call, and expected error output
  - *Feature Requests*: explains the form fields (problem statement, proposed solution, use case, affected survey types)
- **Pull Request Guidelines** updated with "file an issue first for non-trivial changes" guidance before the existing checklist
- Duplicate "Getting Help" section at the bottom removed
- All existing technical content preserved unchanged: Vectorization-First Policy, Statistical Foundations, Tidyverse Style, Code Quality, Testing Requirements (with testthat example), Performance Expectations, Package Architecture, Recognition

## Verification Results

```
GitHub Discussions count: 1   (>= 1 PASS)
bug report count:         3   (>= 1 PASS)
feature request count:    4   (>= 1 PASS)
reprex count:             4   (>= 1 PASS)
discussions count:        1   (>= 1 PASS)
line count:             233   (>= 180 PASS)
```

Full URL present: `https://github.com/chrischizinski/tidycreel/discussions`

## Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Rewrite CONTRIBUTING.md with issue filing, reprex, PR, and Discussions guidance | 4e36dc9 | CONTRIBUTING.md |

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- CONTRIBUTING.md exists: FOUND
- Commit 4e36dc9 exists: FOUND
