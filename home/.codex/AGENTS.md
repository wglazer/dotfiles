## README style

- Use numbered lists in README files instead of bulleted lists.

## Commands and commits

- Prefer simple `just` commands over `uv` or other tooling.
- Use Conventional Commits with one concise, descriptive line and no body.

## General design and writing

- Keep documentation short. Explain purpose, usage, and important constraints; keep runnable examples covered by unit tests.
- Apply the software design philosophy often: reduce complexity, hide decisions behind clear interfaces, and make code obvious to read and change.
- Prefer precise names and prose-like code. Invest in design quality as part of each change.

## Python

- Prefer `uv`, `ruff`, and `basedpyright` for new Python work; follow the project's existing tool configuration when it differs.
- In `/hack`, treat Python files as notebook-style scripts when appropriate: use the project's `jpytxt` workflow and finish with a `# %%` cell for VS Code's Run All.
- Define the domain model and suitable dataclasses before building functions. Prefer strong types and functional composition when they clarify data flow; use composed objects when they provide useful boundaries. Use classmethods for stateless construction when helpful.
- Write tests that read like prose. Prefer focused tests, `pytest.mark.parametrize` for repeated cases, and reusable fixtures, including dataclass-backed fixtures when they clarify setup. Treat complex tests as a design smell; code that cannot be unit-tested or mocked may need a better seam.
