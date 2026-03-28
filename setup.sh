#!/usr/bin/env bash
# ============================================================================
# VPS Setup Script
# ============================================================================
# Re-runnable provisioning for Ubuntu (latest stable) x86_64 development VPS.
# See SPEC.md for full details. See config.sh for toggles.
# ============================================================================
# Note: NOT using set -e so individual failures don't halt the script.
# set -u catches undefined vars, pipefail catches pipe errors.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHRC="$HOME/.bashrc"
SENTINEL_START="# >>> vps-setup >>>"
SENTINEL_END="# <<< vps-setup <<<"

# ============================================================================
# Colors & Output
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_install() { echo -e "\n${GREEN}${BOLD}[INSTALL]${NC} ${GREEN}$1${NC}"; }
print_skip()    { echo -e "\n${YELLOW}${BOLD}[SKIP]${NC} ${YELLOW}$1${NC}"; }
print_fail()    { echo -e "\n${RED}${BOLD}[FAIL]${NC} ${RED}$1${NC}"; }
print_info()    { echo -e "\n${BLUE}${BOLD}[INFO]${NC} ${BLUE}$1${NC}"; }
print_header()  {
    echo -e "\n${BOLD}============================================================${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}============================================================${NC}"
}

# ============================================================================
# Tracking
# ============================================================================
declare -a SUMMARY_NAMES=()
declare -a SUMMARY_STATUS=()
declare -a SUMMARY_VERSIONS=()
declare -a SUMMARY_TIMES=()
TOTAL_START=$(date +%s)
STEP_START=0

start_timer() { STEP_START=$(date +%s); }
stop_timer() {
    local elapsed=$(( $(date +%s) - STEP_START ))
    echo "${elapsed}s"
}

track() {
    local name="$1" status="$2" version="${3:--}" time="${4:--}"
    SUMMARY_NAMES+=("$name")
    SUMMARY_STATUS+=("$status")
    SUMMARY_VERSIONS+=("$version")
    SUMMARY_TIMES+=("$time")
}

command_exists() { command -v "$1" &>/dev/null; }

# ============================================================================
# Source config
# ============================================================================
if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
    # shellcheck source=config.sh
    source "$SCRIPT_DIR/config.sh"
else
    print_fail "config.sh not found in $SCRIPT_DIR. Cannot continue."
    exit 1
fi

# ============================================================================
# Step 1: System Packages
# ============================================================================
install_system_packages() {
    print_header "Step 1/13: System Packages"
    start_timer

    print_install "Updating apt package index..."
    if ! apt-get update -y; then
        local t; t=$(stop_timer)
        print_fail "apt-get update failed"
        track "System packages" "FAILED" "-" "$t"
        return 0  # return 0 so || in main doesn't double-track
    fi

    print_install "Installing base development packages..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential cmake pkg-config \
        curl wget git unzip zip \
        libssl-dev libffi-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev libncurses-dev liblzma-dev libxml2-dev \
        clang libicu-dev libcurl4-openssl-dev libedit-dev \
        software-properties-common apt-transport-https ca-certificates \
        bash-completion; then
        local t; t=$(stop_timer)
        print_fail "Some system packages failed to install"
        track "System packages" "FAILED" "-" "$t"
        return 0
    fi

    local t
    t=$(stop_timer)
    track "System packages" "OK" "-" "$t"
}

# ============================================================================
# Step 2: System Configuration
# ============================================================================
configure_system() {
    print_header "Step 2/13: System Configuration"
    start_timer

    print_info "Setting timezone to $TIMEZONE..."
    timedatectl set-timezone "$TIMEZONE"

    print_info "Setting locale to $LOCALE..."
    locale-gen "$LOCALE"
    update-locale LANG="$LOCALE" LC_ALL="$LOCALE"

    if [[ -n "$HOSTNAME" ]]; then
        print_info "Setting hostname to $HOSTNAME..."
        hostnamectl set-hostname "$HOSTNAME"
    else
        print_info "Hostname not set (empty in config.sh), skipping."
    fi

    local t
    t=$(stop_timer)
    track "System config" "OK" "-" "$t"
}

# ============================================================================
# Step 3: Shell Configuration (Bash)
# ============================================================================
configure_shell() {
    print_header "Step 3/13: Shell Configuration"
    start_timer

    print_install "Configuring bash aliases and settings..."

    # Remove old sentinel block if present
    if grep -q "$SENTINEL_START" "$BASHRC" 2>/dev/null; then
        sed -i "/$SENTINEL_START/,/$SENTINEL_END/d" "$BASHRC"
    fi

    cat >> "$BASHRC" << 'BASHRC_BLOCK'
# >>> vps-setup >>>
# --- Modern CLI replacements (aliases set only if tool exists) ---
command -v eza    &>/dev/null && alias ls='eza --icons'
command -v eza    &>/dev/null && alias ll='eza -alh --icons'
command -v eza    &>/dev/null && alias la='eza -a --icons'
command -v bat    &>/dev/null && alias cat='bat --paging=never'
command -v fd     &>/dev/null && alias find='fd'
command -v rg     &>/dev/null && alias grep='rg'
command -v dust   &>/dev/null && alias du='dust'
command -v duf    &>/dev/null && alias df='duf'

# --- Git shortcuts ---
alias gs='git status'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git push'
alias gpl='git pull'
alias ga='git add'
alias gc='git commit'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# --- System admin ---
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me'
alias meminfo='free -h'
alias cpuinfo='lscpu'
alias sysupdate='apt update && apt upgrade'
alias ss_status='systemctl status'
alias ss_restart='systemctl restart'
alias jl='journalctl -xe'

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- History ---
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# --- Zoxide (smart cd) ---
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"
# <<< vps-setup <<<
BASHRC_BLOCK

    local t
    t=$(stop_timer)
    track "Shell config" "OK" "-" "$t"
}

# ============================================================================
# Step 4: pyenv + Python
# ============================================================================
install_pyenv() {
    if [[ "$INSTALL_PYTHON" != "true" ]]; then
        print_skip "Python (disabled in config.sh)"
        track "pyenv + Python" "SKIPPED" "-" "-"
        return
    fi

    print_header "Step 4/13: pyenv + Python"
    start_timer

    if command_exists pyenv; then
        local pyver
        pyver=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        print_skip "pyenv already installed (Python $pyver)"
        track "pyenv + Python" "SKIPPED" "$pyver" "-"
        return
    fi

    print_install "Installing pyenv..."
    curl -fsSL https://pyenv.run | bash

    # Make pyenv available in this script session
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    # Add to bashrc (inside sentinel block handled separately)
    # We add pyenv init outside the sentinel since it needs to be always present
    if ! grep -q 'PYENV_ROOT' "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'EOF'
# --- pyenv ---
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
    fi

    print_install "Installing latest stable Python..."
    local latest_python
    latest_python=$(pyenv install --list | grep -E '^\s+[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
    pyenv install "$latest_python"
    pyenv global "$latest_python"

    local t
    t=$(stop_timer)
    track "pyenv + Python" "OK" "$latest_python" "$t"
}

# ============================================================================
# Step 5: nvm + Node.js
# ============================================================================
install_nvm() {
    if [[ "$INSTALL_NODE" != "true" ]]; then
        print_skip "Node.js (disabled in config.sh)"
        track "nvm + Node.js" "SKIPPED" "-" "-"
        return
    fi

    print_header "Step 5/13: nvm + Node.js"
    start_timer

    if command_exists node; then
        local nver
        nver=$(node --version 2>/dev/null || echo "unknown")
        print_skip "Node.js already installed ($nver)"
        track "nvm + Node.js" "SKIPPED" "$nver" "-"
        return
    fi

    print_install "Installing nvm..."
    export NVM_DIR="$HOME/.nvm"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    # Make nvm available in this script session
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    print_install "Installing latest LTS Node.js..."
    nvm install --lts
    nvm alias default lts/*

    local nver
    nver=$(node --version 2>/dev/null || echo "unknown")

    local t
    t=$(stop_timer)
    track "nvm + Node.js" "OK" "$nver" "$t"
}

# ============================================================================
# Step 6: goenv + Go
# ============================================================================
install_goenv() {
    if [[ "$INSTALL_GO" != "true" ]]; then
        print_skip "Go (disabled in config.sh)"
        track "goenv + Go" "SKIPPED" "-" "-"
        return
    fi

    print_header "Step 6/13: goenv + Go"
    start_timer

    if command_exists go; then
        local gver
        gver=$(go version 2>/dev/null | awk '{print $3}' || echo "unknown")
        print_skip "Go already installed ($gver)"
        track "goenv + Go" "SKIPPED" "$gver" "-"
        return
    fi

    print_install "Installing goenv..."
    git clone https://github.com/go-nv/goenv.git "$HOME/.goenv"

    # Make goenv available in this script session
    export GOENV_ROOT="$HOME/.goenv"
    export PATH="$GOENV_ROOT/bin:$PATH"
    eval "$(goenv init -)"

    # Add to bashrc
    if ! grep -q 'GOENV_ROOT' "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'EOF'
# --- goenv ---
export GOENV_ROOT="$HOME/.goenv"
[[ -d "$GOENV_ROOT/bin" ]] && export PATH="$GOENV_ROOT/bin:$PATH"
eval "$(goenv init -)"
export PATH="$GOROOT/bin:$PATH"
export PATH="$GOPATH/bin:$PATH"
EOF
    fi

    print_install "Installing latest stable Go..."
    local latest_go
    latest_go=$(goenv install --list | grep -E '^\s+[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
    goenv install "$latest_go"
    goenv global "$latest_go"

    local gver
    gver=$(go version 2>/dev/null | awk '{print $3}' || echo "$latest_go")

    local t
    t=$(stop_timer)
    track "goenv + Go" "OK" "$gver" "$t"
}

# ============================================================================
# Step 7: rustup + Rust (Full Dev)
# ============================================================================
install_rust() {
    if [[ "$INSTALL_RUST" != "true" ]]; then
        print_skip "Rust (disabled in config.sh)"
        track "rustup + Rust" "SKIPPED" "-" "-"
        return
    fi

    print_header "Step 7/13: rustup + Rust"
    start_timer

    if command_exists rustc; then
        local rver
        rver=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        print_skip "Rust already installed ($rver)"
        track "rustup + Rust" "SKIPPED" "$rver" "-"
        return
    fi

    print_install "Installing rustup + stable toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # Make cargo available in this script session
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"

    print_install "Installing Rust dev tools (clippy, rustfmt, rust-analyzer)..."
    rustup component add rustfmt clippy rust-analyzer

    print_install "Installing cargo extensions (cargo-watch, cargo-edit)..."
    cargo install cargo-watch cargo-edit

    local rver
    rver=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "unknown")

    local t
    t=$(stop_timer)
    track "rustup + Rust" "OK" "$rver" "$t"
}

# ============================================================================
# Step 8: Swift (via swiftly)
# ============================================================================
install_swift() {
    if [[ "$INSTALL_SWIFT" != "true" ]]; then
        print_skip "Swift (disabled in config.sh)"
        track "Swift" "SKIPPED" "-" "-"
        return
    fi

    print_header "Step 8/13: Swift (via swiftly)"
    start_timer

    if command_exists swift; then
        local sver
        sver=$(swift --version 2>/dev/null | head -1 | grep -oP '[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "unknown")
        print_skip "Swift already installed ($sver)"
        track "Swift" "SKIPPED" "$sver" "-"
        return
    fi

    print_install "Installing swiftly (Swift version manager)..."
    curl -fsSL https://swiftlang.github.io/swiftly/swiftly-install.sh | bash -s -- -y

    # Source swiftly env if it exists
    if [[ -f "$HOME/.local/share/swiftly/env.sh" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/.local/share/swiftly/env.sh"
    fi
    # Also check the older path
    if [[ -f "$HOME/.swiftly/env.sh" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/.swiftly/env.sh"
    fi

    print_install "Installing latest stable Swift..."
    swiftly install latest

    local sver
    sver=$(swift --version 2>/dev/null | head -1 | grep -oP '[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "unknown")

    local t
    t=$(stop_timer)
    track "Swift" "OK" "$sver" "$t"
}

# ============================================================================
# Step 9: Modern CLI Tools
# ============================================================================
install_cli_tools() {
    if [[ "$INSTALL_CLI_TOOLS" != "true" ]]; then
        print_skip "CLI tools (disabled in config.sh)"
        track "CLI tools" "SKIPPED" "-" "-"
        return
    fi

    print_header "Step 9/13: Modern CLI Tools"
    start_timer
    local failed=0

    # --- apt-based tools ---
    print_install "Installing apt-based CLI tools (bat, eza, fd, ripgrep, fzf, jq, duf, tree, ncdu)..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        bat eza fd-find ripgrep fzf jq duf tree ncdu || {
        print_fail "Some apt CLI tools failed to install"
        failed=1
    }

    # bat installs as 'batcat' on Ubuntu — create symlink
    if command_exists batcat && ! command_exists bat; then
        ln -sf "$(which batcat)" /usr/local/bin/bat
        print_info "Created symlink: bat -> batcat"
    fi

    # fd-find installs as 'fdfind' on Ubuntu — create symlink
    if command_exists fdfind && ! command_exists fd; then
        ln -sf "$(which fdfind)" /usr/local/bin/fd
        print_info "Created symlink: fd -> fdfind"
    fi

    # --- cargo-based tools (need Rust installed) ---
    if command_exists cargo; then
        if ! command_exists dust; then
            print_install "Installing dust via cargo..."
            cargo install du-dust || { print_fail "dust install failed"; failed=1; }
        else
            print_skip "dust already installed"
        fi

        if ! command_exists zoxide; then
            print_install "Installing zoxide via cargo..."
            cargo install zoxide --locked || { print_fail "zoxide install failed"; failed=1; }
        else
            print_skip "zoxide already installed"
        fi
    else
        print_fail "cargo not available — skipping dust and zoxide (install Rust first)"
        failed=1
    fi

    # --- yq (Mike Farah's Go-based YAML processor via GitHub release) ---
    if ! command_exists yq; then
        print_install "Installing yq (YAML processor)..."
        local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
        curl -fsSL "$yq_url" -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq || {
            print_fail "yq install failed"
            failed=1
        }
    else
        print_skip "yq already installed"
    fi

    # --- tldr (needs Node.js) ---
    if command_exists npm; then
        if ! command_exists tldr; then
            print_install "Installing tldr via npm..."
            npm install -g tldr || { print_fail "tldr install failed"; failed=1; }
        else
            print_skip "tldr already installed"
        fi
    else
        print_fail "npm not available — skipping tldr (install Node.js first)"
        failed=1
    fi

    local t
    t=$(stop_timer)
    if [[ $failed -eq 0 ]]; then
        track "CLI tools" "OK" "-" "$t"
    else
        track "CLI tools" "PARTIAL" "-" "$t"
    fi
}

# ============================================================================
# Step 10: Monitoring Tools
# ============================================================================
install_monitoring() {
    if [[ "$INSTALL_MONITORING" != "true" ]]; then
        print_skip "Monitoring (disabled in config.sh)"
        track "Monitoring" "SKIPPED" "-" "-"
        return
    fi

    print_header "Step 10/13: Monitoring Tools"
    start_timer

    print_install "Installing btop, htop, iotop..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y btop htop iotop; then
        local t; t=$(stop_timer)
        print_fail "Some monitoring tools failed to install"
        track "Monitoring" "FAILED" "-" "$t"
        return 0
    fi

    local bver
    bver=$(btop --version 2>/dev/null | head -1 || echo "installed")

    local t
    t=$(stop_timer)
    track "Monitoring" "OK" "$bver" "$t"
}

# ============================================================================
# Step 11: Neovim
# ============================================================================
install_neovim() {
    if [[ "$INSTALL_NEOVIM" != "true" ]]; then
        print_skip "Neovim (disabled in config.sh)"
        track "Neovim" "SKIPPED" "-" "-"
        return
    fi

    print_header "Step 11/13: Neovim"
    start_timer

    if command_exists nvim; then
        local nver
        nver=$(nvim --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
        print_skip "Neovim already installed ($nver)"
        track "Neovim" "SKIPPED" "$nver" "-"
        return
    fi

    # Try apt first (Ubuntu 25.10+ has a recent enough Neovim in default repos).
    # Fall back to GitHub release if apt version is too old or unavailable.
    print_install "Installing Neovim via apt..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y neovim 2>/dev/null; then
        print_info "apt install failed, downloading latest Neovim from GitHub..."
        local nvim_url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
        curl -fsSL "$nvim_url" -o /tmp/nvim.tar.gz
        tar xzf /tmp/nvim.tar.gz -C /opt
        ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
        rm -f /tmp/nvim.tar.gz
    fi

    local nver
    nver=$(nvim --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")

    local t
    t=$(stop_timer)
    track "Neovim" "OK" "$nver" "$t"
}

# ============================================================================
# Step 12: Config Templates
# ============================================================================
create_config_templates() {
    print_header "Step 12/13: Config Templates"
    start_timer

    mkdir -p "$SCRIPT_DIR/config"

    if [[ ! -f "$SCRIPT_DIR/config/github.env.example" ]]; then
        print_install "Creating config/github.env.example..."
        cat > "$SCRIPT_DIR/config/github.env.example" << 'EOF'
# GitHub Personal Access Token (scoped)
# Generate at: https://github.com/settings/tokens
# Required scopes: repo, read:org (adjust as needed)
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF
    else
        print_skip "config/github.env.example already exists"
    fi

    if [[ ! -f "$SCRIPT_DIR/config/zai.env.example" ]]; then
        print_install "Creating config/zai.env.example..."
        cat > "$SCRIPT_DIR/config/zai.env.example" << 'EOF'
# z.ai API Key
# Generate at: https://z.ai (or your z.ai dashboard)
ZAI_API_KEY=zai_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF
    else
        print_skip "config/zai.env.example already exists"
    fi

    # Ensure .gitignore exists and covers actual env files
    local gitignore="$SCRIPT_DIR/.gitignore"
    if ! grep -q 'config/\*.env' "$gitignore" 2>/dev/null; then
        print_install "Updating .gitignore..."
        cat >> "$gitignore" << 'EOF'

# Actual secret files (never commit these)
config/*.env
!config/*.env.example
EOF
    fi

    local t
    t=$(stop_timer)
    track "Config templates" "OK" "-" "$t"
}

# ============================================================================
# Step 13: OpenClaw (ALWAYS LAST)
# ============================================================================
install_openclaw() {
    if [[ "$INSTALL_OPENCLAW" != "true" ]]; then
        print_skip "OpenClaw (disabled in config.sh)"
        track "OpenClaw" "SKIPPED" "-" "-"
        return
    fi

    print_header "Step 13/13: OpenClaw (Claude Code)"
    start_timer

    if command_exists openclaw; then
        local over
        over=$(openclaw --version 2>/dev/null || echo "unknown")
        print_skip "OpenClaw already installed ($over)"
        track "OpenClaw" "SKIPPED" "$over" "-"
        return
    fi

    print_install "Installing OpenClaw via official installer..."
    curl -fsSL https://openclaw.ai/install.sh | bash

    local over
    over=$(openclaw --version 2>/dev/null || echo "installed")

    local t
    t=$(stop_timer)
    track "OpenClaw" "OK" "$over" "$t"
}

# ============================================================================
# Summary Table
# ============================================================================
print_summary() {
    local total_elapsed=$(( $(date +%s) - TOTAL_START ))
    local total_min=$(( total_elapsed / 60 ))
    local total_sec=$(( total_elapsed % 60 ))
    local ok_count=0 fail_count=0 skip_count=0

    for s in "${SUMMARY_STATUS[@]}"; do
        case "$s" in
            OK)             ok_count=$((ok_count + 1)) ;;
            FAILED|PARTIAL) fail_count=$((fail_count + 1)) ;;
            SKIPPED)        skip_count=$((skip_count + 1)) ;;
        esac
    done

    local total=${#SUMMARY_NAMES[@]}

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                       VPS Setup Summary                         ║${NC}"
    echo -e "${BOLD}╠════════════════════╦══════════╦══════════════╦════════════════════╣${NC}"
    printf  "${BOLD}║${NC} %-18s ${BOLD}║${NC} %-8s ${BOLD}║${NC} %-12s ${BOLD}║${NC} %-18s ${BOLD}║${NC}\n" \
            "Tool" "Status" "Version" "Time"
    echo -e "${BOLD}╠════════════════════╬══════════╬══════════════╬════════════════════╣${NC}"

    for i in "${!SUMMARY_NAMES[@]}"; do
        local name="${SUMMARY_NAMES[$i]}"
        local status="${SUMMARY_STATUS[$i]}"
        local version="${SUMMARY_VERSIONS[$i]}"
        local time="${SUMMARY_TIMES[$i]}"

        local color="$NC"
        case "$status" in
            OK)      color="$GREEN" ;;
            FAILED|PARTIAL) color="$RED" ;;
            SKIPPED) color="$YELLOW" ;;
        esac

        printf "${BOLD}║${NC} %-18s ${BOLD}║${NC} ${color}%-8s${NC} ${BOLD}║${NC} %-12s ${BOLD}║${NC} %-18s ${BOLD}║${NC}\n" \
                "$name" "$status" "$version" "$time"
    done

    echo -e "${BOLD}╠════════════════════╬══════════╬══════════════╬════════════════════╣${NC}"
    printf  "${BOLD}║${NC} %-18s ${BOLD}║${NC} ${GREEN}%-8s${NC} ${BOLD}║${NC} %-12s ${BOLD}║${NC} %-18s ${BOLD}║${NC}\n" \
            "Total" "${ok_count}/${total} OK" "" "${total_min}m ${total_sec}s"
    echo -e "${BOLD}╚════════════════════╩══════════╩══════════════╩════════════════════╝${NC}"

    if [[ $fail_count -gt 0 ]]; then
        echo ""
        print_fail "Some installations failed or were partial. Check output above for details."
    fi

    echo ""
    print_info "Setup complete. Run 'source ~/.bashrc' or open a new shell to apply changes."
}

# ============================================================================
# Main
# ============================================================================
main() {
    echo -e "${BOLD}"
    echo "  ╦  ╦╔═╗╔═╗  ╔═╗╔═╗╔╦╗╦ ╦╔═╗"
    echo "  ╚╗╔╝╠═╝╚═╗  ╚═╗║╣  ║ ║ ║╠═╝"
    echo "   ╚╝ ╩  ╚═╝  ╚═╝╚═╝ ╩ ╚═╝╩  "
    echo -e "${NC}"
    echo "  Ubuntu Development VPS Provisioner"
    echo "  Config: $SCRIPT_DIR/config.sh"
    echo ""

    # Ensure running as root
    if [[ $EUID -ne 0 ]]; then
        print_fail "This script must be run as root."
        exit 1
    fi

    # Execute steps in order — each function handles its own errors
    install_system_packages   || { print_fail "System packages step failed"; track "System packages" "FAILED" "-" "$(stop_timer)"; }
    configure_system          || { print_fail "System config step failed";   track "System config"   "FAILED" "-" "$(stop_timer)"; }
    configure_shell           || { print_fail "Shell config step failed";    track "Shell config"    "FAILED" "-" "$(stop_timer)"; }
    install_pyenv             || { print_fail "pyenv step failed";           track "pyenv + Python"  "FAILED" "-" "$(stop_timer)"; }
    install_nvm               || { print_fail "nvm step failed";             track "nvm + Node.js"   "FAILED" "-" "$(stop_timer)"; }
    install_goenv             || { print_fail "goenv step failed";           track "goenv + Go"      "FAILED" "-" "$(stop_timer)"; }
    install_rust              || { print_fail "Rust step failed";            track "rustup + Rust"   "FAILED" "-" "$(stop_timer)"; }
    install_swift             || { print_fail "Swift step failed";           track "Swift"           "FAILED" "-" "$(stop_timer)"; }
    install_cli_tools         || { print_fail "CLI tools step failed";       track "CLI tools"       "FAILED" "-" "$(stop_timer)"; }
    install_monitoring        || { print_fail "Monitoring step failed";      track "Monitoring"      "FAILED" "-" "$(stop_timer)"; }
    install_neovim            || { print_fail "Neovim step failed";          track "Neovim"          "FAILED" "-" "$(stop_timer)"; }
    create_config_templates   || { print_fail "Config templates step failed"; track "Config templates" "FAILED" "-" "$(stop_timer)"; }
    install_openclaw          || { print_fail "OpenClaw step failed";        track "OpenClaw"        "FAILED" "-" "$(stop_timer)"; }

    print_summary
}

main "$@"
