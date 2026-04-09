# Phase 62: Estimation Pipeline Vignettes - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Create two new standalone vignettes — one for the counts → effort pipeline and one for the interview → catch rate → total catch pipeline — that explain the statistical mechanics conceptually. These complement the existing `flexible-count-estimation.Rmd` and `interview-estimation.Rmd` (which are API workflow demos) rather than replacing them.

</domain>

<decisions>
## Implementation Decisions

### Relationship to existing vignettes
- Two new standalone `.Rmd` files, not revisions to existing vignettes
- Existing `flexible-count-estimation.Rmd` and `interview-estimation.Rmd` stay as API workflow demos unchanged
- Each new vignette cross-links to its corresponding workflow vignette at the end (e.g., "For the full API walkthrough, see flexible-count-estimation")
- New vignettes are the "why it works" counterparts to the existing "how to use it" demos

### pkgdown placement
- Create a new "Statistical Methods" section in `_pkgdown.yml` for these two vignettes
- Signals that these are conceptually different in character from workflow demos
- Both new vignettes go in this new section together

### Math presentation
- **Style**: Annotated equations + plain-language gloss — show the formula (LaTeX), then immediately explain each symbol in a sentence
- **Worked numerics**: Both vignettes include a traced numeric example — show the raw numbers, compute the formula step by step, then show the same result from the R function output (confirms the math)
- **ROM vs MOR**: Side-by-side comparison using identical example data — show both estimators' calculations and output, then explain when each is appropriate and why they diverge

### Example data
- Use small inline constructed data (3–5 rows, round numbers) so readers can follow the arithmetic by hand
- Do NOT use `example_*` package datasets for the math trace sections — inline data keeps the numbers transparent
- If a full-workflow demo is shown at the end, `example_*` datasets may be used

### Counts → effort vignette structure
- Build up progressively: single count per day (simple case) first, then multiple counts per day (Rasmussen variance), then progressive count estimator
- Progressive count estimator gets its **own section** (not a subsection of multiple counts) — it is mechanically distinct
- Rasmussen two-stage variance section: show se_between and se_within computed step-by-step on a numeric example, then confirm with `estimate_effort()` output

### Interview → catch pipeline structure
- ROM vs MOR: side-by-side comparison on identical inline data, print both results, then explain when each is appropriate
- Delta method: brief intuition paragraph (linear approximation of variance for a ratio) + annotated formula + worked interpretation of the decomposed variance output
- Cross-link at end to `interview-estimation.Rmd` for the full API walkthrough

### Audience
- **Assumed knowledge**: Creel biologist familiar with creel surveys — knows what they're estimating, does not know two-stage sampling theory or ratio estimators
- Explain the statistics from first principles in plain language — do not assume familiarity with PSUs, HT estimators, or delta method
- **Citations**: Inline citations (Rasmussen 1994) with a `## References` section at the end of each vignette

### Claude's Discretion
- Exact vignette file names (suggest `effort-pipeline.Rmd` and `catch-pipeline.Rmd` or similar)
- Specific numeric values used in inline examples (as long as they are round and traceable)
- Section ordering within each vignette beyond the constraints above
- Exact wording of plain-language glosses for each formula symbol

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bus-route-equations.Rmd`: Established pattern for LaTeX-heavy vignettes in this package — use as style reference for equation blocks
- `flexible-count-estimation.Rmd`: Already contains some statistical explanation (Rasmussen, progressive count); new vignette goes deeper on the math but is conceptually distinct
- `interview-estimation.Rmd`: Covers the API workflow; new vignette is the statistical mechanics companion
- `example_calendar`, `example_counts`, `example_interviews`: Available as package datasets if needed for end-of-vignette workflow demos

### Established Patterns
- Vignettes use `rmarkdown::html_vignette` output with standard `knitr::opts_chunk$set(collapse = TRUE, comment = "#>")` setup
- LaTeX math works via `$...$` (inline) and `$$...$$` (display) in `.Rmd` files
- pkgdown renders vignettes as articles; LaTeX renders correctly in the HTML output
- Section headers use `##` for major sections, `###` for subsections

### Integration Points
- `_pkgdown.yml` `articles:` block needs a new "Statistical Methods" section with both new vignette slugs
- New `.Rmd` files go in `vignettes/`
- `DESCRIPTION` `Suggests:` does not need changes (no new package dependencies expected)

</code_context>

<specifics>
## Specific Ideas

- The Rasmussen variance worked example should show a table: day | count_1 | count_2 | within-day mean | between-day contribution | within-day contribution — makes the decomposition visually clear
- For delta method: show the variance formula as `Var(TC) = effort² × Var(CPUE) + CPUE² × Var(effort) + cross-term` and annotate each term's interpretation (effort uncertainty contribution, CPUE uncertainty contribution)
- Cross-link phrasing: "For the API walkthrough showing how to use these functions on your own data, see [Flexible Count Estimation](flexible-count-estimation.html)"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 62-estimation-pipeline-vignettes*
*Context gathered: 2026-04-03*
