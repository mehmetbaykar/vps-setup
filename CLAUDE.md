# VPS Environment Manifest

This file describes the provisioned state of this VPS after running `setup.sh`.
It exists so that AI agents (including OpenClaw) can immediately understand the environment.

## System

- **OS**: Ubuntu 24.04 LTS (x86_64)
- **Provider**: Hostinger
- **User**: root
- **Timezone**: Europe/Berlin
- **Locale**: en_US.UTF-8
- **Shell**: bash (enhanced with aliases and history tweaks)

## Language Runtimes

| Language | Version Manager | Binary        | Config Location              |
| -------- | --------------- | ------------- | ---------------------------- |
| Python   | pyenv           | `python`      | `~/.pyenv/`                  |
| Node.js  | nvm             | `node`, `npm` | `~/.nvm/`                    |
| Go       | goenv           | `go`          | `~/.goenv/`                  |
| Rust     | rustup          | `rustc`, `cargo` | `~/.cargo/`, `~/.rustup/` |
| Swift    | swiftly         | `swift`       | `~/.local/share/swiftly/` or `~/.swiftly/` |

### Rust Dev Tools

Installed via rustup/cargo: `rustfmt`, `clippy`, `rust-analyzer`, `cargo-watch`, `cargo-edit`.

## CLI Tools

These modern replacements are installed and **aliased to replace defaults** in `~/.bashrc`:

| Alias   | Actual Binary | Original Command | Package          |
| ------- | ------------- | ---------------- | ---------------- |
| `ls`    | `eza`         | `/usr/bin/ls`    | eza              |
| `ll`    | `eza -alh`    | -                | eza              |
| `cat`   | `bat`         | `/usr/bin/cat`   | bat (batcat)     |
| `find`  | `fd`          | `/usr/bin/find`  | fd-find (fdfind) |
| `grep`  | `rg`          | `/usr/bin/grep`  | ripgrep          |
| `du`    | `dust`        | `/usr/bin/du`    | du-dust (cargo)  |
| `df`    | `duf`         | `/usr/bin/df`    | duf              |
| `cd`    | `zoxide`      | (builtin)        | zoxide (cargo)   |

To use the **original** command, use the full path (e.g., `/usr/bin/ls`).

### Additional CLI Tools

| Tool  | Purpose                    | Binary |
| ----- | -------------------------- | ------ |
| fzf   | Fuzzy finder               | `fzf`  |
| jq    | JSON processor             | `jq`   |
| yq    | YAML processor             | `yq`   |
| tldr  | Simplified man pages       | `tldr` |
| tree  | Directory tree viewer      | `tree` |
| ncdu  | Disk usage analyzer (TUI)  | `ncdu` |

## Monitoring (Terminal-only)

| Tool  | Purpose                    | Binary  |
| ----- | -------------------------- | ------- |
| btop  | System resource monitor    | `btop`  |
| htop  | Process viewer             | `htop`  |
| iotop | Disk I/O monitor           | `iotop` |

No web dashboards or monitoring daemons are installed.

## Editor

- **Neovim** is installed (binary only, no plugins or configuration).
- Binary: `nvim`

## Shell Aliases

### Git Shortcuts
`gs` (status), `gl` (log), `gp` (push), `gpl` (pull), `ga` (add), `gc` (commit), `gd` (diff), `gb` (branch), `gco` (checkout)

### System Admin
`ports` (ss -tulnp), `myip` (external IP), `meminfo` (free -h), `cpuinfo` (lscpu), `sysupdate` (apt update+upgrade), `ss_status` (systemctl status), `ss_restart` (systemctl restart), `jl` (journalctl)

### Navigation
`..` (cd ..), `...` (cd ../..), `....` (cd ../../..)

## Secrets / Config

- Token templates are in `config/*.env.example`
- Actual tokens go in `config/*.env` (gitignored)
- Available templates: `github.env.example`, `zai.env.example`
- The setup script does NOT auto-configure secrets. Source them manually:
  ```bash
  source /path/to/vps-setup/config/github.env
  ```

## What Is NOT Installed

- Docker / containers
- Databases (SQLite, Postgres, Redis, etc.)
- Web servers / reverse proxies (nginx, caddy, etc.)
- Process managers (pm2, supervisord)
- tmux / screen
- Firewalls (handled externally)
- Automatic updates (run `sysupdate` alias manually)
- CI/CD tooling

## Conventions

- Run everything as **root**
- SSH hardening is handled by the VPS provider, not this repo
- The setup script is **fully re-runnable** (idempotent)
- To add a new tool: edit `setup.sh`, add a function, update `config.sh` with a toggle
- Config file: `config.sh` (tool toggles and system settings)
