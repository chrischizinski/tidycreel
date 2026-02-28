# Phase 1: Project Setup & Foundation - Context

**Gathered:** 2026-01-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Initialize R package structure with automated quality gates configured. This phase establishes the foundational infrastructure: package scaffolding, CI/CD pipeline, code quality enforcement, and data validation schemas. Development features come in later phases.

</domain>

<decisions>
## Implementation Decisions

### CI/CD Pipeline Setup
- Test against latest R release only (not devel or oldrel)
- Full cross-platform testing: Linux + Windows + macOS
- Aggressive package caching between CI runs for speed
- README.Rmd created in initial scaffolding

### Code Quality Enforcement
- Use tidyverse lintr defaults (comprehensive style rules)
- Standard tidyverse styler formatting without modifications

### Package Scaffolding Approach
- Use usethis helpers for everything (conventional, fast)
- MIT License for package
- Create README.Rmd immediately in Phase 1

### Data Schema Validation
- Define schemas as R lists/functions (native, testable)
- Use checkmate library for validation
- Detailed error messages that explain both what failed and how to fix
- Define both calendar and count data schemas in Phase 1

### Claude's Discretion
- Coverage reporting strategy (track vs enforce thresholds)
- Pre-commit hook blocking behavior (strict vs warn vs auto-fix)
- R CMD check note handling (treat as failures vs allow)
- Additional directory structure beyond required R package layout
- Specific lintr rule adjustments within tidyverse defaults
- Exact implementation of schema validators

</decisions>

<specifics>
## Specific Ideas

No specific requirements — standard R package infrastructure approaches are appropriate.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-project-setup-foundation*
*Context gathered: 2026-01-30*
