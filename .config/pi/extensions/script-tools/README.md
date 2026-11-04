# script-tools

Bash scripts here are automatically registered as LLM-callable tools by the
`script-tools` extension (`../extensions/script-tools.ts`). To add a tool,
drop a `.sh` file in this directory and run `/script-tools-reload` (or restart
pi).

The scripts directory defaults to `~/.config/pi/script-tools`; override with
the `PI_SCRIPT_TOOLS_DIR` environment variable.

## Script header format

The interface is declared in a comment header, which ends at the first
non-comment, non-blank line:

```bash
#!/usr/bin/env bash
# tool: deploy                    (optional; defaults to filename without .sh)
# description: What the tool does — shown to the LLM
# timeout: 60000                  (optional, milliseconds)
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

### Output

- stdout is returned to the LLM as the tool result (stderr is included under a
  `stderr:` label; large output is truncated in the middle).
- A non-zero exit code marks the result as an error and appends
  `exit code: N`.
- Prefer `set -euo pipefail` so unexpected failures fail loudly.

