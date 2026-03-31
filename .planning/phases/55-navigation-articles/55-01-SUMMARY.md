---
phase: 55-navigation-articles
plan: 01
subsystem: ui
tags: [pkgdown, navbar, vignettes, articles, navigation]

# Dependency graph
requires:
  - phase: 54-home-page-reference
    provides: "_pkgdown.yml with reference: block and site theme already configured"
  - phase: 53-foundation-theme
    provides: "pkgdown site scaffold with bslib theme and brand colors"
provides:
  - "Native pkgdown articles: block with five sections (four navbar-promoted, one index-only)"
  - "News/Changelog navbar link rendering NEWS.md as a browsable version history page"
  - "Four workflow article dropdowns in top navbar: Survey Types, Estimation, Reporting & Planning"
  - "Stale manual navbar components: stub removed; replaced by native pkgdown article routing"
affects: [56-deploy-cicd]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "pkgdown articles: sections with navbar: field promote sections to dropdown menus"
    - "tidycreel intro vignette auto-promoted via intro navbar component — not duplicated in articles: block navbar field"
    - "Technical reference vignettes (bus-route-equations) placed in index-only section (no navbar: field)"
    - "news: block with cran_dates: false renders NEWS.md without CRAN release dates"

key-files:
  created: []
  modified:
    - "_pkgdown.yml"

key-decisions:
  - "tidycreel.Rmd auto-promoted via intro component; placed in index-only Get Started section to avoid duplicate navbar entry"
  - "bus-route-equations placed in index-only Reference & Equations section — it is a technical derivation, not a workflow guide"
  - "news: block uses one_page: true so all changelog entries appear on a single scrollable page"

patterns-established:
  - "navbar.structure.left: [intro, reference, articles, news] — canonical navbar order for tidycreel pkgdown site"
  - "Each workflow category (Survey Types, Estimation, Reporting & Planning) maps to one articles: section with matching navbar: field"

requirements-completed: [NAV-01, NAV-02, NAV-03]

# Metrics
duration: ~10min
completed: 2026-03-30
---

# Phase 55 Plan 01: Navigation Articles Summary

**Replaced stale manual navbar href stub with native pkgdown articles: sections, adding four workflow dropdown groups and a News/Changelog link — all verified 404-free**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-27T16:37:38Z (approx)
- **Completed:** 2026-03-30
- **Tasks:** 2 (1 auto + 1 checkpoint:human-verify)
- **Files modified:** 1

## Accomplishments

- Removed stale `components: articles:` navbar stub that contained broken hrefs to non-existent pages
- Added native `articles:` block with five sections: Get Started (index-only), Survey Types, Estimation, Reporting & Planning (all navbar-promoted), Reference & Equations (index-only)
- Updated `navbar.structure.left` to `[intro, reference, articles, news]` and added `news:` block
- `pkgdown::check_pkgdown()` passed with 0 errors; human verified all navbar links resolve with no 404s

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace navbar stub with native articles: sections and add news** - `4b6674e` (feat)
2. **Task 2: Human verification checkpoint** - approved (no commit — verification only)

**Plan metadata:** (see final docs commit below)

## Files Created/Modified

- `_pkgdown.yml` — Removed `components:` stub, added `articles:` block with 5 sections (4 navbar-promoted, 1 index-only), added `news:` block, updated `navbar.structure.left`

## Decisions Made

- `tidycreel.Rmd` auto-promoted via the `intro` navbar component; placed only in an index-only "Get Started" section in `articles:` to avoid a duplicate dropdown entry
- `bus-route-equations` placed in index-only "Reference & Equations" section — technical derivation, not a workflow guide that belongs in a navbar dropdown
- `news: one_page: true` renders the full changelog on a single scrollable page without CRAN release date annotations

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- pkgdown site has complete, working navigation with four workflow article dropdowns, a Reference link, a News/Changelog link, and no 404s
- Ready for Phase 56 (deploy CI/CD) — the GitHub Actions pkgdown.yaml workflow can now be wired to build and publish this fully-configured site

---
*Phase: 55-navigation-articles*
*Completed: 2026-03-30*
