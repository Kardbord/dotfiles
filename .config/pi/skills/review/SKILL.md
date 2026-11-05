---
name: review
description: >
  Conduct a structured code review. Launches a dedicated reviewer subagent to
  analyze the current uncommitted changes or a user-provided diff, and reports
  findings without applying fixes. Manually invoked only.
disable-model-invocation: true
---

# Review

Purpose: Provide a rigorous, expert-level code review of uncommitted changes
or a specific user-provided diff, using a dedicated cold-context reviewer
subagent (kimi-k2.7-code, read-only tools — see the `reviewer` agent
definition in settings).

## Scope
- **Default**: Review all uncommitted changes (staged + unstaged + untracked) in the repository.
- **Provided Diff**: If the user includes a diff, commit hash range, or file list in the message, review that instead.

## Workflow
1. **Determine Scope**:
   - If the user provided a diff or specific files, use those as the review target.
   - If no scope is provided:
     - Use the read-only `git` MCP tools (`mcp__git__git_diff`,
       `mcp__git__git_diff_staged`, `mcp__git__git_diff_unstaged`,
       `mcp__git__git_status`) to gather all pending changes.
     - Untracked files appear in `mcp__git__git_status`; read their contents
       with `read` and include them in the review material.
     - If the `git` MCP tools are unavailable or fail, state the gap and ask
       the user to provide the diff.

2. **Delegate to Reviewer**:
   - Launch the reviewer with the `subagent` tool:
     `subagent({ agent: "reviewer", task: "<brief>" })`
   - The brief must state: goal (review only, never edit); the review target
     (the diff itself, or the file list + refs to gather it with); that the
     review rubric lives at `~/.config/pi/skills/review/review-rubric.md` and
     must be read and followed strictly; the repo root (`cwd`) the change
     belongs to; and that output is the findings report described below.
   - The launch is async by default: do not poll. Keep doing safe independent
     work or end the turn; the completion wakes this session.

3. **Synthesize**:
   - When the reviewer returns, report its findings to the user clearly and
     concisely, preserving severity ordering and file/line citations.

## Constraints
- **Review Only**: Do NOT modify any files. Do not apply fixes or suggestions
  directly. (Works in read mode too — the reviewer stays read-only.)
- **Evidence**: Always cite the specific file path and line number for any
  finding.
- **Cold context**: Do not paste the implementation conversation into the
  brief — only the diff, the rubric path, and the target description. The
  reviewer must judge the change without the builder's framing.
- **Cost policy**: The reviewer agent's model is pinned in settings
  (`moonshotai/kimi-k2.7-code`). Never override it with a frontier model
  unless the user explicitly requests it; the `modelScope` setting will
  reject the launch anyway.
