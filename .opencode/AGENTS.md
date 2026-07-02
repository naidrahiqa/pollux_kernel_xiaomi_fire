# AGENTS.md — Pollux Kernel Orchestrator

## Team Registry

| Role | Skill ID | Skill File | Assigned Triggers | Status |
|------|----------|------------|-------------------|--------|
| **Kernel Initializer** | `kernel-init` | `skills/kernel-init/SKILL.md` | Repo init, clone base, CIP upgrade, LOCALVERSION | Active |
| **Kernel Patcher** | `kernel-patch` | `skills/kernel-patch/SKILL.md` | Add KSU-Next, apply SUSFS, fixup MTK | Active |
| **Kernel Builder** | `kernel-build` | `skills/kernel-build/SKILL.md` | Build with cyrene_clang, packaging | Active |
| **CI/CD Engineer** | `kernel-ci` | `skills/kernel-ci/SKILL.md` | GitHub Actions workflow, release automation | Active |

---

## Available Skills

### Skill: Kernel Initializer
- **ID**: `kernel-init`
- **File**: `skills/kernel-init/SKILL.md`
- **Responsibility**: Initialize empty repo with base kernel + upstream CIP patches
- **Triggers**: `repo_baru`, `reset_kernel`, `upgrade_cip`, `manual_request`
- **Input Type**: `git-context`, `cli-args`
- **Output Type**: `git-commit`, `markdown`
- **Dependencies**: None
- **Estimated Runtime**: ~60-180 seconds (clone), ~120+ seconds (CIP merge)
- **Severity Levels**: `critical` (gagal init = block semua)
- **Owner Role**: Kernel Initializer

**Details**:
- Clones `mt6768-dev/android_kernel_xiaomi_fire@lineage-23.2` (v4.19.325-cip124)
- Applies incremental CIP patches `cip124..cip134`
- Sets `LOCALVERSION=-Pollux` di Makefile
- Creates initial commit dengan metadata lengkap

---

### Skill: Kernel Patcher
- **ID**: `kernel-patch`
- **File**: `skills/kernel-patch/SKILL.md`
- **Responsibility**: Integrate KernelSU-Next + apply SUSFS backport patches
- **Triggers**: `add_ksu`, `apply_susfs`, `patch_kernel`, `manual_request`
- **Input Type**: `directory` (kernel source)
- **Output Type**: `git-commit`, `markdown` (verification report)
- **Dependencies**: `kernel-init` (source must exist)
- **Estimated Runtime**: ~120-300 seconds
- **Severity Levels**: `critical` (patch gagal), `high` (conflict warning)
- **Owner Role**: Kernel Patcher

**Details**:
- Adds KernelSU-Next (`legacy` branch) via git submodule ke `kernel/`
- Clones `naidrahiqa/susf4ksu-legacy` untuk patch files
- Runs `core-scripts/apply.sh --kernelsu-next --mtk` (idempotent)
- Verifies: `fs/susfs.c`, `include/linux/susfs.h`, no `.rej` files
- Fixup: MTK KABI compat, namespace hooks, selinux placement

---

### Skill: Kernel Builder
- **ID**: `kernel-build`
- **File**: `skills/kernel-build/SKILL.md`
- **Responsibility**: Build kernel artifact dengan cyrene_clang toolchain
- **Triggers**: `build_kernel`, `rebuild`, `manual_request`
- **Input Type**: `directory` (kernel source), `cli-args` (defconfig, LTO mode)
- **Output Type**: `artifact` (Image.gz, dtb, dtbo), `json` (build metadata)
- **Dependencies**: `kernel-init`, `kernel-patch` (source siap)
- **Estimated Runtime**: ~600-1800 seconds (full build)
- **Severity Levels**: `critical` (compile error), `high` (warning), `medium` (optimization)
- **Owner Role**: Kernel Builder

**Details**:
- Downloads cyrene_clang dari release terbaru (LLVM 22.1.0+)
- Config: `fire_defconfig` (copy dari mt6768_defconfig + SUSFS options)
- Build flags: `CC=clang`, `LD=ld.lld`, `AR=llvm-ar`, etc.
- LTO modes: `thin` (default), `full`, `none`
- Output: `Image.gz`, `*.dtb`, `*.dtbo`, `build.log`

---

### Skill: CI/CD Engineer
- **ID**: `kernel-ci`
- **File**: `skills/kernel-ci/SKILL.md`
- **Responsibility**: Setup and maintain GitHub Actions CI/CD pipeline
- **Triggers**: `setup_ci`, `modify_workflow`, `add_release`, `manual_request`
- **Input Type**: `git-context`, `cli-args`
- **Output Type**: `yaml` (workflow file), `markdown`
- **Dependencies**: None (can run independently)
- **Estimated Runtime**: ~30-60 seconds (file creation)
- **Severity Levels**: `high` (workflow broken), `medium` (optimization)
- **Owner Role**: CI/CD Engineer

**Details**:
- Creates `.github/workflows/build.yml`
- Supports triggers: `push`, `pull_request`, `workflow_dispatch`
- Build matrix: defconfig choice, LTO mode choice
- Auto-download cyrene_clang via `get_clang.sh`
- Uploads packaged kernel artifacts
- Optional release automation via tag

---

## Workflow Definitions

### Workflow 1: Full Kernel Setup
**ID**: `full-setup`
**Trigger**: User requests "setup kernel baru" or "init kernel from scratch"
**Type**: Sequential (each step depends on previous)

```yaml
steps:
  - step_id: init-repo
    skill_id: kernel-init
    condition: always
    on_failure: halt
    retry_count: 1
    description: "Clone base + apply CIP upstream + initial commit"

  - step_id: patch-kernel
    skill_id: kernel-patch
    condition: on_success(init-repo)
    on_failure: halt
    retry_count: 1
    description: "Add KernelSU-Next + SUSFS patches"

  - step_id: setup-ci
    skill_id: kernel-ci
    condition: on_success(patch-kernel)
    on_failure: notify_only
    description: "Create GitHub Actions workflow"

output_action: "Print summary + push ready"
estimated_duration: ~300-600 seconds
```

**Execution Flow**:
```
[kernel-init] ──success──→ [kernel-patch] ──success──→ [kernel-ci] ───→ DONE
     │                        │                        │
     └──fail→ HALT            └──fail→ HALT            └──fail→ NOTIFY
```

---

### Workflow 2: Build Kernel
**ID**: `build-kernel`
**Trigger**: User says "build kernel", or via GitHub Actions
**Type**: Single skill (can be parallel with itself for different configs)

```yaml
steps:
  - step_id: compile
    skill_id: kernel-build
    condition: always
    on_failure: halt
    retry_count: 0  # no retry on long builds
    parameters:
      defconfig: fire_defconfig
      lto: thin

output_action: "Print artifact paths + build log location"
estimated_duration: ~600-1800 seconds
```

**Execution Flow**:
```
[kernel-build]
     │
     ├──success→ Print "Build OK: out/Image.gz (XX MB)"
     │
     └──fail→ Print build.log errors + HALT
```

---

### Workflow 3: CI Trigger (GitHub Actions)
**ID**: `ci-build`
**Trigger**: Push to `main`, PR opened, `workflow_dispatch`
**Type**: Event-triggered, runs in GitHub runner

```yaml
steps:
  - step_id: checkout
    skill_id: (built-in git checkout)
    condition: always

  - step_id: deps
    skill_id: (apt install build-essential, etc.)
    condition: always

  - step_id: toolchain
    skill_id: kernel-build (partial: setup clang only)
    condition: always

  - step_id: configure
    skill_id: kernel-build (partial: make defconfig)
    condition: always

  - step_id: compile
    skill_id: kernel-build (partial: make -j)
    condition: always
    on_failure: halt

  - step_id: package
    skill_id: kernel-build (partial: cp artifacts)
    condition: always

  - step_id: upload
    skill_id: (actions/upload-artifact)
    condition: always

output_action: "Upload kernel artifacts to GitHub"
estimated_duration: ~900-2400 seconds (CI runner dependent)
```

---

### Workflow 4: Quick Patch Update
**ID**: `patch-update`
**Trigger**: User says "update patches", "reapply susfs", "update ksu"

```yaml
steps:
  - step_id: repatch
    skill_id: kernel-patch
    condition: always
    on_failure: halt
    retry_count: 1
    parameters:
      force_reapply: true

  - step_id: verify
    skill_id: kernel-patch (verify only)
    condition: on_success(repatch)
    on_failure: notify_only

output_action: "Print verification report"
estimated_duration: ~60-180 seconds
```

---

## Skill Routing Logic

### Event-Based Routing

```yaml
triggers:
  "repo_baru":
    - skills: [kernel-init]
      parallel: false
      on_failure: halt
    - description: "Init repo dari scratch"

  "add_ksu":
    - skills: [kernel-patch]
      parallel: false
      on_failure: halt
    - description: "Tambah KernelSU-Next submodule + SUSFS"

  "build_kernel":
    - skills: [kernel-build]
      parallel: false
      on_failure: halt
    - description: "Build kernel dengan fire_defconfig + cyrene_clang"

  "setup_ci":
    - skills: [kernel-ci]
      parallel: false
      on_failure: notify_only
    - description: "Setup GitHub Actions workflow"

  "full_setup":
    - skills: [kernel-init, kernel-patch, kernel-ci]
      parallel: false
      on_failure: halt
    - description: "Setup lengkap: init → patch → ci"
```

### Context-Based Routing

| Context | Skill(s) | Rationale |
|---------|----------|-----------|
| File changed in `kernel/` (KSU submodule) | `kernel-patch` | KSU update detected, need to re-verify patches |
| File changed in `.github/workflows/` | `kernel-ci` | CI config changed, validate/update |
| User mentions "clang", "compiler", "toolchain" | `kernel-build` | Build-related context |
| User mentions "cip", "upstream", "rebase" | `kernel-init` | Upstream update context |
| User mentions "kernelsu", "susfs", "patch" | `kernel-patch` | Patching context |
| User mentions "workflow", "github actions", "ci" | `kernel-ci` | CI/CD context |
| Empty directory / no `.git` | `kernel-init` (forced) | Fresh repo detected |

### Severity-Based Routing

| Severity | Action | Escalation |
|----------|--------|------------|
| **Critical** (compile error, patch conflict) | HALT immediately | Notify user with exact error |
| **High** (build warning, missing config) | Continue with warning | Log + notify user |
| **Medium** (optimization suggestion) | Continue silently | Include in summary report |
| **Low** (style, non-critical) | Continue silently | Add to end-of-run report |

---

## Team Workflow Orchestration

### Developer Workflow
1. **Developer wants to build kernel**
   - `kernel-init` (if repo not ready) → clone base + CIP
   - `kernel-patch` (if not patched) → add KSU + SUSFS
   - `kernel-build` → compile with cyrene_clang
   - Output: `out/Image.gz` + `out/*.dtb`

2. **Developer pushes to GitHub**
   - `.github/workflows/build.yml` triggers
   - GitHub Actions runner:
     - Checkout code
     - Install dependencies
     - Download cyrene_clang
     - `make fire_defconfig`
     - `make -j$(nproc) CC=clang ...`
     - Upload artifacts

### Review Process
1. User requests "check my kernel setup"
2. Run `kernel-patch` verify mode → check all patches applied
3. Run `kernel-build` dry-run → check defconfig validity
4. Report any missing pieces

### Release Process
1. Tag pushed (`v*`)
2. CI workflow runs in strict mode
3. `kernel-build` with `LTO=thin` + full optimization
4. Artifacts uploaded to release
5. Release notes generated

### Incident Response
- **Build failure**: Read `build.log`, identify error, fix, rebuild
- **Patch conflict**: Manual resolution needed, apply `wiggle` fallback
- **Toolchain missing**: Re-run `get_clang.sh` or download cyrene_clang release

---

## Skill Chaining

### Chain: Init → Patch → CI (Full Setup)

```
[kernel-init]
  Output: Initialized kernel source tree (git commit)
     │
     ▼
[kernel-patch]
  Input: Kernel source from kernel-init
  Output: Patched kernel with KSU + SUSFS (git commit)
     │
     ▼
[kernel-ci]
  Input: Kernel source from kernel-patch
  Output: .github/workflows/build.yml (git commit)
     │
     ▼
Ready to push to GitHub
```

### Chain: Build (Standalone)

```
[kernel-build]
  Input: Kernel source (already init + patched)
  Steps:
    1. Setup cyrene_clang (download + extract)
    2. make fire_defconfig (generate .config)
    3. make -j$(nproc) (compile)
    4. Package artifacts
  Output: out/Image.gz, out/*.dtb, build.log
```

### Chain: CI Build (GitHub Actions)

```
[Checkout] ──→ [Deps] ──→ [Toolchain] ──→ [Config] ──→ [Build] ──→ [Package] ──→ [Upload]
     │            │             │               │            │            │             │
     │            │             │               │            │            │             │
  git fetch    apt install   cyrene_clang    fire_defconfig  make -j    cp artifacts  upload-artifact
```

---

## CLI Interface

### Manual Skill Invocation

```bash
# Run individual skills
opencode-agent run kernel-init --path .
opencode-agent run kernel-patch --path .
opencode-agent run kernel-build --path . --defconfig fire_defconfig
opencode-agent run kernel-ci --path . --create-workflow

# Run with custom parameters
opencode-agent run kernel-build \
  --path . \
  --defconfig fire_defconfig \
  --lto thin \
  --jobs 16 \
  --output-dir out

# Run with flags
opencode-agent run kernel-patch --path . --force-reapply --skip-verify
opencode-agent run kernel-ci --path . --workflow-dispatch-only
```

### Workflow Invocation

```bash
# Run full setup workflow
opencode-agent workflow run full-setup --path .

# Run build workflow
opencode-agent workflow run build-kernel --path . --defconfig fire_defconfig

# Run with parameter overrides
opencode-agent workflow run build-kernel \
  --skip-init \
  --skip-patch \
  --lto full

# Dry-run (show what would happen without executing)
opencode-agent workflow run build-kernel --dry-run
```

### Info & Status Commands

```bash
# List available skills
opencode-agent skills list

# Show skill details
opencode-agent skills info kernel-build
opencode-agent skills info kernel-patch

# List available workflows
opencode-agent workflows list

# Show workflow details
opencode-agent workflow info build-kernel

# Validate AGENTS.md structure
opencode-agent validate-agents
```

### Debug Commands

```bash
# Test skill without running
opencode-agent test kernel-build --path . --dry-run

# Show skill dependency graph
opencode-agent skills graph

# Show workflow execution plan
opencode-agent workflow plan full-setup --path .
```

---

## Configuration

### workflow-config.yaml

```yaml
# Pollux Kernel Workflow Configuration
team:
  name: "Pollux Kernel Development"
  project: "pollux_kernel_xiaomi_fire"

skills:
  kernel-init:
    base_repo: "mt6768-dev/android_kernel_xiaomi_fire"
    base_branch: "lineage-23.2"
    cip_tag: "v4.19.325-cip134"
    localversion: "-Pollux"
    remote_origin: "https://github.com/naidrahiqa/pollux_kernel_xiaomi_fire.git"
    timeout_seconds: 300

  kernel-patch:
    susfs_repo: "https://github.com/naidrahiqa/susf4ksu-legacy"
    kernelsu_repo: "https://github.com/KernelSU-Next/KernelSU-Next.git"
    kernelsu_branch: "legacy"
    apply_flags: "--kernelsu-next --mtk"
    timeout_seconds: 300

  kernel-build:
    defconfig: "fire_defconfig"
    arch: "arm64"
    clang_repo: "https://github.com/naidrahiqa/cyrene_clang"
    lto_mode: "thin"
    jobs: 0  # 0 = auto (nproc)
    output_dir: "out"
    timeout_seconds: 3600

  kernel-ci:
    runner: "ubuntu-24.04"
    workflow_file: ".github/workflows/build.yml"
    artifact_retention_days: 7

workflows:
  full-setup:
    enabled: true
    strict_mode: true
    auto_commit: true

  build-kernel:
    enabled: true
    strict_mode: false
    parallel_jobs: 4

  ci-build:
    enabled: true
    strict_mode: true
    notify_on_failure: true

notifications:
  default_channels: ["console"]
  include_build_log: true
  include_artifacts: true

defaults:
  timeout_seconds: 600
  retry_count: 1
  log_level: "info"
```

---

## Monitoring & Metrics

### Skill Execution Metrics

```json
{
  "skill_id": "kernel-build",
  "metrics": {
    "last_execution": "2026-07-02T08:00:00Z",
    "execution_count": 5,
    "success_rate": 80.0,
    "average_runtime_seconds": 845,
    "artifact_size_mb": 12.4,
    "compile_errors": 1,
    "compile_warnings": 23
  }
}
```

```json
{
  "skill_id": "kernel-patch",
  "metrics": {
    "last_execution": "2026-07-02T07:55:00Z",
    "execution_count": 3,
    "success_rate": 100.0,
    "average_runtime_seconds": 45,
    "patches_applied": 7,
    "conflicts_resolved": 0,
    "fixup_scripts_run": 4
  }
}
```

### Workflow Metrics

```json
{
  "workflow_id": "full-setup",
  "metrics": {
    "execution_count": 2,
    "success_rate": 100.0,
    "average_duration_seconds": 180,
    "steps_total": 3,
    "steps_failed": 0
  }
}
```

### Tracked KPIs

| KPI | Target | Current |
|-----|--------|---------|
| Build success rate | > 90% | 80% |
| Average build time | < 15 min | 14 min |
| Patch apply success | 100% | 100% |
| CI workflow uptime | > 99% | 100% |
| Artifact size | < 20 MB | 12.4 MB |

---

## Troubleshooting

### If Skill Fails

```yaml
issue: "kernel-init fails - clone timeout"
solution: "Check internet connection. Use --depth=1 for shallow clone.
          Increase timeout_seconds in config."

issue: "kernel-patch fails - patch rejects (.rej files)"
solution: "1. Check .rej files: find . -name '*.rej'
           2. Try wiggle fallback: wiggle --replace
           3. Manually resolve conflicts
           4. Re-run apply.sh"

issue: "kernel-build fails - compile error"
solution: "1. Check build.log: tail -50 out/build.log
           2. Check defconfig: make fire_defconfig
           3. Try different LTO mode: LTO=none
           4. Check toolchain: clang --version"

issue: "kernel-ci fails - workflow syntax error"
solution: "1. Validate YAML: python3 -c 'import yaml; yaml.safe_load(open(\".github/workflows/build.yml\"))'
           2. Check indentation (YAML is strict)
           3. Verify actions versions exist"
```

### If Workflow Hangs

```yaml
symptom: "Build stuck at compile step"
check: "Check system resources: free -h; nproc"
action: "Kill build: Ctrl+C or cancel workflow. Reduce -j parameter."

symptom: "Patch apply hangs"
check: "Check if patch is waiting for input"
action: "Run with --batch mode. Use apply.sh (not manual patch)"
```

### Common Errors & Solutions

| Error | Cause | Fix |
|-------|-------|-----|
| `fatal: not a git repository` | Repo not init'd | Run `kernel-init` first |
| `patch: **** malformed patch` | Patch format mismatch | Check patch file encoding (LF, not CRLF) |
| `clang: not found` | Toolchain not installed | Run `get_clang.sh` or set PATH |
| `*** Configuration file "fire_defconfig" not found` | Defconfig missing | Create from `mt6768_defconfig` |
| `KernelSU-Next: No such file or directory` | Submodule not init'd | Run `git submodule update --init` |
| `susfs.c: No such file` | SUSFS not applied | Run `apply.sh --kernelsu-next --mtk` |

---

## Example Workflows

### Example 1: Full Setup from Scratch

```bash
# Step-by-step execution
opencode-agent run kernel-init --path .
# Output: Repo initialized with v4.19.325-cip134 + initial commit

opencode-agent run kernel-patch --path .
# Output: KernelSU-Next added + SUSFS patches applied + verified

opencode-agent run kernel-ci --path . --create-workflow
# Output: .github/workflows/build.yml created

# Or one-shot
opencode-agent workflow run full-setup --path .
```

**Expected Result**:
- Repo siap dengan base kernel + CIP upstream
- KernelSU-Next + SUSFS terintegrasi
- GitHub Actions workflow siap
- Tinggal `git push origin main`

---

### Example 2: Quick Build after Changes

```bash
# After making changes to kernel source
opencode-agent run kernel-build --path . --defconfig fire_defconfig
```

**Expected Result**:
- `out/Image.gz` — compressed kernel image
- `out/*.dtb` — device tree blobs
- `out/build.log` — full build log
- `out/.config` — kernel configuration used

---

### Example 3: CI/CD Release

```bash
# 1. Setup CI (one-time)
opencode-agent run kernel-ci --path .

# 2. Push to GitHub
git add -A
git commit -m "Pollux: v1.0 release"
git tag v1.0
git push origin main --tags

# 3. GitHub Actions runs automatically:
#    - Builds kernel with fire_defconfig
#    - Packages artifacts
#    - Creates GitHub Release
```

---

### Example 4: Patch Update Only

```bash
# When KernelSU-Next or SUSFS has updates
opencode-agent run kernel-patch --path . --force-reapply
```

**What happens**:
1. Fetches latest SUSFS patches
2. Re-applies all patches (idempotent)
3. Runs fixup scripts
4. Verifies everything
5. Ready to commit

---

## Material Reference

| Component | Repository | Version/Ref |
|-----------|------------|-------------|
| **Base kernel** | `mt6768-dev/android_kernel_xiaomi_fire` | `lineage-23.2` (v4.19.325-cip124) |
| **Upstream CIP** | `git.kernel.org/pub/scm/linux/kernel/git/cip/linux-cip.git` | `v4.19.325-cip134` |
| **Clang toolchain** | `naidrahiqa/cyrene_clang` | Latest release (LLVM 22.1.0) |
| **KernelSU-Next** | `KernelSU-Next/KernelSU-Next` | `legacy` branch |
| **SUSFS backport** | `naidrahiqa/susf4ksu-legacy` | `master` (v2.2.0 backport) |
| **AnyKernel3** | `naidrahiqa/AnyKernel3` | `master` (flashable zip creator) |
| **Output repo** | `naidrahiqa/pollux_kernel_xiaomi_fire` | `main` |

Device: **Xiaomi Fire (Redmi 12)** — MT6768 / Helio G88
