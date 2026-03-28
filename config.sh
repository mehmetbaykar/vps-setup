#!/usr/bin/env bash
# ============================================================================
# VPS Setup Configuration
# ============================================================================
# Edit this file to customize your VPS setup.
# All toggles default to true. Set to false to skip a category.
# ============================================================================

# --- System Settings --------------------------------------------------------
TIMEZONE="Europe/Berlin"
LOCALE="en_US.UTF-8"
HOSTNAME=""  # Leave empty to skip hostname change

# --- Tool Category Toggles -------------------------------------------------
INSTALL_PYTHON=true       # pyenv + latest stable Python
INSTALL_NODE=true         # nvm + latest LTS Node.js
INSTALL_GO=true           # goenv + latest stable Go
INSTALL_RUST=true         # rustup + stable + rust-analyzer, clippy, cargo-watch, cargo-edit
INSTALL_SWIFT=true        # swiftly + latest stable Swift
INSTALL_CLI_TOOLS=true    # bat, eza, fd, ripgrep, dust, duf, zoxide, fzf, jq, yq, tldr, tree, ncdu
INSTALL_MONITORING=true   # btop, htop, iotop
INSTALL_NEOVIM=true       # Neovim binary (no config/plugins)
INSTALL_OPENCLAW=true     # OpenClaw / Claude Code (always installed last)
