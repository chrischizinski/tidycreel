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

security:
    mkdir -p security
    gitleaks detect --source . --redact --report-format json --report-path security/gitleaks.json || true
