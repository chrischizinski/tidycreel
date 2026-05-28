snapshot:
    git status --short
    git log --oneline -5

test:
    Rscript -e 'devtools::test()'

check:
    Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), error_on = "warning")'

lint:
    Rscript -e 'lintr::lint_package()'

docs:
    Rscript -e 'devtools::document()'
    Rscript -e 'devtools::build_readme()'

site:
    Rscript -e 'pkgdown::build_site()'

check-gemini:
    Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), error_on = "warning")' 2>&1 | gemini -p "summarize errors and warnings only, skip passing checks"

coverage:
    Rscript -e 'covr::package_coverage()' 2>&1 | gemini -p "list functions under 80% coverage, show percentage"

security:
    mkdir -p security
    gitleaks detect --source . --redact --report-format json --report-path security/gitleaks.json || true

# Refresh NGPC creel inventory and refit ngpc_creel_params.
# Incremental: only fetches creels not already in ~/.cache/tidycreel/ngpc_creel_inventory.rds
refresh-inventory:
    Rscript data-raw/ngpc_creel_inventory.R
