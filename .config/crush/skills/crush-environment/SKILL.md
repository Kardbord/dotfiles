---
name: crush-environment
description: >
  Use when working inside the Crush/charmcrush environment: bash is
  available but approval-gated, and Crush runs inside a flatpak sandbox with
  restricted filesystem access and gopass-injected secrets. Consult before
  reaching for shell, accessing files outside the working directory, or
  when a task seems to require shell.
user-invocable: true
---

# Crush Environment

This instance of Crush runs inside a flatpak sandbox. Bash is available but
prompts for approval on every call. Read the quick facts first, then use
the decision table. Load the reference files only when you need deeper
detail.

## Hard constraints

- **The `bash` tool is approval-gated.** It is visible and usable, but every
  invocation requires user approval. Use it sparingly, prefer built-in
  tools and MCP servers, and never call it mid-task; batch shell work to a
  task boundary instead. See `bash-avoidance.md` for the prefer-non-bash
  playbook.
- **No workarounds.** Never emulate shell behavior through other tools: do
  not write a program in an alternative language and execute it via allowed
  tools, do not generate code for the user to run purely to obtain
  execution, and do not chain MCP tools to simulate a shell pipeline. If
  bash is the right tool, request it directly; otherwise stop and report
  the gap.
- **Filesystem access is limited to the current working directory plus
  `xdg-config/crush`** (`~/.config/crush`). Paths outside these mounts,
  including `$HOME/.config` for other tools, are not readable.
- **Network access is available** (the sandbox shares the host network), so
  `webfetch` and HTTP-based MCP servers work normally.
- **Secrets are injected from gopass as environment variables** by the
  launcher, not stored in any file. See `sandbox.md` for the list.
- Allowed built-in tools: `view`, `ls`, `grep`, `glob`, `edit`, `task`,
  `webfetch`, `question`, `lsp`, `skill`, plus `bash` in the prompted
  (approval-required) state.

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
| Anything else (shell-only)        | `bash` (last resort; approval required; check `sandbox.md` limitations first) |

## Reference files

- `sandbox.md` — flatpak sandbox internals: mounts, env injection, failure
  symptoms. Load when a path unexpectedly fails or a secret seems missing.
- `bash-avoidance.md` — playbook for preferring dedicated tools over shell,
  including the no-workaround rule and when bash is appropriate. Load when
  a task seems to require a shell.
