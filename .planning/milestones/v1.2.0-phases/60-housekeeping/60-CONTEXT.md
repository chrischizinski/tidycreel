# Phase 60: Housekeeping - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Bring package metadata and community infrastructure into alignment with the shipped v1.1.0 state: bump DESCRIPTION version from 1.0.0 to 1.1.0, rewrite NEWS.md with accurate dated entries for v1.0.0 and v1.1.0, and confirm GitHub Discussions is accessible. No new code, no API changes.

</domain>

<decisions>
## Implementation Decisions

### Pre-1.0 dev entries in NEWS.md
- Remove the two `0.0.0.9000` development entries entirely — they contain outdated/incorrect API references and don't reflect what shipped
- NEWS.md starts clean at v1.0.0; pre-release history lives in git log only
- Do NOT add a `# tidycreel (development version)` placeholder header — add one when there is actually unreleased content to document

### Versioned entry format
- Use `## subsections` where content warrants grouping (New features, Documentation, Breaking changes)
- Flat bullet list within each subsection
- Version headers include release date: `# tidycreel X.Y.Z (YYYY-MM-DD)`

### v1.0.0 entry scope (date: 2026-03-31)
- Document the Package Website milestone only (phases 52-56): pkgdown site, custom theme, reference index, navbar, GitHub Actions deploy
- Do NOT include breaking API renames (estimate_cpue → estimate_catch_rate etc.) — these were pre-release internal changes, not public-API breaks
- No `## Breaking changes` subsection in v1.0.0

### v1.1.0 entry organization (date: 2026-04-02)
- Two subsections: `## New features` and `## Documentation`
- `## New features` covers `generate_count_times()` and the extended `survey-scheduling` vignette
- `## Documentation` covers GitHub structured issue forms and `CONTRIBUTING.md` rewrite
- Bullets are two-to-three lines with key details (not terse one-liners, not exhaustive parameter docs)
- Include key detail notes: three strategies (random, systematic, fixed), seed reproducibility, `creel_schedule` output class compatibility for `generate_count_times()`

### HOUSE-03 (GitHub Discussions)
- Verify-only: confirm Discussions tab is accessible and existing `config.yml` routing + `CONTRIBUTING.md` references are correct
- No code change required — COMM-05 was resolved by repo owner on 2026-04-03
- Plan includes a verification checklist step, not a file edit step

### Claude's Discretion
- Exact wording of NEWS bullet points (within the two-to-three line guideline)
- Order of bullets within each subsection
- Whether v1.0.0 warrants a `## New features` subsection label or just plain bullets (given it's all website infrastructure)

</decisions>

<specifics>
## Specific Ideas

- v1.0.0 entry should mention the live site URL: https://chrischizinski.github.io/tidycreel
- v1.1.0 `generate_count_times()` bullet should mention: three strategies, seed reproducibility, returns `creel_schedule` (compatible with `write_schedule()`)
- v1.1.0 vignette bullet should note: full pre/post-season narrative added (generate_count_times → validate_design → check_completeness → season_summary)
- v1.1.0 issue forms bullet should mention: `blank_issues_enabled: false` routing how-to questions to Discussions

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DESCRIPTION`: `Version: 1.0.0` — single field to bump to `1.1.0`
- `NEWS.md`: Currently has two dev-era `0.0.0.9000` entries to be deleted and replaced
- `.github/config.yml`: Already has `blank_issues_enabled: false` — no change needed

### Established Patterns
- pkgdown auto-renders NEWS.md as the Changelog page — standard `# pkgName X.Y.Z (date)` headers are required for correct rendering
- `## subsection` headers in NEWS render as collapsible sections on pkgdown

### Integration Points
- No function changes — this phase touches only `DESCRIPTION`, `NEWS.md`, and verification of GitHub repo settings
- pkgdown site will auto-rebuild on push to main (GitHub Actions); updated NEWS.md will appear at /news/

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 60-housekeeping*
*Context gathered: 2026-04-03*
