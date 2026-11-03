---
name: mcp-tooling
description: >
  Use when deciding which MCP server or tool to invoke for a task: filesystem
  ops, git operations, GitHub PRs/issues/actions, web search, library docs,
  or API testing. Provides routing rules and per-server constraints.
user-invocable: true
---

# MCP Tooling

Routing rules for choosing the right MCP server or tool in this Crush
instance. Read the routing table first; load `server-catalog.md` when you
need per-server detail, constraints, or gotchas.

**Note:** any MCP server in this catalog may be disabled, removed, or
renamed at any time by a config change. Always treat a server as
unavailable when its tools fail or are missing; fall back to built-in
tools, `webfetch`, or ask the user rather than assuming it must exist.

## Routing table

| Task                                      | Server / tool                          |
|-------------------------------------------|----------------------------------------|
| Read/list/search local files              | `filesystem` MCP (or built-in view/ls/grep/glob) |
| Git status, diff, log, staging            | `git` MCP                              |
| PRs, issues, releases, Actions (read)     | `github` MCP                           |
| Library/framework documentation lookup    | `context7` MCP                         |
| General web search                        | `exa` MCP                              |
| Fetching a specific known URL             | built-in `webfetch`                    |
| API testing (Bruno collections)           | `bruno` MCP                            |

## Rules

1. **Built-in tools first for pure file work.** `view`/`ls`/`grep`/`glob`
   are faster and always available; use the `filesystem` MCP server only
   when you need capabilities the built-ins lack (e.g. directory trees,
   move/copy operations across allowed paths).
2. **`github` MCP is read-only.** It cannot create or mutate PRs, issues,
   or repos. For write actions, tell the user what to run themselves.
3. **`context7` before guessing library APIs.** When writing or reviewing
   code against a framework, resolve the library and query its docs rather
   than relying on memory of APIs that may have changed.
4. **`exa` for discovery, `webfetch` for known URLs.** If you already know
   the URL, don't pay for a search.
5. **One server at a time for chained work.** Prefer resolving a task with
   the single most specific server before fanning out.

## Reference files

- `server-catalog.md` — per-server detail: command lines, toolsets,
  environment requirements, and known failure modes. Load when a server
  misbehaves or you need exact capability lists.
