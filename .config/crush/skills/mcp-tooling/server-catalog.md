# MCP Server Catalog

Reference for the `mcp-tooling` skill. Per-server detail sourced from
`.config/crush/crushrc`. Any server listed here may be disabled at any
time; verify availability by attempting its tools, and fall back gracefully.

## filesystem

- **Purpose:** read, list, search, and move/copy files over MCP.
- **Why it exists:** the built-in `view`/`ls`/`grep`/`glob` tools are
  sufficient for most file work; this server adds directory trees and
  file operations the built-ins lack.
- **Constraints:** subject to the same sandbox mounts as everything else
  (working directory plus `xdg-config/crush`); see the
  `crush-environment` skill's `sandbox.md`.

## git

- **Purpose:** git operations inside the working directory: status, diff,
  log, staging.
- **Constraints:** pushed to remotes never happens from the agent per
  global policy; use this server for local operations only.

## github

- **Purpose:** read-only GitHub access: PRs, issues, releases, Actions.
- **Constraints:** read-only; cannot create or mutate PRs, issues, or
  repos. Requires `GITHUB_PERSONAL_ACCESS_TOKEN`, injected from gopass by
  the launcher. If auth fails, a missing secret is a likely cause.

## context7

- **Purpose:** resolve library/framework names and query current docs.
- **Constraints:** requires network. Prefer this over memory when writing
  or reviewing code against any framework.

## exa

- **Purpose:** general web search; find pages when the target URL is
  unknown.
- **Constraints:** requires network. Prefer built-in `webfetch` when the
  URL is already known.

## bruno

- **Purpose:** API testing via Bruno collections.
- **Constraints:** requires a Bruno collection path. If its tools are
  missing, the server is currently disabled in `crushrc`; state the gap
  and move on.

## Failure modes

- A server's tools simply not appearing in the tool list means it is
  disabled or failed to start. Do not retry endlessly; note it and use a
  fallback.
- Auth-related failures (401/403) usually mean the gopass-injected
  environment variable is missing or stale; tell the user which secret is
  affected (name only, never its value).
