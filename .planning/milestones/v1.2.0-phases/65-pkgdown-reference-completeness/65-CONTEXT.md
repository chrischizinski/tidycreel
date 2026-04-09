# Phase 65: pkgdown Reference Completeness & GLMM Documentation Polish - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix 4 missing pkgdown reference entries (`attach_count_times`, `estimate_effort_aerial_glmm`, `example_aerial_glmm_counts`), add a "Downstream Estimation" section to `vignettes/aerial-glmm.Rmd` demonstrating the full aerial pipeline through catch rate and total catch, and close DOC-01 tracking in `61-01-SUMMARY.md` and `REQUIREMENTS.md`.

No new functions, datasets, or vignettes are in scope — this is purely gap closure for v1.2.0 audit findings.

</domain>

<decisions>
## Implementation Decisions

### E2E vignette section content
- Add `add_interviews(design, example_aerial_interviews)` inline at the start of the new section — self-contained, shows the real workflow
- Heading: `## Downstream Estimation`
- Brief bridge prose only (1-2 sentences): GLMM effort feeds downstream estimators, then the code
- Show both `estimate_catch_rate(design)` and `estimate_total_catch(design)` — satisfies success criterion exactly
- Use `eval=TRUE` — consistent with the rest of the vignette

### Vignette section placement
- Insert the new `## Downstream Estimation` section after `## GLMM Effort Estimation` and before `## Comparison: Simple vs. GLMM Estimator`
- Do not replace or remove the Comparison section

### pkgdown reference entry ordering
- `attach_count_times` → inserted after `generate_count_times` in the Scheduling contents block (workflow sequence: generate_schedule → generate_count_times → attach_count_times)
- `estimate_effort_aerial_glmm` → inserted after `estimate_effort` in the Estimation contents block (groups both effort estimators together)
- `example_aerial_glmm_counts` → inserted after `example_aerial_interviews` in the Example Datasets contents block (groups all aerial datasets together)

### DOC-01 tracking
- Add `requirements-completed: [DOC-01]` to the frontmatter of `.planning/phases/61-survey-tidycreel-vignette/61-01-SUMMARY.md`
- Change `DOC-01` checkbox from `[ ]` to `[x]` in `REQUIREMENTS.md`

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `example_aerial_interviews`: existing dataset for aerial interview data — use with `add_interviews()` in the new E2E section
- `glmm_result`: already computed in the vignette — the new section builds on it directly

### Established Patterns
- Vignette style (phases 61–64): narrative prose + named R chunks, `eval=TRUE` where data supports it, `eval=FALSE` only for production-only patterns
- pkgdown sections already organized by function family with logical workflow ordering within each block

### Integration Points
- `_pkgdown.yml` reference section — 3 entries need insertion at specific positions
- `vignettes/aerial-glmm.Rmd` — 1 new section inserted between line ~103 (end of GLMM Effort Estimation) and line ~129 (start of Comparison)
- `.planning/phases/61-survey-tidycreel-vignette/61-01-SUMMARY.md` — frontmatter addition
- `.planning/REQUIREMENTS.md` — checkbox change for DOC-01

</code_context>

<specifics>
## Specific Ideas

- No specific styling or visual requirements — match existing vignette conventions
- The "Downstream Estimation" section should NOT re-explain what `estimate_catch_rate()` or `estimate_total_catch()` do — those are covered in other vignettes; just show them being called

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 65-pkgdown-reference-completeness*
*Context gathered: 2026-04-05*
