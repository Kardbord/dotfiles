# No-Bash Tooling Playbook

Reference for the `crush-environment` skill. Bash is denied in this
environment. This file maps common shell tasks to the tools that actually
work. Check the table before reaching for bash, even "just to check".

## Command replacements

| Shell task                     | Replacement                                                    |
|--------------------------------|----------------------------------------------------------------|
| `cat`, `head`, `tail`          | `view` (with `offset`/`limit` for head/tail)                   |
| `ls`, `find`                   | `ls`, `glob`                                                   |
| `grep`, `rg`                   | `grep`                                                         |
| `sed -i`, `awk` transforms     | `edit` (find/replace, or rewrite via its full replacement)     |
| `wc -l`                        | `view` and read the line numbers                               |
| `pwd`                          | The working directory is shown in your context; don't guess    |
| `which`, `command -v`          | Not possible — state the gap                                   |
| `df`, `free`, `ps`             | Not possible — state the gap                                   |
| `curl`, `wget`                 | `webfetch`                                                     |
| `git status/diff/log/commit`   | `git` MCP server tools                                         |
| `gh pr/issue/run`              | `github` MCP server tools (read-only)                          |
| `go build/test/vet`            | Not possible in the sandbox — ask the user to run it           |
| `make`, package managers       | Not possible in the sandbox — ask the user to run it           |
| piped multi-command pipelines  | Decompose into separate tool calls where each step is covered  |

## Rules of thumb

1. **Prefer dedicated tools over any script.** A shell command that could
   be replaced by one tool call is the wrong choice here.
2. **Decompose, don't chain.** A single bash invocation often hides several
   steps (`grep | sort | head`). Express each step as its own tool call and
   combine results yourself.
3. **State gaps instead of guessing.** If nothing in the table covers a
   task, say so explicitly and either ask the user to run it or propose the
   closest workable alternative. Never claim you ran a command you could
   not run.
4. **Read-only probes only via listed tools.** You cannot create temp files,
   run binaries, or inspect processes inside the sandbox.
