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
KSU_VERSION="${KERNELSU_VERSION:-ReSukiSU v4.1.0}"

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
    local msg="🔨 <b>POLLUX KERNEL · Construction Started</b>
=====================================
⚙️ <b>Build:</b> #${BUILD_NUM}
📱 <b>Device:</b> Redmi 12 (fire) / MT6768
🌐 <b>Tag:</b> <code>${TAG}</code>
📌 <b>Commit:</b> <code>${SHA}</code> (${COMMIT_MSG})
=====================================
⏳ <i>Waiting for the forge to cool...</i>

🔍 <a href='${BUILD_URL}'>Monitor construction log</a>"
    send_to_channel "$CHANNEL_ID" "$msg"
    echo "✅ Build start notification sent."
}

function build_success() {
    local changelog_file="${1:-}"
    local changelog_text=""

    if [ -n "$changelog_file" ] && [ -f "$changelog_file" ]; then
        changelog_text=$(head -30 "$changelog_file")
    fi

    local msg="🛠️ <b>POLLUX KERNEL · Forged Successfully</b>
=====================================
📱 <b>Device:</b> Redmi 12 (fire) / MT6768
🌐 <b>Tag:</b> <code>${TAG}</code>
📌 <b>Commit:</b> <code>${SHA}</code>
=====================================

📦 <b>DOWNLOADS</b>
• <a href='${REPO_URL}/releases/tag/${TAG}'>Flashable Zip (AnyKernel3)</a> — via custom recovery
• <a href='${REPO_URL}/releases/tag/${TAG}'>Image.gz</a> — manual flash via fastboot
• <a href='${REPO_URL}/releases/tag/${TAG}'>tar.zst</a> — source/build archive

🔌 <b>INTEGRATIONS</b>
• ${KSU_VERSION}
• Manual Hook (Non-GKI)

🛠 <b>TOOLCHAINS</b>
• <a href='${CLANG_URL}'>Cyrene Clang</a>: ${CLANG_VERSION}

📋 <b>CHANGELOG</b>
<pre>${changelog_text}</pre>
=====================================
🔗 <a href='${REPO_URL}'>Pollux Repository</a> · 🔍 <a href='${BUILD_URL}'>Build Log</a>"
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

    # 1. Kirim status ringkas ke CHANNEL_ID (Update channel) jika terkonfigurasi
    if [ -n "$CHANNEL_ID" ]; then
        local simple_msg="🔨 <b>POLLUX KERNEL · Forge Halted</b>
=====================================
⚙️ <b>Build:</b> #${BUILD_NUM}
📱 <b>Device:</b> Redmi 12 (fire) / MT6768
🌐 <b>Tag:</b> <code>${TAG}</code>-$(date +%Y%m%d)-${SHA}
⚠️ <b>Status:</b> ❌ CONSTRUCTION FAILED
=====================================
🔍 <a href='${BUILD_URL}'>Check Forge Logs</a>"
        send_to_channel "$CHANNEL_ID" "$simple_msg"
        echo "✅ Simple build failure notification sent to update channel."
    fi

    # 2. Kirim detail log error ke ERROR_CHANNEL_ID (Dump channel)
    # Jika ERROR_CHANNEL_ID kosong, fallback kirim ke CHANNEL_ID
    local dump_target="${ERROR_CHANNEL_ID:-$CHANNEL_ID}"
    if [ -n "$dump_target" ]; then
        local detail_msg="📢 <b>Pollux Kernel Info</b>
❌ <b>Pollux Kernel Build #${BUILD_NUM} Failed</b>

<b>Device:</b> Redmi 12 (fire) / MT6768
<b>Tag:</b> <code>${TAG}</code>-$(date +%Y%m%d)-${SHA}
<b>Error:</b> <b>${error_type}</b>
<b>Step:</b> ${failed_step}
=====================================
<b>Error Context:</b>
<pre><code>${error_context}</code></pre>
=====================================
🔍 <a href='${BUILD_URL}'>View Build Log</a>"
        send_to_channel "$dump_target" "$detail_msg"
        echo "✅ Detailed error log notification sent."
    fi
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
