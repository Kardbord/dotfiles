# Bash Avoidance Playbook

Reference for the `crush-environment` skill. Bash is available but
approval-gated: every call pauses the session for user approval. Treat the
table below as the default route and bash as the fallback. Check the table
before reaching for bash, even "just to check".

## Command replacements

| Shell task                     | Replacement                                                    |
|--------------------------------|----------------------------------------------------------------|
| `cat`, `head`, `tail`          | `view` (with `offset`/`limit` for head/tail)                   |
| `ls`, `find`                   | `ls`, `glob`                                                   |
| `grep`, `rg`                   | `grep`                                                         |
| `sed -i`, `awk` transforms     | `edit` (find/replace, or rewrite via its full replacement)     |
| `wc -l`                        | `view` and read the line numbers                               |
| `pwd`                          | The working directory is shown in your context; don't guess    |
| `which`, `command -v`          | `bash` (approval required)                                     |
| `df`, `free`, `ps`             | `bash` (approval required)                                     |
| `curl`, `wget`                 | `webfetch`                                                     |
| `git status/diff/log/commit`   | `git` MCP server tools                                         |
| `gh pr/issue/run`              | `github` MCP server tools (read-only)                          |
| `go build/test/vet`            | May not exist in the sandbox runtime; try once via `bash` (approval required), and if the binary is missing, ask the user to run it |
| `make`, package managers       | May not exist in the sandbox runtime; try once via `bash` (approval required), and if the binary is missing, ask the user to run it |
| piped multi-command pipelines  | Decompose into separate tool calls where each step is covered  |

## Rules of thumb

1. **The table is the default route.** A shell command that could be
   replaced by one tool call is the wrong choice; bash is the fallback.
2. **Decompose, don't chain.** A single bash invocation often hides several
   steps (`grep | sort | head`). Express each step as its own tool call and
   combine results yourself.
3. **Sandbox caveat.** The bash tool runs inside the flatpak sandbox, so
   host-only binaries and toolchains (`go`, `make`, language toolchains)
   may not exist in the runtime. Try once; if the binary is missing, ask
   the user to run it instead. See `sandbox.md`.
4. **State gaps instead of guessing.** Never claim you ran a command you
   did not run.
5. **Workaround rule.** Do not simulate shell capabilities through
   non-shell tools: do not write a script or program in any language and
   execute it via `edit` plus an execution channel, and do not chain other
   tools to emulate a pipeline. Feeling the urge to emulate bash is a
   signal to use bash directly (with its approval gate) or stop and report
   the gap.

## When bash is appropriate

Bash is the right choice only for genuinely shell-only work, and best at a
task boundary rather than mid-implementation:

- Running project test, build, or lint scripts the sandbox supports.
- Environment probes (`which`, `ps`, `df`) when no tool covers them.
- Package-manager operations the sandbox runtime supports.

Every call requires user approval, so avoid it in the middle of a
long-running task; batch it to a checkpoint or surface the commands to the
user up front.
