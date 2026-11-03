---
name: crush-environment
description: >
  Use when working inside the Crush/charmcrush environment: bash is denied,
  Crush runs inside a flatpak sandbox with restricted filesystem access and
  gopass-injected secrets. Consult before running commands, accessing files
  outside the working directory, or when a task seems to require shell.
user-invocable: true
---

# Crush Environment

This instance of Crush runs inside a flatpak sandbox with a deliberately
restricted toolset. Read the quick facts first, then use the decision table.
Load the reference files only when you need deeper detail.

## Hard constraints

- **The `bash` tool is denied.** Any attempt to invoke it fails. Do not try
  to work around it; see `no-bash-tooling.md` for the replacement playbook.
- **Filesystem access is limited to the current working directory plus
  `xdg-config/crush`** (`~/.config/crush`). Paths outside these mounts,
  including `$HOME/.config` for other tools, are not readable.
- **Network access is available** (the sandbox shares the host network), so
  `webfetch` and HTTP-based MCP servers work normally.
- **Secrets are injected from gopass as environment variables** by the
  launcher, not stored in any file. See `sandbox.md` for the list.
- Allowed built-in tools: `view`, `ls`, `grep`, `glob`, `edit`, `task`,
  `webfetch`, `question`, `lsp`, `skill`.

## Decision table

| Task                              | Tool                                        |
|-----------------------------------|---------------------------------------------|
| List files                        | `ls` / `glob`                               |
| Search file contents              | `grep`                                      |
| Read or view a file               | `view`                                      |
| Edit or create a file             | `edit` (it can also create files)             |
| Fetch a URL                       | `webfetch`                                  |
| Git status/diff/log/commit        | `git` MCP server                            |
| PRs, issues, GitHub Actions       | `github` MCP server (read-only)             |
| Library/framework docs            | `context7` MCP server                       |
| Web search                        | `exa` MCP server                            |
| Language-server operations        | `lsp` tools                                 |
| Structured subagent work          | `task` tool                                 |

## Reference files

- `sandbox.md` — flatpak sandbox internals: mounts, env injection, failure
  symptoms. Load when a path unexpectedly fails or a secret seems missing.
- `no-bash-tooling.md` — full playbook for replacing shell commands with
  dedicated tools. Load when a task seems to require a shell.
