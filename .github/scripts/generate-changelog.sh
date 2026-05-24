#!/bin/bash
# Changelog Generator - Pollux Kernel
# Generates changelog from git log between last tag and current HEAD

set -e

echo "📝 Generating changelog..."
echo ""

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
    echo "## ✨ Initial Release" > /tmp/changelog.md
    echo "" >> /tmp/changelog.md
    echo "First build of Pollux Kernel." >> /tmp/changelog.md
    echo "" >> /tmp/changelog.md
    echo "### Commits" >> /tmp/changelog.md
    git log --oneline --no-decorate -20 >> /tmp/changelog.md
else
    echo "## What's Changed" > /tmp/changelog.md
    echo "" >> /tmp/changelog.md
    echo "Changes since **${LAST_TAG}**:" >> /tmp/changelog.md
    echo "" >> /tmp/changelog.md

    # Group commits by type
    echo "### 🚀 Features" >> /tmp/changelog.md
    git log ${LAST_TAG}..HEAD --oneline --no-decorate --grep="feat" -i >> /tmp/changelog.md 2>/dev/null || echo "None" >> /tmp/changelog.md
    echo "" >> /tmp/changelog.md

    echo "### 🐛 Bug Fixes" >> /tmp/changelog.md
    git log ${LAST_TAG}..HEAD --oneline --no-decorate --grep="fix" -i >> /tmp/changelog.md 2>/dev/null || echo "None" >> /tmp/changelog.md
    echo "" >> /tmp/changelog.md

    echo "### 🔒 Security" >> /tmp/changelog.md
    git log ${LAST_TAG}..HEAD --oneline --no-decorate --grep="security\|CVE\|cip\|upstream" -i >> /tmp/changelog.md 2>/dev/null || echo "None" >> /tmp/changelog.md
    echo "" >> /tmp/changelog.md

    echo "### 🔧 Updates" >> /tmp/changelog.md
    git log ${LAST_TAG}..HEAD --oneline --no-decorate --grep="update\|bump\|upgrade\|merge" -i >> /tmp/changelog.md 2>/dev/null || echo "None" >> /tmp/changelog.md
    echo "" >> /tmp/changelog.md

    echo "### 📦 All Commits" >> /tmp/changelog.md
    git log ${LAST_TAG}..HEAD --oneline --no-decorate >> /tmp/changelog.md 2>/dev/null || echo "None" >> /tmp/changelog.md
fi

echo "✅ Changelog generated."
cat /tmp/changelog.md
