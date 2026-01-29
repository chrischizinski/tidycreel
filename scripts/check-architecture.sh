#!/bin/bash

# Architectural Compliance Checker for tidycreel
# Run this before committing to ensure architectural standards

set -e

echo "🔍 Checking tidycreel architectural compliance..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Check 1: Banned file naming patterns
echo "📁 Checking for banned file naming patterns..."
BANNED_FILES=$(find R/ -type f \( \
  -name "*-integration.R" -o \
  -name "*-enhanced.R" -o \
  -name "*-wrapper.R" -o \
  -name "*-patch.R" -o \
  -name "*-internals-access.R" \
\) 2>/dev/null || true)

if [ -n "$BANNED_FILES" ]; then
  echo -e "${RED}❌ ERROR: Banned file naming patterns detected:${NC}"
  echo "$BANNED_FILES"
  ERRORS=$((ERRORS + 1))
else
  echo -e "${GREEN}✅ No banned file patterns${NC}"
fi
echo ""

# Check 2: Banned function patterns
echo "🔧 Checking for banned function patterns..."
BANNED_FUNCTIONS=$(grep -r \
  -e "add_enhanced_" \
  -e "enhance_estimator" \
  -e "create_enhanced_" \
  -e "batch_enhance_" \
  R/ 2>/dev/null | grep -v "^Binary" || true)

if [ -n "$BANNED_FUNCTIONS" ]; then
  echo -e "${RED}❌ ERROR: Banned function patterns detected:${NC}"
  echo "$BANNED_FUNCTIONS"
  ERRORS=$((ERRORS + 1))
else
  echo -e "${GREEN}✅ No banned function patterns${NC}"
fi
echo ""

# Check 3: Estimators use tc_compute_variance
echo "⚙️  Checking if estimators use tc_compute_variance..."
EST_WITHOUT_CORE=0
for file in R/est-*.R; do
  if [ -f "$file" ] && [ ! "$(basename "$file")" = "est-effort-instantaneous-REBUILT.R" ]; then
    if ! grep -q "tc_compute_variance" "$file"; then
      # Check if it has survey design
      if grep -q "svy.*=" "$file" || grep -q "design.*=" "$file"; then
        echo -e "${YELLOW}⚠️  WARNING: $file has survey design but doesn't use tc_compute_variance${NC}"
        EST_WITHOUT_CORE=$((EST_WITHOUT_CORE + 1))
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
  fi
done

if [ $EST_WITHOUT_CORE -eq 0 ]; then
  echo -e "${GREEN}✅ All estimators use core engine (or will after rebuild)${NC}"
fi
echo ""

# Check 4: Core engine files exist
echo "🏗️  Checking core infrastructure..."
CORE_FILES=(
  "R/variance-engine.R"
  "R/variance-decomposition-engine.R"
  "R/survey-diagnostics.R"
)

MISSING_CORE=0
for file in "${CORE_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo -e "${RED}❌ ERROR: Missing core file: $file${NC}"
    MISSING_CORE=$((MISSING_CORE + 1))
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $MISSING_CORE -eq 0 ]; then
  echo -e "${GREEN}✅ All core infrastructure files present${NC}"
fi
echo ""

# Check 5: Documentation exists
echo "📚 Checking documentation..."
DOC_FILES=(
  "ARCHITECTURAL_STANDARDS.md"
  "GROUND_UP_INTEGRATION_DESIGN.md"
  "GROUND_UP_IMPLEMENTATION_SUMMARY.md"
)

MISSING_DOCS=0
for file in "${DOC_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Missing documentation: $file${NC}"
    MISSING_DOCS=$((MISSING_DOCS + 1))
    WARNINGS=$((WARNINGS + 1))
  fi
done

if [ $MISSING_DOCS -eq 0 ]; then
  echo -e "${GREEN}✅ All documentation present${NC}"
fi
echo ""

# Check 6: Old patch files (should be deleted after full rebuild)
echo "🧹 Checking for old patch files..."
OLD_PATCH_FILES=(
  "R/survey-enhanced-integration.R"
  "R/estimators-integration.R"
  "R/survey-internals-integration.R"
  "R/survey-internals-integration-fixed.R"
  "R/survey-integration-example.R"
  "R/survey-integration-phase2-example.R"
  "R/estimators-enhanced.R"
)

OLD_FILES_EXIST=0
for file in "${OLD_PATCH_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Old patch file still exists: $file${NC}"
    echo "   This should be deleted after all estimators are rebuilt"
    OLD_FILES_EXIST=$((OLD_FILES_EXIST + 1))
    WARNINGS=$((WARNINGS + 1))
  fi
done

if [ $OLD_FILES_EXIST -eq 0 ]; then
  echo -e "${GREEN}✅ No old patch files (clean architecture)${NC}"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}✨ Perfect! Architecture is compliant!${NC}"
  echo ""
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo -e "${YELLOW}⚠️  Architecture check passed with $WARNINGS warning(s)${NC}"
  echo ""
  echo "Warnings indicate areas for improvement but don't block commits."
  exit 0
else
  echo -e "${RED}❌ Architecture check FAILED with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
  echo ""
  echo "Please fix errors before committing."
  echo "See ARCHITECTURAL_STANDARDS.md for details."
  exit 1
fi
