# Local Testing Guide

This guide helps you test your R package locally before pushing to GitHub, replicating the CI environment to catch issues early.

## Quick Start

### Option 1: Using Make (Recommended)
```bash
# Run full CI pipeline locally
make ci-local

# Or run individual steps
make docker-build    # Build Docker image
make docker-test     # Run tests
make docker-check    # Run R CMD check
make docker-lint     # Run linting
```

### Option 2: Using the Test Script
```bash
# Run the comprehensive test script
./scripts/test-local.sh
```

### Option 3: Using Docker Compose
```bash
# Run tests
docker-compose run tidycreel-test

# Run R CMD check
docker-compose run tidycreel-check

# Interactive development environment
docker-compose run tidycreel-dev
```

## Available Commands

### Make Targets
- `make help` - Show all available targets
- `make build` - Build package locally (requires R)
- `make test` - Run tests locally (requires R)
- `make check` - Run R CMD check locally (requires R)
- `make lint` - Run lintr locally (requires R)
- `make docker-*` - Docker versions of above commands
- `make ci-local` - Full CI pipeline in Docker
- `make clean` - Clean build artifacts

### Development Workflow

1. **Before making changes:**
   ```bash
   make docker-build  # Ensure clean starting point
   ```

2. **During development:**
   ```bash
   make dev-cycle     # Quick local test (build + test + lint)
   ```

3. **Before pushing to GitHub:**
   ```bash
   make ci-local      # Full CI simulation
   ```

## Troubleshooting

### Docker Issues
- **Build fails**: Check Dockerfile and ensure all dependencies are available
- **Permission errors**: Make sure Docker has access to your project directory
- **Out of space**: Run `docker system prune` to clean up

### R Package Issues
- **Missing dependencies**: Check DESCRIPTION file and renv.lock
- **Test failures**: Run `make docker-shell` to debug interactively
- **Lint errors**: Use `make docker-lint` to see specific style issues

### Common Fixes
```bash
# Clean everything and start fresh
make clean
docker system prune -f
make docker-build

# Debug in interactive container
make docker-shell
# Then inside container:
devtools::load_all()
devtools::test()
```

## What Gets Tested

This local setup replicates your GitHub Actions workflows:

1. **Linting** (`lintr::lint_package()`)
   - Code style compliance
   - Tidyverse formatting rules
   - Line length limits

2. **Testing** (`devtools::test()`)
   - All testthat unit tests
   - Test coverage analysis

3. **R CMD Check** (`rcmdcheck::rcmdcheck()`)
   - Package structure validation
   - Documentation completeness
   - Example code execution
   - CRAN compliance checks

## Environment Variables

The Docker environment sets the same variables as GitHub Actions:
- `_R_CHECK_FORCE_SUGGESTS_=false`
- `_R_CHECK_CRAN_INCOMING_REMOTE_=false`
- `R_DEFAULT_INTERNET_TIMEOUT=20`

## Tips

- Run `make ci-local` before every push to GitHub
- Use `make docker-shell` for interactive debugging
- Keep the Docker image updated with `make docker-build`
- Check `make help` for all available commands

## Integration with Development Workflow

Add this to your git pre-push hook:
```bash
#!/bin/bash
echo "Running local CI checks..."
make ci-local
```

Or add to your `.git/hooks/pre-push` file to automatically test before pushing.