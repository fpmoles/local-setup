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
SKIP_ZSHRC=false
SKIP_DIRECTORIES=false
VERBOSE=false

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
  "oracle-jdk@17"
  "oracle-jdk@21"
  "oracle-jdk"
)

# Development directories to create
declare -a DEV_DIRS=(
  "${HOME}/dev"
  "${HOME}/dev/code"
  "${HOME}/dev/projects"
  "${HOME}/dev/learning"
  "${HOME}/dev/docker"
  "${HOME}/.local/bin"
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
  --skip-zshrc              Skip zshrc configuration
  --skip-directories        Skip development directory creation
  --skip-all                Skip all installation steps (useful for testing)

Examples:
  ./setup.sh                              # Full setup
  ./setup.sh --skip-packages              # Skip packages only
  ./setup.sh --verbose                    # Verbose output
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
      --skip-zshrc)
        SKIP_ZSHRC=true
        shift
        ;;
      --skip-directories)
        SKIP_DIRECTORIES=true
        shift
        ;;
      --skip-all)
        SKIP_HOMEBREW=true
        SKIP_PACKAGES=true
        SKIP_CASKS=true
        SKIP_ZSHRC=true
        SKIP_DIRECTORIES=true
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

install_homebrew() {
  if [[ "$SKIP_HOMEBREW" == true ]]; then
    warn "Skipping Homebrew installation"
    return 0
  fi

  if command -v brew &> /dev/null; then
    success "Homebrew is already installed"
    return 0
  fi

  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

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

  read -r -p "Enter your GITHUB_TOKEN (or press Enter to skip): " github_token

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
  local begin_marker="# >>> local-setup managed block >>>"
  local end_marker="# <<< local-setup managed block <<<"

  info "Configuring zshrc..."

  # Ensure zshrc exists
  if [[ ! -f "$zshrc_file" ]]; then
    touch "$zshrc_file"
    log_verbose "Created new .zshrc file"
  fi

  # Replace only our managed block so user customizations outside this block stay intact.
  if grep -Fq "$begin_marker" "$zshrc_file"; then
    awk -v begin="$begin_marker" -v end="$end_marker" '
      $0 == begin { in_block=1; next }
      $0 == end { in_block=0; next }
      !in_block { print }
    ' "$zshrc_file" > "$tmp_file"
    mv "$tmp_file" "$zshrc_file"
  fi

  cat >> "$zshrc_file" << 'ZSHRC_MANAGED'

# >>> local-setup managed block >>>
# Environment variables
export DEV_HOME="${HOME}/dev"
export CODE_HOME="${DEV_HOME}/code"
export PROJECTS_HOME="${DEV_HOME}/projects"
export LEARNING_HOME="${DEV_HOME}/learning"
export DOCKER_DATA_HOME="${DEV_HOME}/docker"
export SCRIPTS_HOME="${HOME}/.local/bin"
export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null)"

# Path additions
if [[ -n "${JAVA_HOME}" ]]; then
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi
if [[ -d "${SCRIPTS_HOME}" ]]; then
  export PATH="${SCRIPTS_HOME}:${PATH}"
fi
if [[ "$(uname -m)" == "arm64" && -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if [[ "$(uname -m)" == "x86_64" && -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Aliases
alias k='kubectl'

PROMPT="%D%T %~ "
# <<< local-setup managed block <<<
ZSHRC_MANAGED

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
  configure_github_token
  configure_zshrc
  create_dev_directories

  echo ""
  success "Setup complete! 🎉"
  info "You may need to restart your terminal or run: source ~/.zshrc"
}

main "$@"
