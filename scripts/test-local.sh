#!/bin/bash
# Local testing script that replicates GitHub Actions

set -e

echo "🚀 Starting local CI pipeline..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

# Build Docker image
print_status "Building Docker image..."
docker build -t tidycreel:test .

# Run linting
print_status "Running lintr..."
if docker run --rm -v $(pwd):/home/tidycreel tidycreel:test \
    Rscript -e "lintr::lint_package()"; then
    print_status "✅ Linting passed"
else
    print_error "❌ Linting failed"
    exit 1
fi

# Run tests
print_status "Running tests..."
if docker run --rm -v $(pwd):/home/tidycreel tidycreel:test \
    Rscript -e "devtools::test()"; then
    print_status "✅ Tests passed"
else
    print_error "❌ Tests failed"
    exit 1
fi

# Run R CMD check
print_status "Running R CMD check..."
if docker run --rm -v $(pwd):/home/tidycreel tidycreel:test \
    Rscript -e "rcmdcheck::rcmdcheck(args = c('--no-manual', '--as-cran'), error_on='warning', check_dir='check')"; then
    print_status "✅ R CMD check passed"
else
    print_error "❌ R CMD check failed"
    exit 1
fi

# Generate coverage report (optional, doesn't fail the build)
print_status "Generating coverage report..."
if docker run --rm -v $(pwd):/home/tidycreel tidycreel:test \
    Rscript -e "covr::package_coverage()"; then
    print_status "✅ Coverage report generated"
else
    print_warning "⚠️  Coverage report failed (non-blocking)"
fi

print_status "🎉 All checks passed! Ready to push to GitHub."