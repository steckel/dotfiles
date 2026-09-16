# Agent Instructions & Architecture Guide (AGENTS.md)

This document guides AI agents and contributors on the architectural separation, feature classification framework, and safety policies of this dotfiles repository.

---

## 1. Branch & Remote Architecture

This repository maintains a strict two-tier branch model:

| Branch / Tier | Remote | Role & Audience |
| :--- | :--- | :--- |
| **`master`** | `origin` (`github.com/...`) | **Public & Open-Source**: Generic, portable dotfiles that run on personal macOS and Linux systems without corporate dependencies. |
| **Variant Branches** (e.g. `work`, `corp`) | Internal enterprise remotes | **Internal Corporate Overlay**: Workstation environment configurations that periodically rebase or merge `master` and layer on internal tooling (`variants/<variant_name>/`). |

---

## 2. Feature Classification Framework

When implementing, refactoring, or reviewing dotfiles features, classify them into one of the following three categories:

### Category 1: Generic Core Features (Belongs on `master`)
Features that are portable, standard POSIX/Zsh/Tmux capabilities, and completely independent of proprietary corporate infrastructure.

- **Criteria**: Can this configuration run on a personal Mac, a fresh Ubuntu/Arch VM, or a personal server without internal network access or proprietary binaries? If yes, it belongs on `master`.
- **Examples**:
  - Zsh completion tuning (`zstyle` menu select, case-insensitive matcher-lists, process listing styles).
  - Terminal prompt ergonomics (e.g. compact single-line inside tmux, dual-line `user@host` outside tmux).
  - Generic tmux window management and flags (e.g. `@busy` status glyphs, `@unread` window toggles, equal split layouts).
  - Shell failsafe hooks (e.g. clearing `@busy` on prompt return).
  - OSC 52 terminal clipboard integration.

### Category 2: Hybrid Features with Generic Foundations (Candidates for Generalization)
Features that combine a standard, open-source Linux/POSIX capability with a corporate or proprietary backend.

- **Design Pattern**: Always decouple into two layers:
  1. **Generic base on `master`**: Standard hook, interface, or POSIX parser.
  2. **Corporate adapter in `variants/<variant>/`**: Corporate CLI wrappers, specific internal file paths, or authentication helpers.
- **Current Candidates & Iteration Roadmap**:
  - **Scheduled Reboot / Maintenance Countdown**:
    - *Generic Base*: Check standard Linux systemd countdown (`/run/systemd/shutdown/scheduled`).
    - *Variant Layer*: Query corporate VM daemons or maintenance schedulers.
  - **Version Control Prompt Integration**:
    - *Generic Base*: Support standalone Jujutsu (`.jj`) change ID and bookmark parsing alongside Git (`vcs_info`).
    - *Variant Layer*: Internal cloud monorepo workspace paths and pending code-review units.
  - **Remote Workstation Connection Helpers**:
    - *Generic Base*: Configurable `workstation` or `remotebox` SSH/Mosh connection wrapper.
    - *Variant Layer*: Corporate-approved wrappers (e.g. custom mosh with hardware token forwarding).

### Category 3: Strictly Proprietary Variant Features (Belongs ONLY in `variants/`)
Features that depend exclusively on internal corporate infrastructure, authentication, or policies.

- **Criteria**: Mentions internal hostnames, internal package managers, Single-Sign-On / ticket systems, internal code search / monorepo paths, or internal AI metadata.
- **Examples**:
  - Kerberos / corporate SSO ticket status and TTL countdowns.
  - Custom terminal multiplexer wrappers managing security-key socket forwarding.
  - Monorepo workspace completions and client tools.
  - Corporate MCP wrappers and internal airlock / repository installation scripts.
  - Internal web preview and port forwarding documentation.

---

## 3. Commit Hygiene & Leak Prevention

### Pre-Commit and Pre-Push Safety Hooks

Hook **contents are not tracked in this repository**. Only the installation
mechanism is generic and public; the hooks themselves are supplied locally by
the environment that needs them.

This is deliberate. Hook scripts accumulate environment-specific values —
scanner binary paths, blocked email domains, trusted remote patterns, internal
branch naming conventions. Committing them publishes exactly the information
the hooks exist to protect. A tracked hook that excludes itself from its own
scan is worse still: it becomes a blind spot in the one file most likely to
contain such values.

1. **Installation (`Makefile`)**:
   - `hooks/` is listed in `.gitignore` and is never committed.
   - `make hooks` copies any `hooks/pre-commit` and `hooks/pre-push` found
     locally into `.git/hooks/`, which git cannot track.
   - Copies, not symlinks: a symlink into the worktree dangles whenever a
     branch lacking `hooks/` is checked out, silently disabling the hooks on
     precisely the branches that get published. Re-run `make hooks` after
     editing a hook source.
   - `make hooks` also clears any stale `core.hooksPath`. While that setting
     is present git ignores `.git/hooks/` entirely, so leaving it set would
     silently disable every installed hook.
   - With no local `hooks/` directory the target is a no-op, so `make all`
     stays portable on machines that need no such gate.

2. **Expected hook behaviour** (the contract a local hook should implement):
   - **pre-commit**: on allowlisted public branches, block staging any
     `variants/<name>/` directory, and scan the staged diff and commit
     identity against the local pattern list.
   - **pre-push**: default-deny for non-allowlisted remotes. For any remote
     not recognised as internal, block branches outside the allowlist, block
     any commit tree containing `variants/`, and scan the **entire pushed
     commit range** — not just the tip. A term introduced in an intermediate
     commit and removed later is still published, and force-pushing does not
     unpublish it.
   - Scan **all** paths. Never exempt the hook directory from its own checks.
   - Treat every externally-supplied value as optional and degrade gracefully
     when unset, so a hook remains functional on an unprovisioned machine.

3. **Local Leak Patterns (`.git/leak_patterns`)**:
   - Generated during `make all` by the active variant, when one applies.
   - Never committed; stays local in `.git/`.
   - Pattern lists catch known strings only. They will not flag the names of
     the tools doing the scanning, so treat a clean scan as necessary rather
     than sufficient.

### Commit Identity & Metadata Rules
- **Commits on `master`**:
  - Author & Committer must be the personal/public identity (e.g. personal email).
  - Commit messages must NEVER contain:
    - Internal AI agent tags or conversation UUIDs.
    - Proprietary internal tool names or package names.
    - Corporate hostnames, internal domains, or corporate email addresses.
- **Commits on Variant Branches**:
  - Author & Committer use the corporate identity.
  - Must only be pushed to internal corporate remotes, NEVER to public `origin`.

---

## 4. Variant Integration Protocol
- Variants are placed in `variants/<variant_name>/`.
- Each variant provides `detect.sh` (or `detect`) and `variant.mk`.
- The root `zsh/.zshrc` on `master` generically sources `~/.zshrc.variant` if present.
- `variant-setup::` in `variant.mk` symlinks `variants/<variant>/zshrc` $\rightarrow$ `~/.zshrc.variant`.
- No variant-specific file names or company names may ever be hardcoded into `master`.
