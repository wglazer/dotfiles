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
./bootstrap.sh --restore-signing
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

Shell, SSH, Ghostty, Starship, Git signing, and VS Code configuration are
managed. macOS keyboard replacements are in `apps/macos/`.

## Adding configuration

Mirror `$HOME` paths under `home/`. Put files with custom destinations under
`apps/` and add their links to `bootstrap.sh`.
