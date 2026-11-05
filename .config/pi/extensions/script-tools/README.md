# script-tools

Bash scripts here are automatically registered as LLM-callable tools by the
`script-tools` extension (`../script-tools.ts`). To add a tool, drop a `.sh`
file in this directory and run `/script-tools-reload` (or restart pi).

The scripts directory defaults to the `script-tools` directory next to
`../script-tools.ts`; override it with the `PI_SCRIPT_TOOLS_DIR` environment
variable.

Tool-call permission gating is handled separately by the
`@gotgenes/pi-permission-system` package, configured in
`../pi-permission-system/config.json`.

## Script header format

The interface is declared in a comment header, which ends at the first
non-comment, non-blank line:

```bash
#!/usr/bin/env bash
# tool: deploy                    (optional; defaults to filename without .sh)
# description: What the tool does — shown to the LLM
# timeout: 60000                  (optional, milliseconds; default 60000)
# lazy                            (optional; defer until tool_search loads the tool)
# detect: go.mod,*.go             (optional; auto-activate when a marker matches the session cwd)
# param: branch required Branch to deploy
# param: dry_run boolean optional Skip actual deploy
# param: mode oneof:fast,safe optional Deployment mode

set -euo pipefail
...
```

### Param syntax

```
# param: <name> [string|number|boolean|oneof:a,b,c] [required|optional] [description]
```

- `type` defaults to `string`.
- `required|optional` defaults to `required`.
- `oneof:` defines an enum (the LLM can only pass the listed values).

### Lazy tools

Add a bare `# lazy` line (or `# lazy: on`) to register the tool with
`deferred` exposure: it is not declared to the model at startup and costs no
prompt space. The built-in `tool_search` tool declares it on demand — the
tool stays declared for the rest of the session — and codemode scripts can
call it at any time without declaration. Permission gating is unaffected;
deferred tools still go through the allowlist like everything else.

### Detected (auto-activation)

`# detect: marker[,marker...]` registers the tool inactive and activates it
automatically when any marker matches an entry at the root of the session
cwd. Markers are exact names (`go.mod`), `*`/`?` globs (`*.go`), or
directory names (a trailing `/` is ignored, e.g. `.github`).

- Detection runs on every session start (including `/resume`) and after
  `/script-tools-reload`, using the session cwd.
- Fail closed: if the cwd cannot be read, nothing is activated.
- Unmatched detect tools stay deferred; `tool_search` can load them on
  demand. `# lazy` composes: lazy tools are never eager, detect tools are
  eager only on a match. Permission gating is unaffected either way.

### Passing values to the script

Parameters are exported as environment variables, uppercased with
non-alphanumerics replaced by `_` and prefixed with `PI_TOOL_`:

| Header                       | Env var            | Value                    |
| ---------------------------- | ------------------ | ------------------------ |
| `param: branch ...`          | `PI_TOOL_BRANCH`   | the string               |
| `param: dry_run boolean ...` | `PI_TOOL_DRY_RUN`  | `true` / `false`         |
| `param: count number ...`    | `PI_TOOL_COUNT`    | e.g. `3`                 |

- Absent optional params export as empty string.
- `PI_TOOL_ARGS_JSON` holds the full args object as JSON.
- `PI_TOOL_SCRIPT_NAME` holds the tool name.
- The script runs with the current session's working directory.

### Positional arguments

If the header declares a string param named `args`, its value is tokenized
with POSIX shell quoting rules (single quotes, double quotes, backslash
escapes) and passed to the script as positional parameters, available as
`"$@"`. Quoted arguments — including ones containing spaces or newlines —
survive intact. This is the recommended way to pass command lines; the
scripts in this directory call their target command as `<command> "$@"`.

### Output

- stdout is returned to the LLM as the tool result (stderr is included under a
  `stderr:` label; large output is truncated in the middle).
- A non-zero exit code marks the result as an error and appends
  `exit code: N`.
- Prefer `set -euo pipefail` so unexpected failures fail loudly.
- Scripts without a `# timeout:` header are terminated after 60 seconds.
