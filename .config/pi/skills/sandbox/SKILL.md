---
name: sandbox
description: >
  Pi runs inside a Flatpak sandbox. Use this skill when file access fails
  unexpectedly (EPERM/ENOENT on paths that should exist), when a task seems
  to need paths outside the working directory, when handling secrets or
  credentials, or any time you need to know what the environment allows
  before attempting it. Prevents wasted retries against access the sandbox
  will never grant.
---

# Sandbox environment

Pi executes here inside a [Flatpak](https://flatpak.org) sandbox
(`io.github.kardbord.dev`, launched from the user's shell wrapper). The
sandbox exists because pi runs LLM-generated code: it contains the blast
radius of a compromised model, plugin, or dependency. See the host's
`~/projects/dotfiles/docs/SECURITY.md` (when accessible) for the full
security model: secrets manager (gopass + age), sandboxing, filesystem
permissions, and firewall as independent layers.

## What the sandbox allows

| Resource | Access |
| --- | --- |
| Session working directory (`${PWD}` at launch) | read/write |
| `~/.config/pi` (the pi agent dir) | read/write |
| `/tmp`, `/var/tmp` | read/write |
| Network | available |
| Everything else under `$HOME` | **not mounted** |
| Other absolute paths | **not mounted** |

Consequences:

- `~/.ssh`, `~/.gitconfig`, `~/.bashrc`, the dotfiles repo, and any path
  outside the session cwd are **inaccessible**. A read there fails with
  `EPERM`/`ENOENT` — that failure is the sandbox working, not a bug.
- **Do not retry or probe for workarounds.** When access fails this way,
  stop after one attempt, state that the sandbox denies the path, and ask
  the user to act outside the sandbox if it is genuinely needed.
- The user has a `pi-nosandbox` shell command that widens access
  (`--filesystem=host`). That is a **user decision only** — never request
  or suggest it as a workaround for routine work.

## External directories

The pi permission system may allow specific directories beyond the mounts
above (configured in `extensions/pi-permission-system/config.json`,
`external_directory`). The pi documentation tree
(`/app/lib/kardbord-tools/pi/`) is allowed. Treat an `external_directory`
"ask" prompt as normal; do not treat denial as a sandbox malfunction.

## Secrets

- API keys are injected at launch as environment variables
  from the user's gopass store by the shell wrapper.
  The GitHub token is a **read-only** personal access token.
- **NEVER print, log, quote, copy, or embed these values** — not in tool
  output, not in code, not in reports. If a task seems to require reading
  one, stop and ask the user.
- Config referencing secrets must use `${VAR}` expansion (as `mcp.json`
  does), never literal values.
- Files matching `*.env` are denied by the permission system's path rules
  (`*.env.example` is allowed). This is intentional.

## Environment quirks

- `GIT_AUTHOR_NAME`/`GIT_COMMITTER_NAME`/emails are preset by the wrapper;
  do not modify git configuration persistently.
- Go build caches live under XDG dirs (`GOPATH`, `GOMODCACHE`, `GOCACHE`);
  reuse them, do not override.
- The sandbox shares Wayland/X11 and IPC sockets; TUI and image display
  work normally.

## If a task cannot be done inside the sandbox

Say so plainly: name the blocked path or capability, what was attempted,
and what the user could do outside the sandbox. Do not fabricate success,
and do not weaken the task's goal to fit the sandbox without flagging the
change.
