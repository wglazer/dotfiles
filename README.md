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

## SSH and Git signing

Load both keys and configure the workstation:

```sh
ssh-add ~/.ssh/ai-machine-gpu && ssh-add ~/.ssh/github_signing && ./bootstrap.sh --skip-brew --skip-apt
```

Install the login and signing public keys, then configure both machines:

```sh
for host in old new; do cat ~/.ssh/ai-machine-gpu.pub | ssh "$host" 'umask 077; mkdir -p ~/.ssh; key=$(cat); grep -qxF "$key" ~/.ssh/authorized_keys 2>/dev/null || printf "%s\n" "$key" >> ~/.ssh/authorized_keys'; scp ~/.ssh/github_signing.pub "$host":~/.ssh/github_signing.pub; ssh "$host" 'cd ~/dotfiles && ./bootstrap.sh --skip-brew --skip-apt'; done
```

Register the signing key with GitHub once:

```sh
gh ssh-key add ~/.ssh/github_signing.pub --type signing --title "Git signing"
```

Verify:

```sh
ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no old true && ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no new true && ssh new 'ssh-add -L'
```

## Managed configuration

Shell, SSH, Ghostty, Starship, Git signing, and VS Code configuration are
managed. macOS keyboard replacements are in `apps/macos/`.

Shared shell environment and portable aliases live in `home/.shell_common`.
`home/.bashrc` and `home/.zshrc` source it, then initialize tools using the
syntax required by that shell. Keep shared values in `.shell_common`; keep
shell-specific hooks and options in their respective rc files.

## Adding configuration

Mirror `$HOME` paths under `home/`. Put files with custom destinations under
`apps/` and add their links to `bootstrap.sh`.
