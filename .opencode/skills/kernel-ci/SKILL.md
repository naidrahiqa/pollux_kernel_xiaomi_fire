---
name: kernel-ci
description: Use ONLY for creating or modifying GitHub Actions CI/CD workflows for the Pollux kernel build. Handles build pipeline, Telegram notifications, version management, changelog generation, and release publishing.
---

# Skill: kernel-ci

Sets up GitHub Actions CI/CD for automated Pollux kernel builds.

## File Structure

```
.github/
├── workflows/
│   ├── build.yml          ← Orchestrator: Telegram, versioning, changelog, release
│   ├── build-core.yml     ← Reusable workflow: actual kernel build (deps, toolchain, compile)
│   └── patch.yml          ← KernelSU/SUSFS patch workflow (manual trigger)
├── scripts/
│   ├── version.sh         ← Version management (PolluxXDDMMYY)
│   ├── generate-changelog.sh  ← Changelog from git log
│   └── notify-telegram.sh ← Telegram notifications
```

## Version Management

### Format: Semver (`v{major}.{minor}.{patch}[-variant]`)

| Variant | Format | Example | When |
|---------|--------|---------|------|
| **Nightly** | `v0.1.0-nightly.YYYYMMDD` | `v0.1.0-nightly.20260702` | Auto on push to main |
| **Stable** | `v{major}.{minor}.{patch}` | `v1.0.0` | Manual dispatch, tested |
| **Hotfix** | `v{major}.{minor}.{patch+1}` | `v1.0.1` | Manual dispatch, urgent fix |

### Source: `.github/scripts/version.sh`

```bash
source .github/scripts/version.sh "${VARIANT:-0}"
# Sets:
#   POLLUX_VERSION=v0.1.0-nightly.20260702
#   POLLUX_TAG=v0.1.0-nightly.20260702
#   POLLUX_VARIANT_NAME=nightly
#   LOCALVERSION=-Pollux-v0.1.0-nightly.20260702
```

## Telegram Notifications

### Source: `.github/scripts/notify-telegram.sh`

Usage:
```bash
bash notify-telegram.sh start <version> <tag>
bash notify-telegram.sh success <version> <tag> [changelog_file]
bash notify-telegram.sh failed <version> <tag> [error_log]
```

### Notification Formats

**Build Start:**
```
🔨 Pollux Kernel Build Started
Device: Redmi 12 (fire) / MT6768
Build: #19
Tag: v0.1.0-nightly.20260702
Commit: abc1234
Message: feat: add KSU support
Run: GitHub Actions
⏳ Waiting...
```

**Build Success:**
```
✅ Pollux v0.1.0-nightly.20260702 Released!
Device: Redmi 12 (fire) / MT6768
Tag: v0.1.0-nightly.20260702
Commit: abc1234def5678
Release: Download link

🛠 Toolchains
• Cyrene Clang 22.1.0

🔌 Integrations
• KernelSU-Next legacy
• SUSFS v2.2.0 (backport)

📋 Changelog
• feat: add KSU support
• fix: memory leak in driver
• security: update CIP to 134
```

**Build Failed:**
```
📢 Pollux Kernel Info
❌ Pollux Kernel Build #19 Failed

Device: Redmi 12 (fire) / MT6768
Tag: v0.1.0-nightly.20260702
Error: MAKE ERROR
Step: Build kernel (compile error)

Error Context:
(last 15 lines of build.log)

View Build Log
```

## Secrets Setup

### Required GitHub Secrets

Go to: `Settings → Secrets and variables → Actions → New repository secret`

| Secret | Description | How to get |
|--------|-------------|------------|
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather | Chat `@BotFather` → `/newbot` → set name → get token |
| `TELEGRAM_CHANNEL_ID` | Channel/chat ID | Add bot to channel → send any msg → `https://api.telegram.org/bot<TOKEN>/getUpdates` → copy `chat.id` |

### Setup Steps

1. **Create bot**: `/newbot` to @BotFather → name it (e.g., `PolluxKernelBot`)
2. **Create channel**: Make a Telegram channel (e.g., `Pollux Kernel Updates`)
3. **Add bot**: Add your bot as admin to the channel
4. **Get channel ID**: Send a message in channel → visit:
   `https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/getUpdates`
   → Look for `"chat":{"id":-1001234567890}` → that's your channel ID
5. **Set secrets** in GitHub repo:
   - `TELEGRAM_BOT_TOKEN`: `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`
   - `TELEGRAM_CHANNEL_ID`: `-1001234567890`

## Changelog Generator

### Source: `.github/scripts/generate-changelog.sh`

Groups commits by type:
- 🚀 Features (`feat:`)
- 🐛 Bug Fixes (`fix:`)
- 🔒 Security (`security:`, `CVE`, `cip`, `upstream`)
- 🔧 Updates (`update:`, `bump:`, `upgrade:`, `merge:`)
- 📦 All Commits (everything else)

## Workflows

### build.yml — Orchestrator

```yaml
Triggers:
  - push to main
  - workflow_dispatch (with variant, defconfig, LTO inputs)

Jobs:
  1. version       → Generate version via version.sh
  2. notify-start  → Telegram "Build Started" notification
  3. core-build    → Calls build-core.yml (reusable workflow)
  4. generate-changelog → Changelog from git log (if build succeeded)
  5. create-release → GitHub Release with artifacts (if build succeeded)
  6. notify-success → Telegram "Build Released" (if build succeeded)
  7. notify-failed  → Telegram error notification (if build failed)
```

### build-core.yml — Core Build (Reusable)

```yaml
Called by: build.yml (via `uses: ./.github/workflows/build-core.yml`)

Steps:
  1. Checkout (submodules: recursive)
  2. Install deps (system clang via apt + build tools)
  3. Setup cyrene_clang (NOT added to PATH — only for LD/AR/etc.)
  4. Clone SUSFS backport + apply patches
  5. Check for .rej files
  6. make defconfig (CC=gcc)
  7. make -j$(nproc) CC=clang (system clang), LD/AR/etc from cyrene_clang
  8. Final check — set status output (NO exit 1!)
  9. Package artifacts (tar.zst)
  10. Upload as GitHub Actions artifact

Outputs:
  - status: "success" or "failed"
```

Key design:
- CC=clang → system `/usr/bin/clang` (supports x86_64 + aarch64 targets)
- LD/AR/NM/STRIP/OBJCOPY/OBJDUMP → from cyrene_clang toolchain
- CROSS_COMPILE NOT set → Makefile.clang uses CLANG_TARGET_FLAGS_arm64
- Final check uses `if: always()` so output is set even on failure

### patch.yml — KernelSU + SUSFS Patcher

```yaml
Trigger: workflow_dispatch (manual)

Steps:
  1. Checkout + submodules
  2. Install deps (patch, python3, wiggle)
  3. Clone susf4ksu-legacy
  4. Run apply.sh --kernelsu-next --mtk
  5. Verify patches
  6. Check .rej files
  7. Commit + push
```

## Release Format

### Tag: Semver (`v1.0.0-nightly.YYYYMMDD`)
- Automated via `version.sh`
- Created by `softprops/action-gh-release@v2`
- Body: Generated changelog with device info, toolchain, commits
- Assets: `pollux-kernel-<tag>.tar.zst` + `Image.gz` + DTB files

### Changelog Format
```markdown
## What's New in v0.1.0-nightly.20260702

### Info
- **Device:** Redmi 12 (fire) / MT6768
- **Kernel:** 4.19.325-cip134
- **Toolchain:** Cyrene Clang 22.1.0
- **Integration:** KernelSU-Next v3.2.0-legacy + SUSFS v2.2.0
- **Variant:** nightly

### 🚀 Features
- abc1234 feat: add KSU support
- def5678 feat: implement thermal management

### 🐛 Bug Fixes
- ghi9012 fix: memory leak in driver

### 🔒 Security
- jkl3456 security: update CIP to 134

### 🔧 Updates
- mno7890 update: bump toolchain version
```

## Best Practices
1. Set both `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHANNEL_ID` before push
2. Run `patch.yml` workflow first to apply KSU+SUSFS before building
3. Use `workflow_dispatch` for variant selection (nightly/stable/hotfix)
4. Commit messages should use prefixes: `feat:`, `fix:`, `security:`, `update:`

## Input Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `TELEGRAM_BOT_TOKEN` | (secret) | Bot token for Telegram |
| `TELEGRAM_CHANNEL_ID` | (secret) | Channel ID for Telegram |
| `TELEGRAM_ERROR_CHANNEL_ID` | (secret) | Error channel ID for Telegram |
| Variant | `0 — Nightly` | Build variant (0=nightly, 1=stable, 2=hotfix) |
| Defconfig | `fire_defconfig` | Target defconfig |
| LTO | `none` | LTO mode (none/thin/full) |

## Troubleshooting

- **Telegram not sending**: Check secrets are set correctly
- **Wrong channel ID**: Run getUpdates with curl to verify
- **Release duplicate**: Delete tag locally + remote, re-run
- **Changelog empty**: No commits since last tag — first release
- **Build OOM/broken pipe**: Use `LTO=none` and `-j4`
- **Release 403 error**: Add `permissions: contents: write` to job
