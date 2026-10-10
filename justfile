snapshot:
    git status --short
    git log --oneline -5

test:
    Rscript -e 'devtools::test()'

# Builds the PDF reference manual on purpose. `--no-manual` was here until
# GH #358, and it is exactly why Win-Builder found a manual that would not
# compile (1 ERROR) against a local gate reporting 0/0/1. A check that skips the
# manual cannot tell you the package is submittable. Needs pdflatex.
check:
    Rscript -e 'rcmdcheck::rcmdcheck(args = "--as-cran", env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"), error_on = "warning")'

lint:
    Rscript -e 'lintr::lint_package()'

# README.md is a HAND-MAINTAINED mirror of README.Rmd, not a knit artifact --
# both carry the same `output: github_document` front matter. build_readme() was
# called here until GH #358: it rewrites vignette("x") with curly quotes,
# producing R code in the docs that does not parse, and shatters the
# survey-type card markup. Edit README.Rmd and README.md with the same change.
docs:
    Rscript -e 'devtools::document()'

site:
    Rscript -e 'pkgdown::build_site()'

check-gemini:
    Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"), error_on = "warning")' 2>&1 | gemini -p "summarize errors and warnings only, skip passing checks"

coverage:
    Rscript -e 'covr::package_coverage()' 2>&1 | gemini -p "list functions under 80% coverage, show percentage"

security:
    mkdir -p security
    gitleaks detect --source . --redact --report-format json --report-path security/gitleaks.json || true

# Refresh the local survey inventory and refit its parameters.
# Local-only: the inventory script and its data are gitignored, because they
# name one agency's API. Incremental -- only fetches surveys not already cached.
refresh-inventory:
    Rscript data-raw/ngpc_creel_inventory.R

# Show all files with needs-review status in REVIEW-MANIFEST.md
review-status:
    @grep "needs-review" .ai/REVIEW-MANIFEST.md | grep "^| R/" | awk -F'|' '{printf "%-45s tier=%s\n", $2, $7}' || echo "Nothing needs review."

# Update REVIEW-MANIFEST.md after reviewing a file.
# Usage: just review-update R/foo.R clean "notes here"
# Performs best-effort row update; on no-match, prints reminder to edit manually.
review-update file status notes:
    #!/usr/bin/env bash
    set -euo pipefail
    sha=$(git log -1 --format="%h" -- "{{file}}")
    rdate=$(git log -1 --format="%as" -- "{{file}}")
    today=$(date +%Y-%m-%d)
    echo "Updating {{file}} -> {{status}} (reviewed $today)"
    python3 scripts/review_update.py "{{file}}" "{{status}}" "{{notes}}" "$sha" "$rdate" "$today"

# CRAN release helpers -- scripts/release.R; the process is in CONTRIBUTING.md
# under "Releases". Submission itself stays interactive: cran_submit().
#   minor/major: just release-prep 9.0.0 "Fish Name"
#   patch:       just release-prep 8.0.2 "" origin/cran-8.0.1

# Cut cran-<version> in ~/Dev/tidycreel-submit and stamp the version.
release-prep version name="" from="origin/main":
    Rscript -e 'source("scripts/release.R"); release_prep("{{version}}", "{{name}}", "{{from}}")'

# --as-cran check and submission-guard dry run of the release branch.
release-check:
    Rscript -e 'source("scripts/release.R"); release_check()'

# After CRAN publishes: tag, GitHub release, and the post-release PR for main.
release-accepted version:
    Rscript -e 'source("scripts/release.R"); release_accepted("{{version}}")'
