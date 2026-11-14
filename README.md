# dotfiles

Personal macOS, Ubuntu, and WSL setup.

## Install

```bash
./bootstrap.sh
```

Use `--dry-run` to preview or `--skip-brew` / `--skip-apt` to skip package setup.
Replaced files are backed up under `~/.dotfiles-backups/`.

macOS uses Homebrew. Ubuntu uses apt for system packages and Docker, plus
Homebrew for CLI tools. WSL uses Docker Desktop integration; enable the distro
under Docker Desktop **Settings > Resources > WSL Integration**.

VS Code settings are symlinked on macOS and Ubuntu. In WSL, bootstrap pushes
repo settings to Windows VS Code. Pull Windows edits before committing:

```bash
./platform/wsl/vscode-sync.sh pull
./platform/wsl/vscode-sync.sh push
```

## Managed configuration

Shell, Ghostty, Starship, VS Code, Git identity, and Codex CLI. macOS keyboard
replacements are in `platform/osx/`.

Mirror home-directory paths under `home/`. Put platform setup in `platform/` and
app configs with custom destinations under `apps/`.
