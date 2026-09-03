# Dotfiles Variants

This directory provides a modular extension system for platform- and organization-specific dotfiles variants (for example, corporate workstations, cloud development environments, or specialized servers).

## Architecture

The `master` branch maintains the core dotfiles and the generic variant discovery engine. Specific variants can be implemented and maintained on separate Git branches (e.g. `work`, `corp`, etc.).

This separation ensures:
1. The `master` branch remains clean and free of proprietary tooling, company hostnames, or corporate paths.
2. Variant branches can periodically merge `master` (`git merge master`) to receive core dotfiles updates cleanly without merge conflicts.
3. Users can clone and use the same repository across both personal and work environments.

## Directory Structure

Each variant is placed in a subdirectory under `variants/`:

```
variants/<variant_name>/
├── detect.sh      # (Required) Executable detection script
├── variant.mk     # (Optional) Makefile overrides and hooks
└── zshrc          # (Optional) Variant-specific shell configuration
```

### 1. `detect.sh` (or `detect`)
- **Executable**: Must have executable permissions (`chmod +x detect.sh`).
- **Exit Code**: Exit `0` if the current machine matches this variant; exit non-zero otherwise.
- **Output**: Print a human-readable description of the detected environment to stdout (e.g. `Corporate Linux Workstation`).

### 2. `variant.mk`
Included automatically by the root `Makefile` when the variant is detected.
Supported variables and hooks:
- `VARIANT_CUSTOM_TMUX := 1`: Tells `Makefile` not to install tmux via Homebrew, and to invoke `variant-tmux` instead.
- `variant-tmux`: Target that configures the variant's tmux setup.
- `variant-setup::`: Double-colon target executed during `make all` (e.g. symlinking variant shell configs).
- `variant-down::`: Double-colon target executed during teardown (`make tmux-down`).

### 3. Shell Configuration
Any shell configurations can be symlinked into `$HOME` during `variant-setup::`. The root `zsh/.zshrc` automatically sources `~/.zshrc.variant` if present.

## Manual Override

You can manually force a specific variant or disable variant detection:

```bash
# Force a specific variant
make VARIANT=work

# Force standard personal profile (disable variants)
make VARIANT=none
```
