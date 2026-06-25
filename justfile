snapshot:
    git status --short
    git log --oneline -5

test:
    Rscript -e 'devtools::test()'

check:
    Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"), error_on = "warning")'

lint:
    Rscript -e 'lintr::lint_package()'

docs:
    Rscript -e 'devtools::document()'
    Rscript -e 'devtools::build_readme()'

site:
    Rscript -e 'pkgdown::build_site()'

check-gemini:
    Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"), error_on = "warning")' 2>&1 | gemini -p "summarize errors and warnings only, skip passing checks"

coverage:
    Rscript -e 'covr::package_coverage()' 2>&1 | gemini -p "list functions under 80% coverage, show percentage"

security:
    mkdir -p security
    gitleaks detect --source . --redact --report-format json --report-path security/gitleaks.json || true

# Refresh NGPC creel inventory and refit ngpc_creel_params.
# Incremental: only fetches creels not already in ~/.cache/tidycreel/ngpc_creel_inventory.rds
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
