# Requirements: tidycreel

**Defined:** 2026-03-24
**Core Value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals

## v1.0.0 Requirements

Requirements for the Package Website milestone. Each maps to roadmap phases.

### Hex Sticker (STICKER)

- [ ] **STICKER-01**: User can generate a refreshed hex sticker with a professional color palette that matches the website theme
- [ ] **STICKER-02**: Hex sticker is produced by a reproducible R script (`inst/hex/sticker.R`) so it can be re-rendered when branding changes
- [ ] **STICKER-03**: Output is a retina-quality PNG (1200×1390px, 300dpi) written to `man/figures/logo.png`

### Foundation (FOUND)

- [x] **FOUND-01**: `pkgdown` added to DESCRIPTION `Suggests` and `docs/` added to `.gitignore`
- [x] **FOUND-02**: `_pkgdown.yml` created with Bootstrap 5, site URL, and metadata fields populated
- [x] **FOUND-03**: `pkgdown::check_pkgdown()` passes with 0 warnings

### Theme & Design (THEME)

- [x] **THEME-01**: Professional color palette set via `template.bslib` variables in `_pkgdown.yml`
- [x] **THEME-02**: Custom Google Fonts configured for heading, body, and code text
- [x] **THEME-03**: `pkgdown/extra.css` created with structural CSS (navbar, code blocks, callout accent, typography)
- [x] **THEME-04**: `pkgdown/extra.css` extended with hero section spacing and badge styling

### Home Page (HOME)

- [x] **HOME-01**: README.md polished to serve as a compelling home page (description, install, quick example)
- [x] **HOME-02**: Status badges displayed (R CMD check, pkgdown deploy status)
- [x] **HOME-03**: Feature highlights section showing survey types and key capabilities

### Navigation (NAV)

- [x] **NAV-01**: Workflow-driven articles navbar: Get Started | Survey Types | Estimation | Reporting & Planning
- [x] **NAV-02**: Reference link in top navbar for direct function access
- [x] **NAV-03**: NEWS.md rendered as a Changelog page on the site

### Reference (REF)

- [x] **REF-01**: Reference index with all functions grouped by logical topic
- [x] **REF-02**: Every exported function appears in at least one reference group (no orphans)

### Deployment (DEPLOY)

- [ ] **DEPLOY-01**: `.github/workflows/pkgdown.yaml` auto-builds and deploys on push to `main`
- [ ] **DEPLOY-02**: `gh-pages` orphan branch initialized and GitHub Pages configured to serve from it
- [ ] **DEPLOY-03**: PRs trigger a build (no deploy) to catch `_pkgdown.yml` errors before merge

## Future Requirements

### v1.1.0+

- Custom domain (e.g., tidycreel.io) — deferred; GitHub Pages URL sufficient for launch
- Dark mode toggle — deferred; accessibility and maintenance complexity
- Search integration (Algolia DocSearch) — deferred; pkgdown built-in search sufficient for v1.0.0
- Interactive examples (webR) — deferred; high complexity, emerging tooling

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full report rendering (Rmd/PDF template) | Opinionated, agency-specific; out of scope per PROJECT.md |
| Shiny app or interactive widgets | Out of scope for a documentation site milestone |
| Custom domain configuration | GitHub Pages URL sufficient for launch; defer to v1.1.0+ |
| Dark mode | Accessibility complexity; dark themes reduce legibility on code blocks |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| STICKER-01 | Phase 52 | Pending |
| STICKER-02 | Phase 52 | Pending |
| STICKER-03 | Phase 52 | Pending |
| FOUND-01 | Phase 53 | Complete |
| FOUND-02 | Phase 53 | Complete |
| FOUND-03 | Phase 53 | Complete |
| THEME-01 | Phase 53 | Complete |
| THEME-02 | Phase 53 | Complete |
| THEME-03 | Phase 53 | Complete |
| THEME-04 | Phase 54 | Complete |
| HOME-01 | Phase 54 | Complete |
| HOME-02 | Phase 54 | Complete |
| HOME-03 | Phase 54 | Complete |
| REF-01 | Phase 54 | Complete |
| REF-02 | Phase 54 | Complete |
| NAV-01 | Phase 55 | Complete |
| NAV-02 | Phase 55 | Complete |
| NAV-03 | Phase 55 | Complete |
| DEPLOY-01 | Phase 56 | Pending |
| DEPLOY-02 | Phase 56 | Pending |
| DEPLOY-03 | Phase 56 | Pending |

**Coverage:**
- v1.0.0 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0

---
*Requirements defined: 2026-03-24*
*Last updated: 2026-03-24 after roadmap creation — all 20 requirements mapped*
