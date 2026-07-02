#!/bin/bash
# Telegram Notification - Pollux Kernel
# Usage: bash notify-telegram.sh <status> <version> <tag> [changelog_or_error_file]
# Status: start | success | failed
#
# Required GitHub Secrets:
#   TELEGRAM_BOT_TOKEN       - Bot token from @BotFather
#   TELEGRAM_CHANNEL_ID      - Main channel (build start + success)
#   TELEGRAM_ERROR_CHANNEL_ID - Error channel (build failed)

set -e

STATUS="${1:-unknown}"
VERSION="${2:-unknown}"
TAG="${3:-$VERSION}"
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHANNEL_ID="${TELEGRAM_CHANNEL_ID:-}"
ERROR_CHANNEL_ID="${TELEGRAM_ERROR_CHANNEL_ID:-}"

if [ -z "$BOT_TOKEN" ]; then
    echo "⚠️  TELEGRAM_BOT_TOKEN not set. Skipping."
    exit 0
fi

if [ "$STATUS" != "failed" ] && [ -z "$CHANNEL_ID" ]; then
    echo "⚠️  TELEGRAM_CHANNEL_ID not set. Skipping."
    exit 0
fi

if [ "$STATUS" == "failed" ] && [ -z "$ERROR_CHANNEL_ID" ] && [ -z "$CHANNEL_ID" ]; then
    echo "⚠️  Neither TELEGRAM_ERROR_CHANNEL_ID nor TELEGRAM_CHANNEL_ID set. Skipping."
    exit 0
fi

# Gather info
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
FULL_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
COMMIT_MSG=$(git log -1 --pretty=%s 2>/dev/null || echo "unknown")
BUILD_NUM="${GITHUB_RUN_NUMBER:-0}"
BUILD_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
REPO_URL="https://github.com/${GITHUB_REPOSITORY}"

# Toolchain info
CLANG_VERSION="${CLANG_VERSION:-Cyrene Clang 22.1.0}"
CLANG_URL="https://github.com/naidrahiqa/cyrene_clang"
KSU_VERSION="${KERNELSU_VERSION:-KernelSU-Next v3.2.0-legacy}"

function send_to_channel() {
    local target="$1"
    local message="$2"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${target}" \
        -d text="${message}" \
        -d parse_mode="HTML" \
        -d disable_web_page_preview=true > /dev/null
}

function build_start() {
    local msg="<b>🔨 Pollux Kernel Build Started</b>

<b>Device:</b> Redmi 12 (fire) / MT6768
<b>Build:</b> #${BUILD_NUM}
<b>Tag:</b> <code>${TAG}</code>
<b>Commit:</b> <code>${SHA}</code>
<b>Message:</b> ${COMMIT_MSG}
<b>Run:</b> <a href='${BUILD_URL}'>GitHub Actions</a>

⏳ Waiting for build to complete..."
    send_to_channel "$CHANNEL_ID" "$msg"
    echo "✅ Build start notification sent."
}

function build_success() {
    local changelog_file="${1:-}"
    local changelog_text=""

    if [ -n "$changelog_file" ] && [ -f "$changelog_file" ]; then
        changelog_text=$(head -30 "$changelog_file")
    fi

    local msg="<b>✅ Pollux ${VERSION} Released!</b>

<b>Device:</b> Redmi 12 (fire) / MT6768
<b>Tag:</b> <code>${TAG}</code>
<b>Commit:</b> <code>${SHA}</code>
<b>Release:</b> <a href='${REPO_URL}/releases/tag/${TAG}'>Download</a>

<b>📦 Downloads</b>
• Flashable zip (AnyKernel3) — via custom recovery
• Image.gz — manual flash via fastboot
• tar.zst — source/build archive

<b>🛠 Toolchains</b>
• <a href='${CLANG_URL}'>Cyrene Clang</a>: ${CLANG_VERSION}

<b>🔌 Integrations</b>
• ${KSU_VERSION}
• SUSFS v2.2.0 (backport)

<b>📋 Changelog</b>
<pre>${changelog_text}</pre>

<a href='${REPO_URL}'>Pollux Kernel</a> | <a href='${BUILD_URL}'>Build Log</a>"
    send_to_channel "$CHANNEL_ID" "$msg"
    echo "✅ Build success notification sent."
}

function build_failed() {
    local error_log="${1:-build.log}"
    local error_context="No error context available."
    local error_type="UNKNOWN ERROR"
    local failed_step="Unknown step"

    # Detect error type from build log
    if [ -f "$error_log" ]; then
        # Check for make error
        if grep -q "make\[" "$error_log" && grep -q "Error" "$error_log"; then
            error_type="MAKE ERROR"
        elif grep -q "fatal:" "$error_log"; then
            error_type="FATAL ERROR"
        elif grep -q "error:" "$error_log"; then
            error_type="COMPILE ERROR"
        fi

        # Find which step failed
        if grep -q "CC\s" "$error_log" || grep -q "\.c:" "$error_log"; then
            failed_step="Build kernel (compile error)"
        elif grep -q "LD\s" "$error_log" || grep -q "ld.lld:" "$error_log"; then
            failed_step="Build kernel (link error)"
        elif grep -q "make defconfig" "$error_log"; then
            failed_step="Configure kernel"
        else
            failed_step="Build kernel (make error)"
        fi

        # Get error context (last error lines, skip CC spam)
        error_context=$(grep -i -B2 -A10 "error:" "$error_log" | tail -30)
        if [ -z "$error_context" ]; then
            error_context=$(tail -15 "$error_log")
        fi
    fi

    local msg="<b>📢 Pollux Kernel Info</b>
<b>❌ Pollux Kernel Build #${BUILD_NUM} Failed</b>

<b>Device:</b> Redmi 12 (fire) / MT6768
<b>Tag:</b> <code>${TAG}</code>-$(date +%Y%m%d)-${SHA}
<b>Error:</b> <b>${error_type}</b>
<b>Step:</b> ${failed_step}

<b>Error Context:</b>
<pre><code>${error_context}</code></pre>

<a href='${BUILD_URL}'>View Build Log</a>"

    # Send to ERROR channel if set, otherwise fallback to main channel
    local target="${ERROR_CHANNEL_ID:-$CHANNEL_ID}"
    send_to_channel "$target" "$msg"
    echo "✅ Build failure notification sent to error channel."
}

case "$STATUS" in
    start)
        build_start
        ;;
    success)
        build_success "$4"
        ;;
    failed)
        build_failed "$4"
        ;;
    *)
        echo "❌ Unknown status: $STATUS"
        echo "Usage: notify-telegram.sh <start|success|failed> <version> <tag> [file]"
        exit 1
        ;;
esac
