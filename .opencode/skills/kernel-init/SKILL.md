---
name: kernel-init
description: Use ONLY when initializing or re-initializing the Pollux kernel repo. Handles git init, cloning base kernel from mt6768-dev/android_kernel_xiaomi_fire (lineage-23.2), applying upstream CIP patches (v4.19.325-cip124 -> cip134), and setting LOCALVERSION. NOT for applying KernelSU/SUSFS patches or building.
---

# Skill: kernel-init

Initializes the Pollux kernel repository from scratch.

## Repo Structure

```
pollux_kernel_xiaomi_fire/
├── base: mt6768-dev/android_kernel_xiaomi_fire @ lineage-23.2
│   └── v4.19.325-cip124 (already CIP-based)
├── upstream: linux-cip v4.19.325-cip134
│   └── Apply incremental patches cip124..cip134
├── arch/arm64/configs/fire_defconfig (custom Pollux defconfig)
├── kernel/ (KernelSU-Next submodule)
└── .github/workflows/build.yml
```

## Steps

### 1. Init Git + Set Remote

```bash
cd /path/to/pollux_kernel_xiaomi_fire
git init
git remote add origin https://github.com/naidrahiqa/pollux_kernel_xiaomi_fire.git
```

### 2. Clone Base Kernel

```bash
git remote add base https://github.com/mt6768-dev/android_kernel_xiaomi_fire.git
git fetch base lineage-23.2 --depth=1
git merge-base --is-ancestor FETCH_HEAD HEAD 2>/dev/null || git reset --hard FETCH_HEAD
```

### 3. Apply Upstream CIP v4.19.325-cip134

The base is already at v4.19.325-cip124. Apply incremental CIP patches:

```bash
# Add CIP remote
git remote add cip https://git.kernel.org/pub/scm/linux/kernel/git/cip/linux-cip.git
git fetch cip v4.19.325-cip134 --depth=1

# Generate patch range from current tag to target tag
git format-patch v4.19.325-cip124..v4.19.325-cip134 --stdout > ../cip-upgrade.patch
git am ../cip-upgrade.patch

# Update localversion-cip
echo "-cip134" > localversion-cip
```

If conflicts occur, resolve manually and `git am --continue`.

### 4. Set LOCALVERSION

Edit `Makefile`:

```
EXTRAVERSION = -Pollux
```

Or pass via defconfig: `CONFIG_LOCALVERSION="-Pollux"`.

### 5. Create Initial Commit

```bash
git add -A
git commit -m "Pollux: Initial import based on v4.19.325-cip134

Base: mt6768-dev/android_kernel_xiaomi_fire @ lineage-23.2
Upstream: linux-cip v4.19.325-cip134
"
git branch -M main
```

## Verification

```bash
head -5 Makefile  # VERSION=4, PATCHLEVEL=19, SUBLEVEL=325
cat localversion-cip  # should be "-cip134"
git log --oneline -3
```

## Input Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_REPO` | `mt6768-dev/android_kernel_xiaomi_fire` | Base kernel repo |
| `BASE_BRANCH` | `lineage-23.2` | Base kernel branch |
| `CIP_TAG` | `v4.19.325-cip134` | Upstream CIP tag |
| `LOCALVERSION` | `-Pollux` | Kernel local version string |
