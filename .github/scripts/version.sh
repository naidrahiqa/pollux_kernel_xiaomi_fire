#!/bin/bash
# Version Management - Pollux Kernel
# Usage: source version.sh  (sets POLLUX_VERSION, POLLUX_TAG, etc.)

# Date-based version: PolluxXDDMMYY
# X = build variant (0=nightly, 1=stable, 2=hotfix)
# DD = day, MM = month, YY = year

BUILD_VARIANT="${1:-0}"  # default nightly
DATE_TAG=$(date +%d%m%y)

export POLLUX_VERSION="${BUILD_VARIANT}${DATE_TAG}"
export POLLUX_TAG="Pollux${POLLUX_VERSION}"
export POLLUX_BASE="4.19.325-cip134"
export POLLUX_CODENAME="Pollux"

# Kernel localversion
export LOCALVERSION="-Pollux-${POLLUX_VERSION}"

# Release info
export RELEASE_DATE=$(date +"%d %B %Y")
export RELEASE_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
