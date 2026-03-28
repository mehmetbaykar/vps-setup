# VPS Setup

Re-runnable provisioning script for Ubuntu (latest stable) x86_64 development VPS.

## Quick Start

```bash
# 1. Clone this repo on your VPS
git clone <your-repo-url> ~/vps-setup
cd ~/vps-setup

# 2. (Optional) Edit config.sh to toggle tools on/off
nano config.sh

# 3. Run as root
chmod +x setup.sh
./setup.sh

# 4. Apply shell changes
source ~/.bashrc

# 5. Set up your secrets
cp config/github.env.example config/github.env
cp config/zai.env.example config/zai.env
# Edit the .env files with your actual tokens
```

## What Gets Installed

| Category   | Tools                                                                   |
| ---------- | ----------------------------------------------------------------------- |
| System     | build-essential, cmake, clang, curl, wget, git, and more                |
| Python     | pyenv + latest stable Python                                            |
| Node.js    | nvm + latest LTS Node.js                                                |
| Go         | goenv + latest stable Go                                                |
| Rust       | rustup + stable + rust-analyzer, clippy, cargo-watch, cargo-edit        |
| Swift      | swiftly + latest stable Swift                                           |
| CLI Tools  | bat, eza, fd, ripgrep, dust, duf, zoxide, fzf, jq, yq, tldr, tree, ncdu |
| Monitoring | btop, htop, iotop                                                       |
| Editor     | Neovim (binary only)                                                    |
| AI Agent   | OpenClaw (Claude Code)                                                  |

## Configuration

Edit `config.sh` before running. All toggles default to `true`:

```bash
INSTALL_PYTHON=true
INSTALL_NODE=true
INSTALL_GO=true
INSTALL_RUST=true
INSTALL_SWIFT=true
INSTALL_CLI_TOOLS=true
INSTALL_MONITORING=true
INSTALL_NEOVIM=true
INSTALL_OPENCLAW=true
```

System settings:

```bash
TIMEZONE="Europe/Berlin"
LOCALE="en_US.UTF-8"
HOSTNAME=""  # Set to change hostname
```

## Re-running

The script is fully idempotent. Run it again at any time:

- Already-installed tools are **skipped** (not upgraded)
- Shell config is **replaced** (not duplicated)
- Config templates are only created if they don't exist

## Secrets

Token templates live in `config/`. Copy `.example` to `.env` and fill in your values:

```
config/
├── github.env.example  -> github.env
└── zai.env.example     -> zai.env
```

`.env` files are gitignored and never committed.

## For AI Agents

See [CLAUDE.md](CLAUDE.md) for a complete description of the environment, installed tools, aliases, and conventions.
