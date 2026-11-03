# Flatpak Sandbox Details

Reference for the `crush-environment` skill. Covers how the sandbox is
launched and what that means in practice.

## Launcher

`crush` is a shell function in `.bashrc.d/99-charmcrush.sh` that wraps:

```
flatpak run io.github.kardbord.dev charmcrush \
  --filesystem=${PWD} \
  --filesystem=xdg-config/crush \
  --share=network \
  --env=GIT_AUTHOR_NAME=... --env=GIT_AUTHOR_EMAIL=... \
  --env=GIT_COMMITTER_NAME=... --env=GIT_COMMITTER_EMAIL=...
```

A `crush-nosandbox` variant exists that replaces `--filesystem=${PWD}` with
`--filesystem=host`; the sandboxed variant is the default.

## Filesystem mounts

| Mount                | Effect                                                     |
|----------------------|------------------------------------------------------------|
| `${PWD}`             | The directory the user launched Crush from                 |
| `xdg-config/crush`   | `~/.config/crush` (CRUSH.md, crushrc, skills)              |

Anything else — other `~/.config` subdirectories, system paths, sibling
project directories — is invisible. If a file read fails with a permission
or not-found error for a path you believe exists, that path is almost
certainly outside the sandbox mounts. Tell the user instead of searching
for workarounds.

## Secret injection

The launcher runs `_run_with_secrets` before starting Crush, which pulls
each secret from gopass and exports it as an environment variable. Known
injected secrets:

- `OPENROUTER_API_KEY` ← `personal/openrouter/api-key`
- `OPENAI_API_KEY` ← `personal/openai/api-key`
- `ANTHROPIC_API_KEY` ← `personal/anthropic/api-key`
- `HF_TOKEN` ← `personal/huggingface/api-key`
- `GITHUB_PERSONAL_ACCESS_TOKEN` ← `personal/github/ro-pat`

Notes:

- Secrets exist only as environment variables inside the Crush process;
  they are not written to disk inside the sandbox.
- If a secret is missing from gopass, the launcher only prints a warning
  and continues, so a provider can silently fail. If an MCP server that
  relies on a token (e.g. `github`) errors out, a missing secret is a
  likely cause — report it rather than retrying.
- Never echo, log, or write these variables into files or output.
