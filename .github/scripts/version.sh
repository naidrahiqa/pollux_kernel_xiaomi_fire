#!/bin/bash
# Version Management - Pollux Kernel
# Usage: source version.sh [variant] [base_version]
#
# Variants:
#   0 = nightly  → v0.1.0-nightly.YYYYMMDD
#   1 = stable   → v1.0.0
#   2 = hotfix   → v1.0.1

set -e

VARIANT="${1:-0}"
BASE_VERSION="${2:-1.0.0}"
DATE_TAG=$(date +%Y%m%d)

case "$VARIANT" in
    0)
        # Nightly: v0.1.0-nightly.YYYYMMDD
        POLLUX_VERSION="v0.1.0-nightly.${DATE_TAG}"
        POLLUX_VARIANT_NAME="nightly"
        ;;
    1)
        # Stable: v1.0.0
        POLLUX_VERSION="v${BASE_VERSION}"
        POLLUX_VARIANT_NAME="stable"
        ;;
    2)
        # Hotfix: v1.0.1
        MAJOR=$(echo "$BASE_VERSION" | cut -d. -f1)
        MINOR=$(echo "$BASE_VERSION" | cut -d. -f2)
        PATCH=$(echo "$BASE_VERSION" | cut -d. -f3)
        POLLUX_VERSION="v${MAJOR}.${MINOR}.$((PATCH + 1))"
        POLLUX_VARIANT_NAME="hotfix"
        ;;
    *)
        echo "❌ Unknown variant: $VARIANT (0=nightly, 1=stable, 2=hotfix)"
        exit 1
        ;;
esac

POLLUX_TAG="${POLLUX_VERSION}"

export POLLUX_VERSION
export POLLUX_TAG
export POLLUX_VARIANT_NAME
export POLLUX_BASE="4.19.325-cip134"
export POLLUX_CODENAME="Pollux"

# Kernel localversion
export LOCALVERSION="-Pollux-${POLLUX_VERSION}"

# Release info
export RELEASE_DATE=$(date +"%d %B %Y")
export RELEASE_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
