# Worktree workflow

- Use a managed Git worktree by default for coding tasks in every Codex surface
  that supports worktree creation. Do not wait for the user to repeat this
  preference. The interactive `codex` shell command and `cw` shortcut do this
  automatically.
- Resume an existing session with `codex resume`; it continues in that
  session's existing checkout.
- Fork a session into a separate worktree with `codex fork --worktree <session-id>`.
- Use `codex-here` only when a task should work in the current checkout.
- In the Codex app or IDE, select the worktree execution environment when
  starting a task. If already in a managed worktree, continue there.
- Before editing, confirm the active checkout and branch. If the current surface
  cannot create a worktree, explain that limitation and give the user the exact
  action needed to start one; do not silently edit the base checkout.
- At the end of each turn, show the turn's diff summary. `td` displays the most
  recent saved turn diff for the current Git worktree; use `td --last` to skip
  empty turns and `td --all` to inspect the most recent diff across worktrees.
- When the host provides a **Pull changes** action, use it after completing the
  requested work so the worktree changes reach the base checkout. If the host
  does not provide that action, report the worktree branch and the exact
  integration step. Do not create a commit unless the user asks for one.

## README style

- Use numbered lists in README files instead of bulleted lists.

## Command preference

- Prefer simple `just` commands over `uv` or other tooling.

## Commit style

- Always use Conventional Commits with one concise, descriptive line and no body.
