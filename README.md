# dotfiles

Personal macOS and Ubuntu development environment configuration.

## Structure

```text
home/       Files linked into $HOME
apps/       Application configurations with custom destinations
bootstrap.sh
Brewfile
```

## Install

Clone the repository, enter it, and run:

```bash
./bootstrap.sh
```

Bootstrap installs packages and links configuration files. Replaced files are
backed up under `~/.dotfiles-backups/`.

macOS uses Homebrew for tools and apps, including Colima and Docker. Ubuntu
uses apt for Docker and Homebrew prerequisites; Homebrew installs terminal tools.

Ubuntu setup needs sudo. Bootstrap keeps an existing apt Docker provider,
configures Docker's official repository if needed, and enables the service when
systemd is running. Conflicting or unmanaged installations stop setup.

Useful options:

```bash
./bootstrap.sh --dry-run
./bootstrap.sh --skip-brew
./bootstrap.sh --skip-apt
./bootstrap.sh --skip-brew --skip-apt
```

Use `--skip-brew --skip-apt` to link configuration without installing
packages. `--dry-run` previews actions without changing the system.

On Ubuntu, verify `/usr/bin/docker --version`, `/usr/bin/docker compose version`,
and `/usr/bin/docker buildx version` before removing Homebrew's Docker formulae:

```bash
brew uninstall docker docker-compose docker-buildx
```

Bootstrap does not remove these formulae automatically.

## Managed configuration

1. Managed: shell, Ghostty, Starship, VS Code, Git identity, and Codex CLI.
2. Bootstrap sets the global Git name to `wglazer` and asks for an email if one is not configured.
3. Codex includes managed defaults, worktree helpers, and turn diffs.
4. macOS keyboard replacements are in `apps/macos/`.

## Opinions

1. My default IDE is VS Code with the Codex terminal in the right panel, the
  editor in the center, and Git/files on the left. Set the terminal, editor,
  and sidebar widths manually (45% / 45% / 10%).
2. I strongly prefer simple `just` commands over `uv` or other tooling.

Shared shell environment and portable aliases live in `home/.shell_common`.
`home/.bashrc` and `home/.zshrc` source it, then initialize tools using the
syntax required by that shell. Keep shared values in `.shell_common`; keep
shell-specific hooks and options in their respective rc files.

## Adding configuration

Mirror `$HOME` paths under `home/`. Put files with custom destinations under
`apps/` and add their links to `bootstrap.sh`.
