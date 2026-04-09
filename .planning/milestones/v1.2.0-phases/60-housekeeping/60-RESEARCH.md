# Phase 60: Housekeeping - Research

**Researched:** 2026-04-03
**Domain:** R package metadata (DESCRIPTION, NEWS.md) and GitHub community infrastructure
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Remove both `0.0.0.9000` development entries from NEWS.md entirely; pre-release history stays in git log only
- Do NOT add a `# tidycreel (development version)` placeholder header until there is unreleased content to document
- Use `## subsections` where content warrants grouping; flat bullet list within each subsection
- Version headers include release date: `# tidycreel X.Y.Z (YYYY-MM-DD)`
- v1.0.0 entry date: 2026-03-31; scope: Package Website milestone only (phases 52-56) — pkgdown site, custom theme, reference index, navbar, GitHub Actions deploy
- No `## Breaking changes` subsection in v1.0.0 entry
- v1.1.0 entry date: 2026-04-02; two subsections: `## New features` and `## Documentation`
- `## New features` covers `generate_count_times()` and the extended `survey-scheduling` vignette
- `## Documentation` covers GitHub structured issue forms and `CONTRIBUTING.md` rewrite
- Bullets are two-to-three lines with key details (not terse one-liners, not exhaustive parameter docs)
- `generate_count_times()` bullet must mention: three strategies, seed reproducibility, `creel_schedule` output compatibility with `write_schedule()`
- HOUSE-03: verify-only — confirm Discussions tab is accessible and `config.yml` routing + `CONTRIBUTING.md` references are correct; no file edits
- v1.0.0 entry should mention the live site URL: https://chrischizinski.github.io/tidycreel
- v1.1.0 vignette bullet should note: full pre/post-season narrative (generate_count_times → validate_design → check_completeness → season_summary)
- v1.1.0 issue forms bullet should mention: `blank_issues_enabled: false` routing how-to questions to Discussions

### Claude's Discretion

- Exact wording of NEWS bullet points (within the two-to-three line guideline)
- Order of bullets within each subsection
- Whether v1.0.0 warrants a `## New features` subsection label or just plain bullets (given it's all website infrastructure)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HOUSE-01 | Package version reflects shipped state (`1.1.0` in DESCRIPTION — backfill for missed bump) | Single `Version:` field edit in DESCRIPTION; confirmed current value is `1.0.0` |
| HOUSE-02 | NEWS.md has accurate entries for v1.0.0 and v1.1.0 with feature lists | Full rewrite: delete two stale dev entries, write two versioned entries with subsections per locked decisions |
| HOUSE-03 | GitHub Discussions blocker cleared (COMM-05 resolved) | config.yml already has `blank_issues_enabled: false` + Discussions link; verify-only checklist step |
</phase_requirements>

---

## Summary

Phase 60 is a pure metadata and documentation housekeeping phase — no R code changes, no API surface changes. It has exactly three deliverables: a one-field version bump in DESCRIPTION, a full rewrite of NEWS.md, and a verification checklist for GitHub Discussions.

The current DESCRIPTION has `Version: 1.0.0`. Bumping to `1.1.0` is a one-line edit. The current NEWS.md contains two stale `0.0.0.9000` development entries that reference APIs and designs that never shipped; these must be deleted entirely and replaced with two clean versioned entries: v1.0.0 (2026-03-31) covering the Package Website milestone, and v1.1.0 (2026-04-02) covering `generate_count_times()` and community documentation. HOUSE-03 is already resolved: `.github/ISSUE_TEMPLATE/config.yml` has `blank_issues_enabled: false` with a Discussions contact link; no file edits are required, only a runtime verification that the Discussions tab is live.

**Primary recommendation:** Write the two NEWS entries directly following the locked decisions in CONTEXT.md; bump `Version:` in DESCRIPTION; close out HOUSE-03 with a verification step in the plan's success criteria.

---

## Standard Stack

### Core

| Tool / File | Version / Location | Purpose | Why Standard |
|-------------|-------------------|---------|--------------|
| `DESCRIPTION` | `/DESCRIPTION` (root) | Package metadata including `Version:` field | R packaging standard (CRAN / devtools convention) |
| `NEWS.md` | `/NEWS.md` (root) | Human-readable changelog | pkgdown renders it as `/news/` automatically when format is `# pkgName X.Y.Z (date)` |
| `.github/ISSUE_TEMPLATE/config.yml` | Already exists | Issue routing + Discussions link | GitHub community health standard |

### Established Format Rules (confirmed from existing repo + pkgdown docs)

- `# tidycreel X.Y.Z (YYYY-MM-DD)` — top-level version header; pkgdown parses this to create per-version sections on the Changelog page
- `## Subsection` — second-level headers within a version; pkgdown renders as collapsible sections
- Bullet items: `* text` (asterisk + space) — R/pkgdown NEWS convention; plain hyphens also accepted
- Version string in DESCRIPTION must be exactly `1.1.0` (three-part numeric; no `.9000` dev suffix)

### No Additional Dependencies

This phase introduces no new packages or tools. All edits are to plain text files.

---

## Architecture Patterns

### Recommended NEWS.md Structure for This Phase

```
# tidycreel 1.1.0 (2026-04-02)

## New features

* [generate_count_times() bullet — 2-3 lines]

* [survey-scheduling vignette bullet — 2-3 lines]

## Documentation

* [Issue forms bullet — 2-3 lines]

* [CONTRIBUTING.md bullet — 2-3 lines]

# tidycreel 1.0.0 (2026-03-31)

[Either plain bullets or a ## New features subsection — Claude's discretion]

* [pkgdown site bullet]
* [theme/reference/navbar bullet]
* [GitHub Actions deploy bullet]
```

Notes:
- Newest version appears at the top (standard changelog convention)
- No trailing `# tidycreel (development version)` header — locked decision
- No `0.0.0.9000` entries — locked decision

### DESCRIPTION Version Bump Pattern

```
Version: 1.0.0   →   Version: 1.1.0
```

Single field, single line. No other DESCRIPTION fields change in this phase.

### Anti-Patterns to Avoid

- **Do not add a development version header** (`# tidycreel (development version)`) — explicitly prohibited by locked decisions until unreleased content exists
- **Do not add `## Breaking changes` to v1.0.0** — locked decision; pre-release API renames are not public-facing breaks
- **Do not include pre-release content in NEWS** — the `0.0.0.9000` entries reference removed APIs and wrong function names; they would confuse users reading the changelog
- **Do not use terse one-liner bullets** — two-to-three lines with key details is required per locked decisions
- **Do not edit config.yml for HOUSE-03** — it is already correct; only verification is needed

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| NEWS.md rendering | Custom changelog script | pkgdown's built-in NEWS parser | pkgdown auto-renders `/news/` from standard `# pkg X.Y.Z (date)` headers on every push to main |
| Version verification | Manual grep of DESCRIPTION | `packageVersion("tidycreel")` in R console | Standard R check; also covered by `devtools::check()` |

---

## Common Pitfalls

### Pitfall 1: Non-standard Version Header Format Breaks pkgdown Rendering

**What goes wrong:** pkgdown silently fails to parse version sections if the header deviates from `# pkgName X.Y.Z (date)` — version sections merge or disappear on the Changelog page.
**Why it happens:** pkgdown uses a regex that requires the exact format; extra text (e.g., `# tidycreel v1.1.0`) or missing date breaks the match.
**How to avoid:** Use exactly `# tidycreel 1.1.0 (2026-04-02)` — no "v" prefix, parenthesized date, package name matching `Package:` in DESCRIPTION.
**Warning signs:** `/news/` page on pkgdown site shows all content under one section after deploy.

### Pitfall 2: Version String Format in DESCRIPTION

**What goes wrong:** `packageVersion("tidycreel")` returns unexpected output or `devtools::check()` warns if `Version:` contains non-numeric segments outside of a `.9000` dev suffix.
**Why it happens:** R's version comparison uses `numeric_version()`; a value like `1.1.0.9000` is valid for dev versions but `1.1.0` is the correct released form.
**How to avoid:** Use `1.1.0` exactly — three-part numeric, no suffix.

### Pitfall 3: Bullet Symbol Inconsistency

**What goes wrong:** Mixing `*` and `-` bullet styles within NEWS.md works in raw markdown but can produce inconsistent rendering in pkgdown.
**Why it happens:** pkgdown's NEWS renderer normalizes most cases but has historically been sensitive to mixed styles.
**How to avoid:** Use `*` (asterisk + space) consistently throughout, which is the canonical R NEWS convention.

---

## Code Examples

### DESCRIPTION Version Field (after edit)

```
# Source: DESCRIPTION (root of repo)
Version: 1.1.0
```

### NEWS.md Header Format (verified pattern)

```markdown
# Source: pkgdown NEWS rendering convention
# tidycreel 1.1.0 (2026-04-02)

## New features

* `generate_count_times()` adds three sampling strategies for allocating
  interview periods within a survey day: random, systematic, and fixed-interval.
  Supports a `seed` argument for reproducibility; returns a `creel_schedule`
  object compatible with `write_schedule()`.

* The `survey-scheduling` vignette now covers the full pre- and post-season
  workflow: `generate_count_times()` through `validate_design()`,
  `check_completeness()`, and `season_summary()`.

## Documentation

* GitHub issue templates now use structured forms with
  `blank_issues_enabled: false`, routing how-to questions to GitHub Discussions
  to keep answers searchable.

* `CONTRIBUTING.md` has been rewritten with current workflow guidance,
  contribution types, and community norms.

# tidycreel 1.0.0 (2026-03-31)

* Launched the pkgdown documentation site at
  https://chrischizinski.github.io/tidycreel with a custom theme, full
  function reference index, and structured navbar.

* Added GitHub Actions workflow to deploy the pkgdown site automatically on
  push to main.
```

Note: Exact bullet wording is Claude's discretion per locked decisions. The above draft is a starting point for the planner.

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|-----------------|-------|
| `0.0.0.9000` dev entries with stale API refs | Clean versioned entries starting at `1.0.0` | Locked decision — delete dev entries entirely |
| `Version: 1.0.0` in DESCRIPTION | `Version: 1.1.0` | Single-line bump |

**Deprecated/outdated in this repo:**
- Both `0.0.0.9000` NEWS entries: reference `est_effort.*` dispatch names, `as_day_svydesign()`, `est_cpue()` — none of these match the current exported API and will confuse users

---

## Open Questions

1. **v1.0.0 subsection label**
   - What we know: All v1.0.0 content is website/infrastructure (pkgdown site, GitHub Actions) — not user-facing function changes
   - What's unclear: Whether a `## New features` label is appropriate for infra-only content, or plain bullets read better
   - Recommendation: Claude's discretion per CONTEXT.md — either approach is acceptable; plain bullets with no subsection label may read more naturally for infrastructure-only content

---

## Validation Architecture

> `workflow.nyquist_validation` is absent from `.planning/config.json` — treated as enabled. However, this phase contains no R code changes; all deliverables are plain-text file edits and a GitHub UI verification. Automated test coverage is not applicable.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat 3 |
| Config file | `tests/testthat.R` |
| Quick run command | `Rscript -e "devtools::test()"` |
| Full suite command | `Rscript -e "devtools::check()"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| HOUSE-01 | `packageVersion("tidycreel")` returns `"1.1.0"` | smoke | `Rscript -e "stopifnot(packageVersion('tidycreel') == '1.1.0')"` | Run after install; no test file needed |
| HOUSE-02 | NEWS.md has versioned entries for v1.0.0 and v1.1.0 | manual | Inspect `NEWS.md` directly; confirm pkgdown renders `/news/` correctly | No automated test applicable |
| HOUSE-03 | GitHub Discussions tab is accessible | manual | Navigate to https://github.com/chrischizinski/tidycreel/discussions | External GitHub UI state; not automatable |

### Sampling Rate

- Per task commit: inspect modified files directly (no test run required — no code changes)
- Per wave merge: `Rscript -e "devtools::check()"` to confirm DESCRIPTION parses cleanly
- Phase gate: All three success criteria verified before `/gsd:verify-work`

### Wave 0 Gaps

None — existing test infrastructure covers package-level checks; no new test files needed for this phase.

---

## Sources

### Primary (HIGH confidence)

- Direct file inspection: `/DESCRIPTION` — confirmed `Version: 1.0.0` (single field to bump)
- Direct file inspection: `/NEWS.md` — confirmed two stale `0.0.0.9000` entries to delete
- Direct file inspection: `/.github/ISSUE_TEMPLATE/config.yml` — confirmed `blank_issues_enabled: false` + Discussions link already in place
- CONTEXT.md (`60-CONTEXT.md`) — all locked decisions and specifics confirmed

### Secondary (MEDIUM confidence)

- pkgdown NEWS rendering convention: `# pkg X.Y.Z (date)` header format required for correct per-version sections — well-established convention documented in pkgdown docs and consistent with how existing pkgdown sites in R ecosystem render changelogs

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- DESCRIPTION edit: HIGH — single field, confirmed current value, target value locked
- NEWS.md rewrite: HIGH — all content decisions locked in CONTEXT.md; format rules confirmed from existing file + pkgdown convention
- HOUSE-03 verification: HIGH — config.yml already correct; GitHub Discussions live per project memory

**Research date:** 2026-04-03
**Valid until:** Stable indefinitely — no external dependencies; all decisions are locked
