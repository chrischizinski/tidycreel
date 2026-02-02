# Makefile for tidycreel local testing
# Replicates GitHub Actions workflows locally

.PHONY: help build test check lint coverage clean docker-build docker-test docker-check docker-shell

# Default target
help:
	@echo "Available targets:"
	@echo "  build         - Build the package"
	@echo "  test          - Run tests"
	@echo "  check         - Run R CMD check"
	@echo "  lint          - Run lintr"
	@echo "  coverage      - Generate test coverage report"
	@echo "  clean         - Clean build artifacts"
	@echo "  docker-build  - Build Docker image"
	@echo "  docker-test   - Run tests in Docker"
	@echo "  docker-check  - Run R CMD check in Docker"
	@echo "  docker-shell  - Open shell in Docker container"
	@echo "  ci-local      - Run full CI pipeline locally"

# Local R commands (requires R installation)
build:
	Rscript -e "devtools::document()"
	Rscript -e "devtools::build()"

test:
	Rscript -e "devtools::test()"

check:
	Rscript -e "rcmdcheck::rcmdcheck(args = c('--no-manual', '--as-cran'), error_on='warning')"

lint:
	Rscript -e "lintr::lint_package()"

coverage:
	Rscript -e "covr::package_coverage()"

clean:
	rm -rf check/
	rm -rf *.tar.gz
	rm -rf man/
	find . -name "*.Rcheck" -type d -exec rm -rf {} +

# Docker-based commands (replicates CI environment)
docker-build:
	docker build -t tidycreel:latest .

docker-test: docker-build
	docker run --rm -v $(PWD):/home/tidycreel tidycreel:latest \
		bash -c "rm -f .Rprofile && Rscript -e 'devtools::test()'"

docker-check: docker-build
	docker run --rm -v $(PWD):/home/tidycreel tidycreel:latest \
		bash -c "rm -f .Rprofile && Rscript -e 'rcmdcheck::rcmdcheck(args = c(\"--no-manual\", \"--no-build-vignettes\", \"--as-cran\"), error_on=\"warning\", check_dir=\"check\")'"

docker-lint: docker-build
	docker run --rm -v $(PWD):/home/tidycreel tidycreel:latest \
		bash -c "rm -f .Rprofile && Rscript -e 'lintr::lint_package()'"

docker-coverage: docker-build
	docker run --rm -v $(PWD):/home/tidycreel tidycreel:latest \
		bash -c "rm -f .Rprofile && Rscript -e 'covr::package_coverage()'"

docker-shell: docker-build
	docker run --rm -it -v $(PWD):/home/tidycreel tidycreel:latest /bin/bash

# Run full CI pipeline locally
ci-local: docker-build docker-lint docker-test docker-check
	@echo "✅ All CI checks passed locally!"

# Quick local development cycle
dev-cycle: build test lint
	@echo "✅ Development cycle complete!"
