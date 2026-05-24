---
name: kernel-patch
description: Use ONLY for applying KernelSU-Next (legacy branch) as submodule and applying SUSFS patches via susf4ksu-legacy/apply.sh --kernelsu-next --mtk. NOT for initial repo setup or building.
---

# Skill: kernel-patch

Applies KernelSU-Next and SUSFS to the Pollux kernel source.

## Prerequisites

- Kernel source must already be initialized (run kernel-init first)
- Working directory must be the kernel root
- `patch`, `python3`, `findutils`, `sed` must be available

## Steps

### 1. Add KernelSU-Next as Submodule

```bash
git submodule add -b legacy https://github.com/KernelSU-Next/KernelSU-Next.git kernel/
```

Verify structure:
```
kernel/
├── kernel/          # KSU kernel module source
├── uapi/            # KSU userspace API headers
└── ...
```

### 2. Integrate KernelSU-Next into Build

Add to `kernel/Makefile` include at the end of the main kernel Makefile, or add objects to the relevant Kconfig/Kbuild:

For 4.19 kernels, add to the top-level `Makefile`:
```makefile
# KernelSU-Next
ifneq ($(wildcard $(srctree)/kernel),)
-include kernel/Makefile
endif
```

Or integrate via `arch/arm64/configs/fire_defconfig`:
```
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
```

### 3. Clone susf4ksu-legacy

```bash
git clone --depth=1 https://github.com/naidrahiqa/susf4ksu-legacy.git ../susf4ksu-legacy
```

### 4. Apply SUSFS Patches

```bash
bash ../susf4ksu-legacy/core-scripts/apply.sh . --kernelsu-next --mtk
```

Flags:
- `--kernelsu-next` : Use KernelSU-Next dispatch (sys_reboot-based, not prctl)
- `--mtk` : Apply MediaTek platform fixups (MTK include paths, KABI compat)

The script is idempotent — safe to re-run.

### 5. Verify

```bash
bash ../susf4ksu-legacy/core-scripts/verify.sh . fire_defconfig
```

Checks:
- `fs/susfs.c` exists
- `include/linux/susfs.h` exists
- No stale `susfs_def.h` includes in kernel/ source
- No `.rej` files
- Defconfig SUSFS options present

### 6. Commit

```bash
git add -A
git commit -m "Pollux: Integrate KernelSU-Next + SUSFS

KernelSU-Next: legacy branch
SUSFS: simonpunk/susfs4ksu v2.2.0 backport
"
```

## Input Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `SUSFS_REPO` | `naidrahiqa/susf4ksu-legacy` | SUSFS backport repo |
| `KERNELSU_BRANCH` | `legacy` | KernelSU-Next branch |
| `SUSFS_FLAGS` | `--kernelsu-next --mtk` | Flags for apply.sh |

## Troubleshooting

- **Patch rejects (.rej files)**: Run `wiggle` fallback or manually resolve
- **Missing syscall**: For 4.19, `get_cred_rcu` / `path_umount` may need backport — check `kernel/KernelSU-Next/007-susfs-for-kernelsu-next.patch`
- **MTK header errors**: Re-run with `--mtk` flag
