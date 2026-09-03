# dotfiles

Personal, public-safe macOS development environment configuration.

## Install

Clone the repository, enter it, and run:

```bash
./bootstrap.sh
```

The bootstrap script installs Homebrew packages from `Brewfile`, then creates symlinks from the repository into your home directory. Existing files are moved to a timestamped directory under `~/.dotfiles-backups/` before they are replaced.

Useful options:

```bash
./bootstrap.sh --dry-run
./bootstrap.sh --skip-brew
```

The script can be run repeatedly and determines its paths from the script location, so the current working directory does not matter.

## Managed configuration

- Shell: `.zshrc`, `.zprofile`, `.bashrc`, `.bash_profile`, and `.shell_common`
- Homebrew: `Brewfile`
- CLI tools: Starship, Atuin, btop, GitHub CLI, Ghostty, and Zellij
- VS Code: settings and keybindings

## Adding configuration

Add portable, non-secret files to the repository using the same path they should have under `$HOME` when practical. Add special platform paths to `bootstrap.sh`, document them here, and update `.gitignore` for any generated or sensitive files.
