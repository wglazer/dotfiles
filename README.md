# dotfiles

Personal macOS terminal and development environment configuration.

## Structure

```text
home/       Files linked into $HOME, keeping their final paths
apps/        Application configurations with custom destinations
bootstrap.sh
Brewfile
```

## Install

Clone the repository, enter it, and run:

```bash
./bootstrap.sh
```

The bootstrap script installs Homebrew packages from `Brewfile`, then creates
symlinks from `home/` and `apps/vscode/` into their final locations. Existing
files are moved to a timestamped directory under `~/.dotfiles-backups/` before
they are replaced.

Useful options:

```bash
./bootstrap.sh --dry-run
./bootstrap.sh --skip-brew
./bootstrap.sh --restore-signing
```

The script can be run repeatedly and determines its paths from the script location, so the current working directory does not matter.

## Managed configuration

- Shell: `home/.zshrc`, `home/.zprofile`, `home/.bashrc`, `home/.bash_profile`, and `home/.shell_common`
- SSH: `home/.ssh/config` (`ssh gpu1` and `ssh gpu2`)
- Homebrew: `Brewfile`
- Tools and apps: Starship, Atuin, btop, GitHub CLI, Ghostty, and Zellij
- VS Code: `apps/vscode/settings.json` and `apps/vscode/keybindings.json`
- Espanso: `apps/espanso/config/default.yml` and `apps/espanso/match/base.yml`

## Adding configuration

Add files destined for `$HOME` under `home/` using the same relative path.
Put app-specific configurations that need custom destinations under `apps/`
and add their link to `bootstrap.sh`. Update `.gitignore` for any generated or
sensitive files.

Espanso owns the keyboard replacements managed here. Bootstrap clears the
native macOS replacement list to prevent duplicate triggers.
