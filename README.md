# local-setup

Automates local macOS setup using a single script, `setup.sh`, following
[fpm_bash_scripter](https://github.com/fpmoles/dev-pack/tree/main/skills/fpm_bash_scripter)
conventions.

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

```bash
curl -fsSL <raw-setup-sh-url> | bash -s -- --verbose
```

Use your repository raw script URL, for example:

```text
https://raw.githubusercontent.com/<owner>/<repo>/<branch>/setup.sh
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
- `oracle-jdk`

Notes:
- Docker cask is skipped when `docker` is already available in `PATH`.

## Directory Structure Created

Created from `DEV_DIRS` in `setup.sh`:

```text
~/dev/
  code/
  projects/
  learning/
  docker/
~/.local/
  bin/
```

## `.zshrc` Behavior

The script writes a managed block delimited by:

- `# >>> local-setup managed block >>>`
- `# <<< local-setup managed block <<<`

On re-run, it replaces only that block and leaves other `.zshrc` content untouched.

### Managed Environment Variables

- `DEV_HOME="${HOME}/dev"`
- `CODE_HOME="${DEV_HOME}/code"`
- `PROJECTS_HOME="${DEV_HOME}/projects"`
- `LEARNING_HOME="${DEV_HOME}/learning"`
- `DOCKER_DATA_HOME="${DEV_HOME}/docker"`
- `SCRIPTS_HOME="${HOME}/.local/bin"`
- `JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null)"`

### Managed PATH Additions

- Prepends `${JAVA_HOME}/bin` when `JAVA_HOME` is set
- Prepends `${SCRIPTS_HOME}` when directory exists
- Loads Homebrew shellenv for Apple Silicon (`/opt/homebrew`) or Intel (`/usr/local`)

### Managed Aliases

- `alias k='kubectl'`

### Managed Prompt

- `PROMPT="%D%T %~ "`

## GitHub Token Prompt

Before `.zshrc` block management, the script checks for an existing line matching:

- `export GITHUB_TOKEN=...`

If present, token prompting is skipped.
If not present, it prompts and writes the token export to `.zshrc`.

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
