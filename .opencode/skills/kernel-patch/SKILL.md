---
name: kernel-patch
description: Use ONLY for adding ReSukiSU as submodule to the Pollux kernel. NOT for initial repo setup or building.
---

# Skill: kernel-patch

Integrates ReSukiSU (Resurrection KernelSU) into the Pollux kernel source.

## Prerequisites

- Kernel source must already be initialized (run kernel-init first)
- Working directory must be the kernel root
- Internet connection for cloning submodule

## Steps

### 1. Add ReSukiSU as Submodule

```bash
git submodule add -b main https://github.com/ReSukiSU/ReSukiSU.git KernelSU
```

Verify structure:
```
KernelSU/
├── kernel/          # KSU kernel module source
├── uapi/            # KSU userspace API headers
└── ...
```

### 2. Configure Defconfig

Add to `arch/arm64/configs/fire_defconfig`:
```
# ReSukiSU
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_KSU_MULTI_MANAGER_SUPPORT=y
```

Note:
- `CONFIG_KSU_MANUAL_HOOK=y`: Required for non-GKI kernels (< 5.10)
- `CONFIG_KSU_MULTI_MANAGER_SUPPORT=y`: Support KernelSU/MKSU/RKSU/SukiSU managers

### 3. Verify

```bash
test -f KernelSU/kernel/Kconfig && echo "OK"
grep -q CONFIG_KSU=y arch/arm64/configs/fire_defconfig && echo "Defconfig OK"
```

### 4. Commit

```bash
git add -A
git commit -m "Pollux: Integrate ReSukiSU

ReSukiSU: main branch (Resurrection KernelSU)
Manual hook mode for non-GKI 4.19 kernel
Multi-manager support enabled
"
```

## Input Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `RESUKISU_REPO` | `ReSukiSU/ReSukiSU` | ReSukiSU repository |
| `RESUKISU_BRANCH` | `main` | ReSukiSU branch |

## Troubleshooting

- **Submodule clone fails**: Check internet/GitHub access. Try `git submodule add --depth=1`
- **Kconfig not found**: Verify `KernelSU/kernel/Kconfig` exists after clone
- **Manual hook compile errors**: Check ReSukiSU docs at https://resukisu.github.io/guide/manual-integrate.html
