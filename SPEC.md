# VPS Setup Specification

## Overview

A single, re-runnable setup script that provisions a fresh Ubuntu (latest stable) x86_64 VPS with a complete development environment. Designed to be VPS-size agnostic (tested on 16GB and 32GB Hostinger instances). The script installs dev tools, modern CLI utilities, monitoring, and finishes with OpenClaw (Claude Code) as the last step.

The repo also serves as documentation for AI agents — a static `CLAUDE.md` describes the full environment so that any agent running on the VPS understands what tools are available, where they live, and how the system is configured.

---

## Target Environment

| Property       | Value                                |
| -------------- | ------------------------------------ |
| OS             | Ubuntu (latest stable, e.g. 25.10)   |
| Architecture   | x86_64                               |
| Provider       | Hostinger                            |
| VPS sizes      | 16GB, 32GB (script is size-agnostic) |
| Run as         | root                                 |
| SSH hardening  | Handled externally (not in scope)    |
| Firewall       | Handled externally (not in scope)    |

---

## Repo Structure

```
vps-setup/
├── setup.sh              # Single entry-point script (all logic in functions)
├── config.sh             # User-editable toggles and system settings
├── config/               # Token/key templates (gitignored actuals)
│   ├── github.env.example    # GitHub scoped token template
│   └── zai.env.example       # z.ai API key template
├── CLAUDE.md             # AI-agent-readable environment manifest
├── SPEC.md               # This file
└── README.md             # Human-readable setup instructions
```

**Single script architecture**: All installation logic lives in `setup.sh` as discrete functions. No separate module files. Each function handles one tool or category.

---

## Configuration (`config.sh`)

A sourceable shell file with **tool category toggles** (enable/disable) and **system settings**. Always installs latest stable versions — no version pinning.

### System Settings

| Setting         | Default           | Notes                          |
| --------------- | ----------------- | ------------------------------ |
| `TIMEZONE`      | `Europe/Berlin`   | System timezone                |
| `LOCALE`        | `en_US.UTF-8`     | System locale                  |
| `HOSTNAME`      | `""`              | Optional, set if non-empty     |

### Tool Category Toggles

| Toggle                 | Default | What it controls                                      |
| ---------------------- | ------- | ----------------------------------------------------- |
| `INSTALL_PYTHON`       | `true`  | pyenv + latest stable Python                          |
| `INSTALL_NODE`         | `true`  | nvm + latest LTS Node.js                              |
| `INSTALL_GO`           | `true`  | goenv + latest stable Go                              |
| `INSTALL_RUST`         | `true`  | rustup + stable + full dev tooling                    |
| `INSTALL_SWIFT`        | `true`  | swiftly + latest stable Swift                         |
| `INSTALL_CLI_TOOLS`    | `true`  | Modern CLI replacements (bat, eza, fd, rg, etc.)      |
| `INSTALL_MONITORING`   | `true`  | btop + terminal monitoring tools                      |
| `INSTALL_NEOVIM`       | `true`  | Neovim binary (no config/plugins)                     |
| `INSTALL_OPENCLAW`     | `true`  | OpenClaw / Claude Code (always last)                  |

---

## Installation Order

The script executes in this exact order. Dependencies flow downward.

### 1. System Packages (`apt`)

Update package index and install base dependencies:

- `build-essential`, `cmake`, `pkg-config`
- `curl`, `wget`, `git`, `unzip`, `zip`
- `libssl-dev`, `libffi-dev`, `zlib1g-dev`, `libbz2-dev`, `libreadline-dev`, `libsqlite3-dev`, `libncurses-dev`, `liblzma-dev`, `libxml2-dev`
- `clang`, `libicu-dev`, `libcurl4-openssl-dev`, `libedit-dev` (Swift dependencies)
- `software-properties-common`, `apt-transport-https`, `ca-certificates`
- `bash-completion`

### 2. System Configuration

- Set timezone to `$TIMEZONE` via `timedatectl`
- Generate and set locale to `$LOCALE`
- Set hostname if `$HOSTNAME` is non-empty

### 3. Shell Configuration (Bash)

Append to `~/.bashrc` (idempotent — check for a sentinel comment before appending):

**Aliases — Modern CLI replacements** (only added if corresponding tool is installed):

```bash
alias ls='eza --icons'
alias ll='eza -alh --icons'
alias la='eza -a --icons'
alias cat='bat --paging=never'
alias find='fd'
alias grep='rg'
alias du='dust'
alias df='duf'
```

**Aliases — Git shortcuts**:

```bash
alias gs='git status'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git push'
alias gpl='git pull'
alias ga='git add'
alias gc='git commit'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
```

**Aliases — System admin**:

```bash
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me'
alias meminfo='free -h'
alias cpuinfo='lscpu'
alias update='apt update && apt upgrade'
alias ss_status='systemctl status'
alias ss_restart='systemctl restart'
alias jl='journalctl -xe'
```

**Aliases — Navigation**:

```bash
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
```

**History tweaks**:

```bash
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
```

### 4. pyenv + Python

- Install pyenv via its official installer (`curl https://pyenv.run | bash`)
- Add pyenv init to `~/.bashrc`
- Install latest stable Python version
- Set as global default

### 5. nvm + Node.js

- Install nvm via official install script
- Add nvm init to `~/.bashrc`
- Install latest LTS Node.js version
- Set as default

### 6. goenv + Go

- Install goenv via git clone
- Add goenv init to `~/.bashrc`
- Install latest stable Go version
- Set as global default

### 7. rustup + Rust (Full Dev)

- Install rustup via `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y`
- Source cargo env
- Install stable toolchain
- Install additional components and tools:
  - `rustfmt` (formatter)
  - `clippy` (linter)
  - `rust-analyzer` (LSP)
  - `cargo-watch` (auto-rebuild on file changes)
  - `cargo-edit` (add/remove/upgrade deps from CLI)

### 8. Swift (via swiftly)

- Install swiftly: `curl -s https://swiftly.cc/install.sh | bash`
- Install latest stable Swift
- Verify with `swift --version`

### 9. Modern CLI Tools

Install via apt where available, otherwise via cargo, GitHub releases, or direct download:

| Tool     | Purpose                       | Install method          |
| -------- | ----------------------------- | ----------------------- |
| bat      | cat replacement with syntax   | apt / GitHub release    |
| eza      | ls replacement with icons     | apt / cargo             |
| fd-find  | find replacement (fast)       | apt                     |
| ripgrep  | grep replacement (fast)       | apt                     |
| dust     | du replacement (visual)       | cargo / GitHub release  |
| duf      | df replacement (visual)       | apt / GitHub release    |
| zoxide   | cd replacement (smart)        | apt / cargo             |
| fzf      | Fuzzy finder                  | apt / git               |
| jq       | JSON processor                | apt                     |
| yq       | YAML processor                | GitHub release / pip    |
| tldr     | Simplified man pages          | npm (tldr) / pip        |
| tree     | Directory tree viewer         | apt                     |
| ncdu     | Disk usage analyzer           | apt                     |

After installation, add zoxide init to `~/.bashrc`:
```bash
eval "$(zoxide init bash)"
```

### 10. Monitoring Tools (Terminal-only)

| Tool  | Purpose                    | Install method   |
| ----- | -------------------------- | ---------------- |
| btop  | System resource monitor    | apt / snap       |
| htop  | Process viewer             | apt              |
| iotop | Disk I/O monitor           | apt              |

No web dashboards, no daemons.

### 11. Neovim

- Install latest stable neovim via apt PPA or GitHub release
- No configuration, no plugins — binary only

### 12. Config Templates

Create `config/` directory with example files:

**`config/github.env.example`**:
```bash
# GitHub Personal Access Token (scoped)
# Generate at: https://github.com/settings/tokens
# Required scopes: repo, read:org (adjust as needed)
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**`config/zai.env.example`**:
```bash
# z.ai API Key
# Generate at: https://z.ai (or your z.ai dashboard)
ZAI_API_KEY=zai_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Add `config/*.env` to `.gitignore` (but NOT the `.example` files).

### 13. OpenClaw (LAST)

- Install via: `curl -fsSL https://openclaw.ai/install.sh | bash`
- This is always the final installation step
- The script does NOT configure OpenClaw — the user sets up API keys manually from `config/` templates

---

## Idempotency Rules

The script is **fully re-runnable** at any time:

1. **Skip if present**: Before installing any tool, check if the binary exists in `$PATH`. If yes, print a yellow "SKIPPING" message and move on. Do not check versions or attempt upgrades.
2. **Bash config sentinel**: All `.bashrc` additions are wrapped in a sentinel comment block (e.g., `# >>> vps-setup >>>` ... `# <<< vps-setup <<<`). On re-run, the block is replaced, not duplicated.
3. **Config templates**: Only create `.example` files if they don't already exist. Never overwrite.
4. **System settings**: Timezone, locale, and hostname are always applied (they're idempotent by nature).

---

## Error Handling

- **Warn and continue**: If a tool installation fails, print a red error message with details and continue to the next tool.
- **No retries**: Failed installations are not retried automatically.
- **Failures are tracked**: Every failure is recorded and included in the end-of-run summary.
- **Non-blocking**: A failure in step 4 (pyenv) does NOT prevent step 5 (nvm) from running.

---

## Terminal Output

**Colored section headers** for each tool/phase:

| Color    | Meaning                                              |
| -------- | ---------------------------------------------------- |
| Green    | Currently installing — shows tool name and method    |
| Yellow   | Skipping — tool already installed                    |
| Red      | Failed — shows error details                         |
| Blue     | Info — system configuration, status messages         |
| White    | Standard apt/curl/cargo output (passed through)      |

Example:
```
[INSTALL] Installing pyenv...
  Downloading installer...
  Installing Python 3.12.x...
  Done.

[SKIP] Node.js already installed (nvm detected)

[FAIL] goenv installation failed: git clone returned exit code 128
  Continuing...
```

---

## End-of-Run Summary

After all steps complete, print a detailed summary table:

```
╔══════════════════════════════════════════════════════════════╗
║                    VPS Setup Summary                        ║
╠══════════════════╦══════════╦════════════╦═══════════════════╣
║ Tool             ║ Status   ║ Version    ║ Time              ║
╠══════════════════╬══════════╬════════════╬═══════════════════╣
║ System packages  ║ OK       ║ -          ║ 45s               ║
║ pyenv + Python   ║ OK       ║ 3.12.x    ║ 120s              ║
║ nvm + Node.js    ║ SKIPPED  ║ 22.x      ║ -                 ║
║ goenv + Go       ║ FAILED   ║ -          ║ -                 ║
║ ...              ║ ...      ║ ...        ║ ...               ║
╠══════════════════╬══════════╬════════════╬═══════════════════╣
║ Total            ║ 9/11 OK  ║            ║ 8m 32s            ║
╚══════════════════╩══════════╩════════════╩═══════════════════╝
```

---

## CLAUDE.md (AI Agent Manifest)

A static file in the repo root that describes the provisioned environment. Updated manually when the setup script changes. Contains:

- List of all installed tools with their purpose and binary paths
- Available language runtimes and their version managers
- Alias mappings (what replaces what)
- Config file locations (`~/.bashrc`, `config/`, etc.)
- What is NOT installed (Docker, web servers, databases, firewalls)
- Conventions (root user, Hostinger, how to add new tools)

This file ensures that any AI agent (including OpenClaw) running on the VPS can immediately understand the environment without probing.

---

## Secrets Management

- **Approach**: Plain `.env` files, gitignored
- **Location**: `config/` directory at repo root
- **Templates**: `.example` files committed to repo with placeholder values and comments
- **Usage**: User copies `.example` to `.env`, fills in real values after setup
- **No automation**: Script does NOT read, export, or configure any secrets. User sources them manually.

---

## What Is Explicitly Out of Scope

- Docker / container runtime
- SSH hardening (handled by provider)
- Firewall / UFW (handled externally)
- Swap configuration
- Kernel / sysctl tuning
- Automatic updates (manual `apt upgrade` only)
- Databases (SQLite, Postgres, etc.)
- Web servers / reverse proxies
- Process managers (pm2, supervisord)
- tmux / screen
- Neovim plugins or configuration
- CI/CD pipelines
