---
name: kernel-build
description: Use ONLY for building the Pollux kernel with cyrene_clang toolchain. Handles toolchain setup, defconfig configuration, kernel compilation, and artifact packaging. NOT for repo init or patching.
---

# Skill: kernel-build

Builds the Pollux kernel using cyrene_clang toolchain.

## Prerequisites

- Kernel source initialized + patched (kernel-init + kernel-patch done)
- Linux build environment (GitHub Actions Ubuntu runner or local Linux)
- ~12GB+ free RAM, ~30GB+ free disk

## Steps

### 1. Set Up cyrene_clang Toolchain

Download latest cyrene_clang release:

```bash
# One-liner installer
bash <(wget -qO- https://raw.githubusercontent.com/naidrahiqa/cyrene_clang/main/get_clang.sh)

# Or manual
wget https://raw.githubusercontent.com/naidrahiqa/cyrene_clang/main/clang-version.txt
DOWNLOAD_URL=$(grep DOWNLOAD_URL clang-version.txt | cut -d= -f2)
wget "$DOWNLOAD_URL"
mkdir -p $HOME/toolchains
tar -I zstd -xf cyrene-clang-*.tar.zst -C $HOME/toolchains/
```

Set PATH:
```bash
export PATH="$HOME/toolchains/cyrene/bin:$PATH"
```

### 2. Configure Defconfig

Create/update Pollux defconfig:

```bash
# Copy existing MT6768 defconfig as base
cp arch/arm64/configs/mt6768_defconfig arch/arm64/configs/fire_defconfig

# Or merge with ReSukiSU configs
cat <<EOF >> arch/arm64/configs/fire_defconfig
# ReSukiSU
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_KSU_MULTI_MANAGER_SUPPORT=y

# Pollux
CONFIG_LOCALVERSION="-Pollux"
EOF
```

Generate .config:
```bash
make O=out ARCH=arm64 fire_defconfig
```

### 3. Build Kernel

```bash
make -j$(nproc) \
  O=out \
  ARCH=arm64 \
  CC=clang \
  LD=ld.lld \
  AR=llvm-ar \
  NM=llvm-nm \
  STRIP=llvm-strip \
  OBJCOPY=llvm-objcopy \
  OBJDUMP=llvm-objdump \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=aarch64-linux-gnu- \
  2>&1 | tee build.log
```

### 4. Package Artifacts

```bash
# Kernel image
cp out/arch/arm64/boot/Image.gz out/

# Device tree blobs
cp out/arch/arm64/boot/dts/mediatek/*.dtb out/

# DTBO (if applicable)
find out/arch/arm64/boot/dts -name "*.dtbo" -exec cp {} out/ \;

# Module tree (optional)
make O=out ARCH=arm64 modules_install INSTALL_MOD_PATH=out/modules

# AnyKernel3 flashable zip
cp out/Image.gz AnyKernel3/
cp anykernel.sh AnyKernel3/anykernel.sh
cd AnyKernel3
zip -r9 ../pollux-<tag>-flashable.zip . -x '*.git*'
cd ..

# Archive
cd out && tar -I zstd -cf ../pollux-<tag>.tar.zst * && cd ..
```

### 5. Verify

```bash
# Check kernel version
strings out/arch/arm64/boot/Image.gz | grep "Pollux"

# Check KernelSU symbols
strings out/vmlinux | grep kernelsu

# Check size
ls -lh out/Image.gz
```

## Input Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `DEFCONFIG` | `fire_defconfig` | Target defconfig name |
| `ARCH` | `arm64` | Target architecture |
| `CLANG_PATH` | `$HOME/toolchains/cyrene` | Path to cyrene_clang |
| `JOBS` | `nproc` | Parallel build jobs |
| `OUT_DIR` | `out` | Build output directory |

## CI Integration

For GitHub Actions, use `ubuntu-22.04` or `ubuntu-24.04` runner:

```yaml
- name: Checkout
  uses: actions/checkout@v4
  with:
    submodules: 'recursive'

- name: Setup cyrene_clang
  run: |
    bash <(wget -qO- https://raw.githubusercontent.com/naidrahiqa/cyrene_clang/main/get_clang.sh)
    echo "$HOME/toolchains/cyrene/bin" >> $GITHUB_PATH

- name: Build kernel
  run: |
    make O=out ARCH=arm64 fire_defconfig
    make -j$(nproc) O=out ARCH=arm64 CC=clang ...

- name: Create flashable zip
  run: |
    cp out/Image.gz AnyKernel3/
    cp anykernel.sh AnyKernel3/anykernel.sh
    cd AnyKernel3 && zip -r9 ../pollux-<tag>-flashable.zip . -x '*.git*'
```

## Troubleshooting

- **LLVM IAS errors**: Try `LLVM_IAS=0` to use GNU assembler
- **Out of memory**: Reduce `-j` jobs
- **Missing toolchain**: Run `clang --version` to verify
- **LTO issues**: Add `LTO=thin` or `LTO=none` to make flags
