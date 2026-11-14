# Codex CLI wrappers for interactive Bash and zsh shells.

# Start new Codex sessions in managed worktrees. Keep resume and maintenance
# commands on the native CLI path.
codex() {
    case "${1:-}" in
        resume|fork|login|logout|mcp|plugin|features|update|doctor|app|app-server|agents|review|exec-server|import|completion|sandbox|debug|execpolicy|apply|cloud|queue|archive|delete|unarchive|migrate-rollouts|migrate-nfs-db|responses-api-proxy|stdio-to-uds|tcp-tunnel|remote-control|--help|-h|--version|-V)
            command codex "$@"
            ;;
        exec)
            shift
            case "${1:-}" in
                resume|review) command codex exec "$@" ;;
                *)
                    if command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                        command codex exec --worktree "$@"
                    else
                        command codex exec "$@"
                    fi
                    ;;
            esac
            ;;
        *)
            if command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                command codex --worktree "$@"
            else
                command codex "$@"
            fi
            ;;
    esac
}

cw() { command codex --worktree "$@"; }
codex-here() { command codex "$@"; }
