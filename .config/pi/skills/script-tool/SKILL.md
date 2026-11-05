---
name: script-tool
description: >
  Add, modify, or debug a Pi script tool — a bash script in the pi config's
  script-tools directory that is registered as an LLM-callable tool. Use when
  the user asks for a new command tool ("add a tool for X", "let the agent
  run X"), reports that a script tool misbehaves, or asks how script tools
  work.
---

# Script tools

Script tools turn bash scripts into LLM-callable tools. The pi process runs
in a Flatpak sandbox with **no bash tool** — script tools are the sanctioned
way for the agent to execute commands. Scripts live in
`~/.config/pi/extensions/script-tools/` and are registered by the
`script-tools` extension.

**The authoritative interface spec is
`~/.config/pi/extensions/script-tools/README.md` — read it before writing
or changing any script.** This skill covers the house conventions on top of
it.

## Adding a tool

1. **Read the README** (above) for the header format, param syntax, lazy /
   detect semantics, and env-var contract.
2. **Check the name** is not reserved: `read`, `bash`, `powershell`, `edit`,
   `write`, `grep`, `find`, `ls`, `codemode`, `thought`, `todo`, `subagent`
   are rejected by the extension. Names are `[a-zA-Z][a-zA-Z0-9_]*`.
3. **Write `~/.config/pi/extensions/script-tools/<name>.sh`** following the
   house pattern (see `fd.sh`, `go_test.sh` for reference):
   - Shebang `#!/bin/bash`, then the `#`-comment header. The header ends at
     the first non-comment, non-blank line.
   - `# description:` in the style "Runs `X` followed by the arguments you
     pass." — first sentence is what the model sees in the tool list, make
     it count.
   - `set -euo pipefail` as the first code line so failures fail loudly.
   - Source `include/check_dependencies.sh` and call
     `check_dependencies <cmd>` for each prerequisite.
   - Prefer the single `# param: args string required <desc>` convention:
     the extension tokenizes it with POSIX quoting rules and passes it as
     `"$@"`. Invoke the target as `<cmd> "$@"`.
   - Add `# lazy` when the tool is niche (deferred until `tool_search`
     loads it), and `# detect: <markers>` when it only applies to certain
     projects (markers match entries at the root of the session cwd, e.g.
     `go.mod,*.go`). Add `# timeout:` above 60000 only when the command
     genuinely needs longer.
   - Forbid dangerous flags explicitly where relevant (`fd.sh` rejects
     `--exec`/`--exec-batch`; mirror that thinking for anything that turns
     the tool into an arbitrary-code executor).
4. **Add a permission entry** in
   `~/.config/pi/extensions/pi-permission-system/config.json`:
   `"<tool-name>": "allow"` (or `"ask"`). Unlisted tools fall through to
   the `"*": "ask"` default, so an explicit entry is expected for anything
   routine.
5. **Decide mode availability.** Script tools are excluded from read/plan
   modes unless added to `~/.config/pi/extensions/modes/config.json`
   (`"+<tool-name>"`). Only add genuinely read-only tools there; anything
   that executes project code stays build-mode-only.
6. **Reload**: ask the user to run `/script-tools-reload` (or restart pi).
   The model cannot run slash commands itself.
7. **Verify**: after reload, call the new tool with a harmless argument and
   confirm sane stdout/stderr and exit code.

## Debugging an existing tool

- **Tool not registered**: the header must end at the first non-comment
  line; a stray blank line is fine, a code line is not. Check the startup
  / reload notification for per-script problems (reserved name, unreadable
  file).
- **Params arrive empty**: env vars are `PI_TOOL_<NAME_UPPERCASE>`
  (non-alphanumerics → `_`). Absent optionals export as empty string, so
  `:-default` expansions apply. Full args are also in `PI_TOOL_ARGS_JSON`.
- **Output cut off**: output is truncated at 30,000 chars (middle elided).
  Make the script quieter or write files to `/tmp` and summarize.
- **Killed / "terminated"**: hit the timeout (default 60 s) or output
  limit. Raise `# timeout:` only for genuinely slow commands.
- **Quoting surprises**: prefer the `args` param (already shell-tokenized
  by the extension) over parsing `PI_TOOL_ARGS_JSON` by hand.
- **Detect never activates**: markers match entries at the **root** of the
  session cwd only (exact name, `*`/`?` glob, or directory name). Fail
  closed — unreadable cwd means nothing activates; the tool stays
  deferred and loadable via `tool_search`.

## Sandbox notes

Scripts run with the session's cwd inside the Flatpak sandbox (see the
`sandbox` skill): only the cwd, `~/.config/pi`, `/tmp`, and `/var/tmp` are
mounted. A tool that needs other paths will fail there — design around it
or tell the user the command belongs outside the sandbox.
