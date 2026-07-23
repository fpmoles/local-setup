#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup.sh
# Configure local machine with Homebrew, packages, casks, and development directories.
#
# Prerequisites:
#   - curl: For downloading setup resources
#
# Usage:
#   ./setup.sh [OPTIONS]
#   ./setup.sh --help
#   ./setup.sh --skip-packages --skip-casks
# ---------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration variables
SKIP_HOMEBREW=false
SKIP_PACKAGES=false
SKIP_CASKS=false
SKIP_NPM_GLOBALS=false
SKIP_YARN_GLOBALS=false
SKIP_ZSHRC=false
SKIP_DIRECTORIES=false
SKIP_GITCONFIG=false
SKIP_SSH_KEY=false
SKIP_AI_CONFIG=false
VERBOSE=false

GIT_EMAIL=""

# Homebrew packages to install
declare -a BREW_PACKAGES=(
  "azure-cli"
  "awscli"
  "curl"
  "git"
  "go"
  "httpie"
  "jq"
  "kind"
  "kubectl"
  "node"
  "python3"
  "vim"
  "wget"
  "yq"
)

# Homebrew casks to install
declare -a BREW_CASKS=(
  "docker"
  "gcloud-cli"
  "oracle-jdk@17"
  "oracle-jdk@21"
  "oracle-jdk"
)

# npm global packages to install
declare -a NPM_GLOBAL_PACKAGES=(
  "yarn"
)

# yarn global packages to install
declare -a YARN_GLOBAL_PACKAGES=(
  "create-react-app"
  "create-redwood-app"
)

# Claude Code's own agent/skill directories (fpm_* agents & skills, per
# CLAUDE.md). Granted read-only access in configure_claude_settings so
# invoking an fpm agent/skill doesn't hit a permission prompt.
declare -a CLAUDE_READONLY_DIRS=(
  "${HOME}/.claude/agents"
  "${HOME}/.claude/skills"
)

# Development directories to create
declare -a DEV_DIRS=(
  "${HOME}/.local/bin"
  "${HOME}/dev"
  "${HOME}/dev/code"
  "${HOME}/dev/designs"
  "${HOME}/dev/docs"
  "${HOME}/dev/docker"
  "${HOME}/dev/go"
  "${HOME}/dev/learning"
  "${HOME}/dev/proposals"
  "${HOME}/dev/templates"

)

# ============================================================================
# Output helpers
# ============================================================================

info() {
  echo -e "${BLUE}[INFO]${NC}  $*"
}

success() {
  echo -e "${GREEN}[OK]${NC}    $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC}  $*"
}

error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

# ============================================================================
# Helper functions
# ============================================================================

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -h, --help                Show this help message and exit
  -v, --verbose             Enable verbose output
  --skip-homebrew           Skip Homebrew installation
  --skip-packages           Skip installing Homebrew packages
  --skip-casks              Skip installing Homebrew casks
  --skip-npm-globals        Skip installing global npm packages
  --skip-yarn-globals       Skip installing global yarn packages
  --skip-zshrc              Skip zshrc configuration
  --skip-directories        Skip development directory creation
  --skip-gitconfig          Skip git global configuration
  --skip-ssh-key            Skip SSH keypair generation
  --skip-ai-config          Skip AI coding tool configuration (Claude Code, Codex, Copilot)
  --skip-all                Skip all installation steps (useful for testing)
  --zshrc-only              Only run zshrc configuration, skip everything else

Examples:
  ./setup.sh                              # Full setup
  ./setup.sh --verbose                    # Full setup with verbose output
  ./setup.sh --skip-homebrew              # Skip Homebrew install (already installed)
  ./setup.sh --skip-packages              # Skip Homebrew formula installs
  ./setup.sh --skip-casks                 # Skip Homebrew cask installs
  ./setup.sh --skip-npm-globals           # Skip global npm package installs
  ./setup.sh --skip-yarn-globals          # Skip global yarn package installs
  ./setup.sh --skip-zshrc                 # Skip .zshrc managed block update
  ./setup.sh --skip-directories           # Skip dev directory creation
  ./setup.sh --skip-gitconfig             # Skip git global config
  ./setup.sh --skip-ssh-key               # Skip SSH keypair generation
  ./setup.sh --skip-all                   # Dry-run: parse args only (useful for testing)
  ./setup.sh --zshrc-only                 # Repair/reorder the .zshrc managed block only
EOF
  exit 0
}

log_verbose() {
  if [[ "$VERBOSE" == true ]]; then
    info "$*"
  fi
}

# ============================================================================
# Argument parsing
# ============================================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --skip-homebrew)
        SKIP_HOMEBREW=true
        shift
        ;;
      --skip-packages)
        SKIP_PACKAGES=true
        shift
        ;;
      --skip-casks)
        SKIP_CASKS=true
        shift
        ;;
      --skip-npm-globals)
        SKIP_NPM_GLOBALS=true
        shift
        ;;
      --skip-yarn-globals)
        SKIP_YARN_GLOBALS=true
        shift
        ;;
      --skip-zshrc)
        SKIP_ZSHRC=true
        shift
        ;;
      --skip-directories)
        SKIP_DIRECTORIES=true
        shift
        ;;
      --skip-gitconfig)
        SKIP_GITCONFIG=true
        shift
        ;;
      --skip-ssh-key)
        SKIP_SSH_KEY=true
        shift
        ;;
      --skip-ai-config)
        SKIP_AI_CONFIG=true
        shift
        ;;
      --skip-all)
        SKIP_HOMEBREW=true
        SKIP_PACKAGES=true
        SKIP_CASKS=true
        SKIP_NPM_GLOBALS=true
        SKIP_YARN_GLOBALS=true
        SKIP_ZSHRC=true
        SKIP_DIRECTORIES=true
        SKIP_GITCONFIG=true
        SKIP_SSH_KEY=true
        SKIP_AI_CONFIG=true
        shift
        ;;
      --zshrc-only)
        SKIP_HOMEBREW=true
        SKIP_PACKAGES=true
        SKIP_CASKS=true
        SKIP_NPM_GLOBALS=true
        SKIP_YARN_GLOBALS=true
        SKIP_DIRECTORIES=true
        SKIP_GITCONFIG=true
        SKIP_SSH_KEY=true
        SKIP_AI_CONFIG=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        usage
        ;;
      *)
        error "Unexpected argument: $1"
        usage
        ;;
    esac
  done
}

# ============================================================================
# Dependency checks
# ============================================================================

check_dependencies() {
  log_verbose "Checking dependencies..."

  local missing_deps=0

  for cmd in curl; do
    if ! command -v "$cmd" &> /dev/null; then
      warn "Missing dependency: $cmd"
      missing_deps=$((missing_deps + 1))
    fi
  done

  if [[ $missing_deps -gt 0 ]]; then
    error "Please install missing dependencies and try again"
    exit 1
  fi

  success "All dependencies are installed"
}

ensure_xcode_clt() {
  if xcode-select -p &> /dev/null; then
    success "Xcode Command Line Tools are already installed"
    return 0
  fi

  info "Installing Xcode Command Line Tools..."
  xcode-select --install &> /dev/null || warn "Xcode Command Line Tools installer may already be open"
  warn "Complete the Xcode Command Line Tools install dialog to continue"

  # Wait for installation to complete (up to 30 minutes).
  local max_attempts=180
  local attempt=1
  while [[ $attempt -le $max_attempts ]]; do
    if xcode-select -p &> /dev/null; then
      success "Xcode Command Line Tools installation complete"
      return 0
    fi
    sleep 10
    attempt=$((attempt + 1))
  done

  error "Xcode Command Line Tools installation was not detected in time"
  error "Please complete installation manually and re-run this script"
  exit 1
}

# ============================================================================
# Homebrew functions
# ============================================================================

# Load Homebrew into PATH for the current shell when installed in common locations.
ensure_homebrew_path() {
  if command -v brew &> /dev/null; then
    return 0
  fi

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_homebrew() {
  if [[ "$SKIP_HOMEBREW" == true ]]; then
    warn "Skipping Homebrew installation"
    return 0
  fi

  ensure_homebrew_path
  if command -v brew &> /dev/null; then
    success "Homebrew is already installed"
    return 0
  fi

  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  ensure_homebrew_path
  if command -v brew &> /dev/null; then
    success "Homebrew installed successfully"
  else
    error "Homebrew installation failed"
    exit 1
  fi
}

install_brew_packages() {
  if [[ "$SKIP_PACKAGES" == true ]]; then
    warn "Skipping Homebrew packages installation"
    return 0
  fi

  ensure_homebrew_path
  if ! command -v brew &> /dev/null; then
    warn "Homebrew not available, skipping package installation"
    return 0
  fi

  info "Installing Homebrew packages..."

  for package in "${BREW_PACKAGES[@]}"; do
    if brew list "$package" &> /dev/null; then
      log_verbose "Package already installed: $package"
    else
      info "Installing package: $package"
      brew install "$package" || warn "Failed to install package: $package"
    fi
  done

  success "Homebrew packages installation complete"
}

install_brew_casks() {
  if [[ "$SKIP_CASKS" == true ]]; then
    warn "Skipping Homebrew casks installation"
    return 0
  fi

  ensure_homebrew_path
  if ! command -v brew &> /dev/null; then
    warn "Homebrew not available, skipping cask installation"
    return 0
  fi

  info "Installing Homebrew casks..."

  for cask in "${BREW_CASKS[@]}"; do
    # Special handling for docker - check if docker command exists
    if [[ "$cask" == "docker" ]] && command -v docker &> /dev/null; then
      log_verbose "Docker is already installed"
      continue
    fi

    if brew list --cask "$cask" &> /dev/null 2>&1; then
      log_verbose "Cask already installed: $cask"
    else
      info "Installing cask: $cask"
      brew install --cask "$cask" || warn "Failed to install cask: $cask"
    fi
  done

  success "Homebrew casks installation complete"
}

install_npm_global_packages() {
  if [[ "$SKIP_NPM_GLOBALS" == true ]]; then
    warn "Skipping global npm packages installation"
    return 0
  fi

  if ! command -v npm &> /dev/null; then
    warn "npm not available, skipping global npm packages"
    return 0
  fi

  info "Installing global npm packages..."

  for package in "${NPM_GLOBAL_PACKAGES[@]}"; do
    if npm list -g --depth=0 "$package" &> /dev/null; then
      log_verbose "Global npm package already installed: $package"
    else
      info "Installing global npm package: $package"
      npm install -g "$package" || warn "Failed to install global npm package: $package"
    fi
  done

  success "Global npm packages installation complete"
}

install_yarn_global_packages() {
  if [[ "$SKIP_YARN_GLOBALS" == true ]]; then
    warn "Skipping global yarn packages installation"
    return 0
  fi

  if ! command -v yarn &> /dev/null; then
    warn "yarn not available, skipping global yarn packages"
    return 0
  fi

  info "Installing global yarn packages..."

  for package in "${YARN_GLOBAL_PACKAGES[@]}"; do
    if yarn global list 2>/dev/null | grep -q "\"${package}@"; then
      log_verbose "Global yarn package already installed: $package"
    else
      info "Installing global yarn package: $package"
      yarn global add "$package" || warn "Failed to install global yarn package: $package"
    fi
  done

  success "Global yarn packages installation complete"
}

# ============================================================================
# Configuration functions
# ============================================================================

configure_github_token() {
  local zshrc_file="${HOME}/.zshrc"

  # Check if GITHUB_TOKEN is already exported
  if [[ -f "$zshrc_file" ]] && grep -q "^export GITHUB_TOKEN=" "$zshrc_file"; then
    success "GitHub token already configured"
    return 0
  fi

  info "GitHub token configuration"
  info "A GITHUB_TOKEN is useful for API rate limits and private repo access"
  info "Create a token at: https://github.com/settings/tokens"
  echo ""

  read -r -p "Enter your GITHUB_TOKEN (or press Enter to skip): " github_token || true

  if [[ -z "$github_token" ]]; then
    warn "GitHub token not set"
    return 0
  fi


  # Remove old GITHUB_TOKEN line if it exists in managed block
  local tmp_file="${zshrc_file}.tmp"
  local begin_marker="# >>> local-setup managed block >>>"
  local end_marker="# <<< local-setup managed block <<<"

  if grep -Fq "$begin_marker" "$zshrc_file" 2>/dev/null; then
    awk -v begin="$begin_marker" -v end="$end_marker" -v token="export GITHUB_TOKEN=\"${github_token}\"" '
      $0 == begin { in_block=1; print; next }
      $0 == end { print token; print; in_block=0; next }
      !in_block { print }
    ' "$zshrc_file" > "$tmp_file"
    mv "$tmp_file" "$zshrc_file"
  else
    # If managed block doesn't exist yet, just append it
    echo "export GITHUB_TOKEN=\"${github_token}\"" >> "$zshrc_file"
  fi

  success "GitHub token configured"
}

configure_zshrc() {
  if [[ "$SKIP_ZSHRC" == true ]]; then
    warn "Skipping zshrc configuration"
    return 0
  fi

  local zshrc_file="${HOME}/.zshrc"
  local tmp_file="${zshrc_file}.tmp"
  local block_file="${zshrc_file}.block.tmp"
  local begin_marker="# >>> local-setup managed block >>>"
  local end_marker="# <<< local-setup managed block <<<"

  info "Configuring zshrc..."

  # Ensure zshrc exists
  if [[ ! -f "$zshrc_file" ]]; then
    touch "$zshrc_file"
    log_verbose "Created new .zshrc file"
  fi

  # Strip any existing managed block (wherever it currently lives) so it can be
  # rewritten at the top of the file. Everything the managed block exports (DEV_HOME,
  # GOPATH, PATH additions, etc.) needs to be in place before later config relies on it.
  if grep -Fq "$begin_marker" "$zshrc_file"; then
    awk -v begin="$begin_marker" -v end="$end_marker" '
      $0 == begin { in_block=1; next }
      $0 == end { in_block=0; next }
      !in_block { print }
    ' "$zshrc_file" > "$tmp_file"
  else
    cp "$zshrc_file" "$tmp_file"
  fi

  # Drop leading blank lines left behind by the removed block so re-running this
  # doesn't accumulate extra blank lines between the block and the rest of the file.
  awk 'BEGIN{skipping=1} skipping && /^[[:space:]]*$/{next} {skipping=0; print}' "$tmp_file" > "${tmp_file}.trimmed"
  mv "${tmp_file}.trimmed" "$tmp_file"

  cat > "$block_file" << 'ZSHRC_MANAGED'
# >>> local-setup managed block >>>
# Environment variables
export DEV_HOME="${HOME}/dev"
export GOPATH="${DEV_HOME}/go"
export CODE_HOME="${DEV_HOME}/code"
export DOCKER_DATA_HOME="${DEV_HOME}/docker"
export DOCS_HOME="${DEV_HOME}/docs"
export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null)"
export LEARNING_HOME="${DEV_HOME}/learning"
export SCRIPTS_HOME="${HOME}/.local/bin"
export TEMPLATES_HOME="${DEV_HOME}/templates"
export CURRENT_USER="${USER}"

# Path additions
if [[ -n "${JAVA_HOME}" ]]; then
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi
if [[ -d "${SCRIPTS_HOME}" ]]; then
  export PATH="${SCRIPTS_HOME}:${PATH}"
fi
export PATH="${GOPATH}/bin:${PATH}"
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Aliases
alias k='kubectl'
alias code='cd ${CODE_HOME} && ls'
alias docs='cd ${DOCS_HOME} && ls'
alias designs='cd ${DEV_HOME}/designs && ls'
alias kc='kubectl config'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias tf='terraform'

PROMPT="%D%T %~ "
# <<< local-setup managed block <<<

ZSHRC_MANAGED

  cat "$block_file" "$tmp_file" > "$zshrc_file"
  rm -f "$tmp_file" "$block_file"

  success "zshrc configuration complete"
}

# ============================================================================
# Directory functions
# ============================================================================

create_dev_directories() {
  if [[ "$SKIP_DIRECTORIES" == true ]]; then
    warn "Skipping development directory creation"
    return 0
  fi

  info "Creating development directories..."

  for dir in "${DEV_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      log_verbose "Directory already exists: $dir"
    else
      mkdir -p "$dir"
      success "Created directory: $dir"
    fi
  done

  success "Development directory creation complete"
}

# ============================================================================
# Git configuration functions
# ============================================================================

configure_gitconfig() {
  if [[ "$SKIP_GITCONFIG" == true ]]; then
    warn "Skipping git global configuration"
    return 0
  fi

  info "Configuring global git settings..."

  local git_name="Frank P Moley III"
  local existing_email
  existing_email="$(git config --global user.email 2> /dev/null || true)"

  if [[ -n "$existing_email" ]]; then
    GIT_EMAIL="$existing_email"
    log_verbose "Git email already configured: $GIT_EMAIL"
  elif [[ -t 0 ]]; then
    while [[ -z "$GIT_EMAIL" ]]; do
      read -r -p "Enter your git email address: " GIT_EMAIL || true
      if [[ -z "$GIT_EMAIL" ]]; then
        warn "Email address is required for git configuration"
      fi
    done
  else
    warn "No git email configured and no terminal available to prompt; skipping user.email"
  fi

  git config --global user.name "$git_name"
  if [[ -n "$GIT_EMAIL" ]]; then
    git config --global user.email "$GIT_EMAIL"
  fi

  git config --global init.defaultBranch main

  git config --global url."git@github.com:".insteadOf "https://github.com/"
  git config --global url."git@gitlab.com:".insteadOf "https://gitlab.com/"

  local global_gitignore="${HOME}/.gitignore_global"
  if [[ ! -f "$global_gitignore" ]]; then
    cat > "$global_gitignore" << 'GITIGNORE_GLOBAL'
.idea/
.spec/
.plans/
**/.claude/settings.local.json
GITIGNORE_GLOBAL
    success "Created global gitignore: $global_gitignore"
  fi
  git config --global core.excludesFile "~/.gitignore_global"

  git config --global push.autoSetupRemote true
  git config --global pull.rebase true
  git config --global rebase.autoStash true
  git config --global merge.ff only

  success "Git global configuration complete"
}

generate_ssh_keypair() {
  if [[ "$SKIP_SSH_KEY" == true ]]; then
    warn "Skipping SSH keypair generation"
    return 0
  fi

  local key_path="${HOME}/.ssh/id_ed25519"

  if [[ -f "$key_path" ]]; then
    success "SSH keypair already exists at ${key_path}"
  else
    info "Generating SSH ed25519 keypair..."

    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"

    local key_comment="${GIT_EMAIL:-$(whoami)@$(hostname -s)}"
    ssh-keygen -t ed25519 -C "$key_comment" -f "$key_path" -N ""

    success "SSH keypair generated at ${key_path}"
  fi

  info "Copying public key to clipboard..."
  pbcopy < "${key_path}.pub"
  success "Public key copied to clipboard"

  echo ""
  info "Add your public key to:"
  info "  GitHub : https://github.com/settings/ssh/new"
  info "  GitLab : https://gitlab.com/-/profile/keys"
  echo ""
}

# ============================================================================
# AI coding tool configuration functions
#
# Grants AI coding tools (Claude Code, Codex CLI, GitHub Copilot CLI) access to
# the directories this script manages, so a fresh machine doesn't hit a wall of
# permission/trust prompts the first time an AI tool is pointed at ${DEV_HOME}.
# Every write here is additive/idempotent: existing config files are merged,
# never overwritten, and tools that aren't installed are left untouched.
# ============================================================================

# Turns "$HOME/dev/code" into "~/dev/code" for tools (like Claude Code) that
# accept tilde-relative paths in config, keeping settings portable across machines.
to_tilde_path() {
  echo "${1/#$HOME/\~}"
}

# Prints a JSON array from its arguments (or "[]" for none).
to_json_array() {
  if [[ $# -eq 0 ]]; then
    echo "[]"
  else
    printf '%s\n' "$@" | jq -R . | jq -sc .
  fi
}

configure_claude_settings() {
  if ! command -v jq &> /dev/null; then
    warn "jq not available, skipping Claude Code settings configuration"
    return 0
  fi

  local claude_dir="${HOME}/.claude"
  local settings_file="${claude_dir}/settings.json"
  mkdir -p "$claude_dir"

  # Grant access to every directory this script manages, and scope Edit/Write
  # to the same set (minus ~/.local/bin, whose contents are managed scripts).
  local additional_dirs=() allow_rules=() dir tilde_dir
  local static_allow=(
    "Read" "Glob" "Grep"
    "Bash(git status)" "Bash(git diff*)" "Bash(git log*)" "Bash(git add*)"
    "Bash(git commit*)" "Bash(git branch*)" "Bash(git checkout*)"
    "Bash(git pull*)" "Bash(git push*)"
    "Bash(ls*)" "Bash(grep*)" "Bash(cat*)" "Bash(pwd*)" "Bash(mkdir*)" "Bash(cd*)"
  )
  local static_deny=(
    "Bash(rm -rf*)" "Bash(curl*)" "Bash(wget*)"
    "Edit(~/.local/bin/**)" "Bash(chmod*~/.local/bin*)"
  )

  for dir in "${DEV_DIRS[@]}"; do
    tilde_dir="$(to_tilde_path "$dir")"
    additional_dirs+=("$tilde_dir")
    if [[ "$dir" != "${HOME}/.local/bin" ]]; then
      # Edit() rules cover all file-editing tools (Write included) in
      # Claude Code's permission checks; a separate Write() rule is never
      # matched and only clutters the settings file.
      allow_rules+=("Edit(${tilde_dir}/**)")
    fi
  done

  for dir in "${CLAUDE_READONLY_DIRS[@]}"; do
    tilde_dir="$(to_tilde_path "$dir")"
    additional_dirs+=("$tilde_dir")
    allow_rules+=("Read(${tilde_dir}/**)")
  done

  allow_rules=("${static_allow[@]}" "${allow_rules[@]}")

  local dirs_json allow_json deny_json
  dirs_json="$(to_json_array "${additional_dirs[@]}")"
  allow_json="$(to_json_array "${allow_rules[@]}")"
  deny_json="$(to_json_array "${static_deny[@]}")"

  if [[ -f "$settings_file" ]]; then
    local tmp_file="${settings_file}.tmp"
    if jq \
      --argjson newDirs "$dirs_json" \
      --argjson newAllow "$allow_json" \
      --argjson newDeny "$deny_json" \
      '# Write(...) rules are dead weight: only Edit(...) rules are matched by
       # Claude Code permission checks. Drop any stale Write() rule left over
       # from earlier versions of this script before merging in the current set.
       def dropDeadWrite: map(select(startswith("Write(") | not));
       .permissions = ((.permissions // {}) + {
         additionalDirectories: (((.permissions.additionalDirectories // []) + $newDirs) | unique),
         allow: ((((.permissions.allow // []) | dropDeadWrite) + $newAllow) | unique),
         deny: ((((.permissions.deny // []) | dropDeadWrite) + $newDeny) | unique)
       })' \
      "$settings_file" > "$tmp_file" 2> /dev/null; then
      mv "$tmp_file" "$settings_file"
      success "Merged dev directory permissions into: $settings_file"
    else
      rm -f "$tmp_file"
      warn "Failed to update Claude Code settings, leaving existing file untouched: $settings_file"
    fi
  else
    jq -n \
      --argjson dirs "$dirs_json" \
      --argjson allow "$allow_json" \
      --argjson deny "$deny_json" \
      '{permissions: {additionalDirectories: $dirs, allow: $allow, deny: $deny, defaultMode: "default"}}' \
      > "$settings_file"
    success "Created Claude Code settings: $settings_file"
  fi
}

# Marks ${DEV_HOME} as a trusted project for Codex CLI (~/.codex/config.toml),
# so project-scoped .codex/ layers load without a per-session trust prompt.
# Only touches the file if Codex CLI is actually installed.
configure_codex_trust() {
  local codex_home="${HOME}/.codex"
  [[ -d "$codex_home" ]] || { log_verbose "Codex CLI not installed (no ~/.codex), skipping"; return 0; }

  local config_file="${codex_home}/config.toml"
  local project_table="[projects.\"${HOME}/dev\"]"

  touch "$config_file"

  if grep -Fq "$project_table" "$config_file"; then
    log_verbose "Codex CLI already trusts ${HOME}/dev"
    return 0
  fi

  {
    echo ""
    echo "$project_table"
    echo "trust_level = \"trusted\""
  } >> "$config_file"

  success "Marked ${HOME}/dev as a trusted Codex CLI project"
}

# Adds dev directories to GitHub Copilot CLI's trusted folders
# (~/.copilot/config.json), so Copilot can read/write/exec there without a
# per-session trust prompt. Only touches the file if Copilot CLI is installed,
# and only ever adds to trustedFolders — no other keys in this
# tool-managed file are read or modified.
configure_copilot_trust() {
  local copilot_home="${HOME}/.copilot"
  [[ -d "$copilot_home" ]] || { log_verbose "Copilot CLI not installed (no ~/.copilot), skipping"; return 0; }

  if ! command -v jq &> /dev/null; then
    warn "jq not available, skipping Copilot CLI trusted folder configuration"
    return 0
  fi

  local config_file="${copilot_home}/config.json"
  local trusted_json
  trusted_json="$(to_json_array "${HOME}/dev" "${HOME}/.local/bin")"

  if [[ -f "$config_file" ]]; then
    local tmp_file="${config_file}.tmp"
    if jq --argjson newTrusted "$trusted_json" \
      '.trustedFolders = ((.trustedFolders // []) + $newTrusted | unique)' \
      "$config_file" > "$tmp_file" 2> /dev/null; then
      mv "$tmp_file" "$config_file"
      success "Added dev directories to Copilot CLI trusted folders"
    else
      rm -f "$tmp_file"
      warn "Failed to update Copilot CLI trusted folders, leaving existing file untouched: $config_file"
    fi
  else
    jq -n --argjson trusted "$trusted_json" '{trustedFolders: $trusted}' > "$config_file"
    success "Created Copilot CLI trusted folders: $config_file"
  fi
}

configure_ai_tool_access() {
  if [[ "$SKIP_AI_CONFIG" == true ]]; then
    warn "Skipping AI coding tool configuration"
    return 0
  fi

  info "Configuring AI coding tool access..."
  configure_claude_settings
  configure_codex_trust
  configure_copilot_trust
  success "AI coding tool configuration complete"
}

# ============================================================================
# Main entry point
# ============================================================================

main() {
  parse_args "$@"

  info "Starting local machine setup..."
  log_verbose "Script directory: $SCRIPT_DIR"

  check_dependencies
  ensure_xcode_clt
  install_homebrew
  install_brew_packages
  install_brew_casks
  install_npm_global_packages
  install_yarn_global_packages
  configure_github_token
  configure_zshrc
  create_dev_directories
  configure_gitconfig
  generate_ssh_keypair
  configure_ai_tool_access

  echo ""
  success "Setup complete! 🎉"
  info "You may need to restart your terminal or run: source ~/.zshrc"
}

main "$@"
