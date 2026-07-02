#!/bin/bash
# Changelog Generator - Pollux Kernel
# Generates formatted changelog for GitHub releases

set -e

VERSION="${1:-unknown}"
TAG="${2:-$VERSION}"
VARIANT="${3:-nightly}"

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# Collect commits by type
FEATURES=$(git log ${LAST_TAG:+$LAST_TAG..}HEAD --oneline --no-decorate --grep="feat" -i 2>/dev/null || echo "")
FIXES=$(git log ${LAST_TAG:+$LAST_TAG..}HEAD --oneline --no-decorate --grep="fix" -i 2>/dev/null || echo "")
SECURITY=$(git log ${LAST_TAG:+$LAST_TAG..}HEAD --oneline --no-decorate --grep="security\|CVE\|cip\|upstream" -i 2>/dev/null || echo "")
UPDATES=$(git log ${LAST_TAG:+$LAST_TAG..}HEAD --oneline --no-decorate --grep="update\|bump\|upgrade\|merge\|refactor" -i 2>/dev/null || echo "")
ALL_COMMITS=$(git log ${LAST_TAG:+$LAST_TAG..}HEAD --oneline --no-decorate 2>/dev/null || echo "")

# Build changelog
cat << EOF
## What's New in ${TAG}

### Info
- **Device:** Redmi 12 (fire) / MT6768
- **Kernel:** ${POLLUX_BASE:-4.19.325-cip134}
- **Toolchain:** Cyrene Clang 22.1.0
- **Integration:** KernelSU-Next v3.2.0-legacy + SUSFS v2.2.0
- **Variant:** ${VARIANT}

EOF

if [ -n "$FEATURES" ]; then
    echo "### 🚀 Features"
    echo "$FEATURES"
    echo ""
fi

if [ -n "$FIXES" ]; then
    echo "### 🐛 Bug Fixes"
    echo "$FIXES"
    echo ""
fi

if [ -n "$SECURITY" ]; then
    echo "### 🔒 Security"
    echo "$SECURITY"
    echo ""
fi

if [ -n "$UPDATES" ]; then
    echo "### 🔧 Updates"
    echo "$UPDATES"
    echo ""
fi

if [ -n "$ALL_COMMITS" ]; then
    echo "### 📦 All Commits"
    echo "$ALL_COMMITS"
    echo ""
fi

if [ -z "$FEATURES" ] && [ -z "$FIXES" ] && [ -z "$SECURITY" ] && [ -z "$UPDATES" ] && [ -z "$ALL_COMMITS" ]; then
    echo "### 📦 Changes"
    echo "No commits since last release."
    echo ""
fi
