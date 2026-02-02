#!/bin/bash
# Install git hooks for local testing

set -e

echo "Installing git hooks for tidycreel..."

# Create pre-push hook
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
# Pre-push hook to run local CI checks

echo "🔍 Running local CI checks before push..."

if command -v make &> /dev/null && command -v docker &> /dev/null; then
    if make ci-local; then
        echo "✅ All checks passed! Proceeding with push."
        exit 0
    else
        echo "❌ CI checks failed! Fix issues before pushing."
        echo "Run 'make ci-local' to see detailed output."
        exit 1
    fi
else
    echo "⚠️  Docker or Make not available. Skipping local CI checks."
    echo "Consider installing Docker and running 'make ci-local' manually."
    exit 0
fi
EOF

# Make hook executable
chmod +x .git/hooks/pre-push

echo "✅ Pre-push hook installed!"
echo "Now 'git push' will automatically run local CI checks."
echo ""
echo "To bypass the hook (not recommended):"
echo "  git push --no-verify"
echo ""
echo "To test the hook manually:"
echo "  make ci-local"
