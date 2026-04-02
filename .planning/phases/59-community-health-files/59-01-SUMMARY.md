---
phase: 59-community-health-files
plan: 01
subsystem: community
tags: [github-issues, issue-templates, yaml, survey-type, github-discussions]

# Dependency graph
requires: []
provides:
  - Structured GitHub issue form for bug reports (survey_type dropdown, version field, behavior sections)
  - Structured GitHub issue form for feature requests (problem/solution/use-case/survey-types fields)
  - Issue template chooser config routing how-to questions to GitHub Discussions
affects: [59-02-community-contributing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GitHub structured issue forms (YAML schema) with domain-specific fields"
    - "Issue template config.yml to disable blank issues and add Discussions link"

key-files:
  created:
    - .github/ISSUE_TEMPLATE/feature-request.yml
    - .github/ISSUE_TEMPLATE/config.yml
  modified:
    - .github/ISSUE_TEMPLATE/bug-report.yml

key-decisions:
  - "config.yml committed in earlier 59-02 run; Task 3 already satisfied before this plan executed"
  - "survey_type dropdown includes 'not applicable / unsure' as sixth option for non-domain bugs"
  - "survey_types in feature-request is multi-select to support cross-type features"
  - "blank_issues_enabled: false forces template selection, reducing low-context issue noise"

patterns-established:
  - "Domain-specific issue forms: capture survey_type context required to diagnose creel issues"

requirements-completed: [COMM-01, COMM-02, COMM-03, COMM-05]

# Metrics
duration: 2min
completed: 2026-04-02
---

# Phase 59 Plan 01: Community Health Files — Issue Templates Summary

**Structured GitHub issue forms with survey_type dropdown for bug reports, feature request form with problem/solution/survey-types fields, and config.yml routing how-to questions to Discussions**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-02T19:06:09Z
- **Completed:** 2026-04-02T19:07:57Z
- **Tasks:** 3 of 3 auto tasks complete (Task 4 is checkpoint:human-verify)
- **Files modified:** 3

## Accomplishments
- Rewrote bug-report.yml with survey_type single-select dropdown (all five survey types plus "not applicable / unsure"), tidycreel_version input, and separate expected/actual behavior textareas
- Created feature-request.yml with problem_statement, proposed_solution, use_case (r-rendered), survey_types multi-select dropdown, and alternatives fields
- config.yml with blank_issues_enabled: false and Discussions link was already committed in a prior plan execution (4e36dc9); confirmed content correct

## Task Commits

1. **Task 1: Rewrite bug-report.yml** - `0693c02` (feat)
2. **Task 2: Create feature-request.yml** - `49874b1` (feat)
3. **Task 3: Create config.yml** - already committed at `4e36dc9` (prior execution); no new commit needed

## Files Created/Modified
- `.github/ISSUE_TEMPLATE/bug-report.yml` - Structured bug form with survey_type dropdown, version input, expected/actual behavior textareas, reprex and sessionInfo
- `.github/ISSUE_TEMPLATE/feature-request.yml` - Structured feature request form with problem statement, proposed solution, use case, and survey types multi-select dropdown
- `.github/ISSUE_TEMPLATE/config.yml` - Issue template chooser: blank_issues_enabled: false, Discussions contact link

## Decisions Made
- Added "not applicable / unsure" as sixth survey_type option to handle bugs that are not domain-specific
- Feature request survey_types field is multi-select to allow features that span multiple survey types
- config.yml found already committed in prior 59-02 execution with correct content — accepted as-is

## Deviations from Plan

None - plan executed exactly as written. config.yml was pre-existing from a prior plan run with correct content, so Task 3 required no new commit.

## Issues Encountered

config.yml was already committed in commit `4e36dc9` (labeled feat(59-02)) from a previous plan execution run. The content matched the plan specification exactly, so no corrective action was needed. This is a harmless ordering artifact.

## User Setup Required

COMM-05 (Enable GitHub Discussions) requires a manual step: go to the GitHub repository Settings > Features and toggle on "Discussions". The config.yml contact_links URL points to `https://github.com/chrischizinski/tidycreel/discussions` but the feature must be enabled by the repo owner before the link is functional for visitors.

## Next Phase Readiness

- All issue template files are in place and parse as valid YAML
- GitHub Discussions URL is configured in config.yml
- Repo owner needs to enable Discussions in repository settings (manual step, cannot be automated)
- Task 4 checkpoint: human-verify is outstanding — review files and confirm correctness

---
*Phase: 59-community-health-files*
*Completed: 2026-04-02*
