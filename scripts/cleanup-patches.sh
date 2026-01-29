#!/bin/bash

# Cleanup Script for Old Patch Files
# Run this AFTER all estimators have been rebuilt with native survey integration

echo "🧹 tidycreel Patch File Cleanup Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  WARNING: This script will DELETE old patch/integration files."
echo "Only run this AFTER:"
echo "  1. All estimators have been rebuilt with native integration"
echo "  2. All tests pass"
echo "  3. Results have been validated"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# Track what we delete
DELETED_COUNT=0

# Patch/integration R files
PATCH_FILES=(
  "R/survey-enhanced-integration.R"
  "R/estimators-integration.R"
  "R/survey-internals-integration.R"
  "R/survey-internals-integration-fixed.R"
  "R/survey-integration-example.R"
  "R/survey-integration-phase2-example.R"
  "R/estimators-enhanced.R"
)

echo "📁 Deleting patch R files..."
for file in "${PATCH_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  Deleting: $file"
    rm "$file"
    DELETED_COUNT=$((DELETED_COUNT + 1))
  fi
done
echo ""

# Demo files
DEMO_FILES=(
  "INTEGRATION_DEMONSTRATION.R"
  "SIMPLE_DEMO.R"
)

echo "📝 Deleting demo files..."
for file in "${DEMO_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  Deleting: $file"
    rm "$file"
    DELETED_COUNT=$((DELETED_COUNT + 1))
  fi
done
echo ""

# Old planning docs
OLD_DOCS=(
  "SURVEY_INTEGRATION_PLAN.md"
  "CURRENT_INTEGRATION_STATUS.md"
  "IMMEDIATE_ACTIONS.md"
)

echo "📚 Deleting old planning documents..."
for file in "${OLD_DOCS[@]}"; do
  if [ -f "$file" ]; then
    echo "  Deleting: $file"
    rm "$file"
    DELETED_COUNT=$((DELETED_COUNT + 1))
  fi
done
echo ""

# The REBUILT proof-of-concept (should be replaced by actual implementation)
REBUILT_FILE="R/est-effort-instantaneous-REBUILT.R"
if [ -f "$REBUILT_FILE" ]; then
  echo "📌 Note: $REBUILT_FILE still exists"
  echo "   This should be used to REPLACE R/est-effort-instantaneous.R"
  echo "   Then deleted once the original is replaced."
  echo ""
fi

# Test files that need updating
TEST_INTEGRATION_FILES=(
  "tests/testthat/test-estimators-integration.R"
  "tests/testthat/test-survey-internals.R"
)

echo "🧪 Checking test files..."
for file in "${TEST_INTEGRATION_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  ⚠️  Test file exists: $file"
    echo "     Review if this needs updating or removal"
  fi
done
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cleanup complete!"
echo ""
echo "📊 Summary:"
echo "   Deleted files: $DELETED_COUNT"
echo ""
echo "📋 Next steps:"
echo "   1. Run: Rscript -e 'devtools::document()' to update NAMESPACE"
echo "   2. Run: Rscript -e 'devtools::test()' to verify tests pass"
echo "   3. Run: bash scripts/check-architecture.sh to verify compliance"
echo "   4. Run: git status to review changes"
echo "   5. If all looks good, commit the changes"
echo ""
echo "⚠️  Remember to:"
echo "   - Replace R/est-effort-instantaneous.R with REBUILT version"
echo "   - Delete R/est-effort-instantaneous-REBUILT.R after replacement"
echo "   - Update all remaining estimators before final cleanup"
echo ""
