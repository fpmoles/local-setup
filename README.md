# FPMoles Local Dev Setup

Automates local macOS setup 

It handles:
- Homebrew installation (if missing)
- Homebrew package and cask installation
- Xcode Command Line Tools installation (if missing)
- `.zshrc` managed block updates
- Development directory creation

## Prerequisites

- macOS
- `curl`
- `bash`

## Quick Start

Option 1: Run directly from GitHub (no clone)

```bash
curl -fsSL https://raw.githubusercontent.com/fpmoles/local-setup/main/setup.sh | bash -s -- --verbose
```

Option 2: Clone the repo and run locally

```bash
git clone https://github.com/fpmoles/local-setup.git
cd local-setup
chmod +x setup.sh
./setup.sh --verbose
```

## Usage

```bash
./setup.sh [OPTIONS]
```

### Options

| Option | Description |
|---|---|
| `-h`, `--help` | Show help and exit |
| `-v`, `--verbose` | Enable verbose output |
| `--skip-homebrew` | Skip Homebrew installation |
| `--skip-packages` | Skip Homebrew packages |
| `--skip-casks` | Skip Homebrew casks |
| `--skip-zshrc` | Skip `.zshrc` updates |
| `--skip-directories` | Skip directory creation |
| `--skip-gitconfig` | Skip git global configuration |
| `--skip-ssh-key` | Skip SSH keypair generation |
| `--skip-ai-config` | Skip AI coding tool configuration |
| `--skip-all` | Skip all install/config steps |

## What Gets Installed

### Homebrew Packages

Installed from `BREW_PACKAGES` in `setup.sh`:

- `azure-cli`
- `awscli`
- `curl`
- `git`
- `go`
- `httpie`
- `jq`
- `kind`
- `kubectl`
- `node`
- `python3`
- `vim`
- `wget`
- `yq`

### Homebrew Casks

Installed from `BREW_CASKS` in `setup.sh`:

- `docker`
- `oracle-jdk@17`
- `oracle-jdk@21`
- `oracle-jdk@25`
- `oracle-jdk`

Notes:
- Docker cask is skipped when `docker` is already available in `PATH`.

## Directory Structure Created

Created from `DEV_DIRS` in `setup.sh`:

```text
~/.local/
  bin/
~/dev/
  code/
  designs/
  docker/
  go/
  learning/
  proposals/
  templates/
```

## `.zshrc` Behavior

The script writes a managed block delimited by:

- `# >>> local-setup managed block >>>`
- `# <<< local-setup managed block <<<`

On re-run, it replaces only that block and leaves other `.zshrc` content untouched.

### Managed Environment Variables

- `CODE_HOME="${DEV_HOME}/code"`
- `CURRENT_USER="${USER}"`
- `DEV_HOME="${HOME}/dev"`
- `DOCKER_DATA_HOME="${DEV_HOME}/docker"`
- `GOPATH="${DEV_HOME}/go"`
- `JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null)"`
- `LEARNING_HOME="${DEV_HOME}/learning"`
- `SCRIPTS_HOME="${HOME}/.local/bin"`
- `TEMPLATES_HOME="${DEV_HOME}/templates"`

### Managed PATH Additions

- Prepends `${JAVA_HOME}/bin` when `JAVA_HOME` is set
- Prepends `${SCRIPTS_HOME}` when directory exists
- Prepends `${GOPATH}/bin`
- Loads Homebrew shellenv for Apple Silicon (`/opt/homebrew`) or Intel (`/usr/local`)

### Managed Aliases

- `alias k='kubectl'`
- `alias kc='kubectl config'`
- `alias kg='kubectl get'`
- `alias kd='kubectl describe'`
- `alias kl='kubectl logs'`
- `alias tf='terraform'`

### Managed Prompt

- `PROMPT="%D%T %~ "`

## GitHub Token Prompt

Before `.zshrc` block management, the script checks for an existing line matching:

- `export GITHUB_TOKEN=...`

If present, token prompting is skipped.
If not present, it prompts and writes the token export to `.zshrc`.

## Git Global Configuration

Sets, via `git config --global`:

- `user.name` / `user.email` (email is prompted for)
- `init.defaultBranch main`
- `url."git@github.com:".insteadOf https://github.com/`
- `url."git@gitlab.com:".insteadOf https://gitlab.com/`
- `core.excludesFile ~/.gitignore_global` — creates `~/.gitignore_global` with a small default
  (`.idea/`, `.spec/`, `.plans/`, `**/.claude/settings.local.json`) if it doesn't already exist
- `push.autoSetupRemote true`
- `pull.rebase true`
- `rebase.autoStash true`
- `merge.ff only`

## AI Coding Tool Configuration

Grants AI coding tools access to `DEV_DIRS` so a fresh machine doesn't hit a wall of
permission/trust prompts the first time an AI tool is pointed at `~/dev`. Every write is
additive and idempotent — existing config files are merged (never overwritten), and a tool
that isn't installed on the machine is left untouched.

| Tool | File | What's written |
|---|---|---|
| Claude Code | `~/.claude/settings.json` | `permissions.additionalDirectories` for every `DEV_DIRS` entry, plus `allow`/`deny` `Edit(...)` rules scoping file edits to those directories (`~/.local/bin` excluded — its contents are managed scripts). Only `Edit(...)` rules are written; `Write(...)` rules aren't matched by Claude Code's permission checks and are stripped from existing settings on each run |
| Codex CLI | `~/.codex/config.toml` | `[projects."~/dev"]` marked `trust_level = "trusted"` |
| GitHub Copilot CLI | `~/.copilot/config.json` | `~/dev` and `~/.local/bin` added to `trustedFolders` |

## Customization

Update these arrays in `setup.sh`:

- `BREW_PACKAGES`
- `BREW_CASKS`
- `DEV_DIRS`

## Troubleshooting

### Script not executable

```bash
chmod +x setup.sh
```

### Reload shell config

```bash
source ~/.zshrc
```

### Install a failed package manually

```bash
brew install <package-name>
```
