---
name: review
description: >
  Conduct a structured code review. Launches a dedicated subagent to analyze
  the current uncommitted changes or a user-provided diff, and reports findings
  without applying fixes. Manually invoked only.
user-invocable: true
disable-model-invocation: true
---

# Review

Purpose: Provide a rigorous, expert-level code review of uncommitted changes
or a specific user-provided diff, using a dedicated subagent.

## Scope
- **Default**: Review all uncommitted changes (staged + unstaged + untracked) in the repository.
- **Provided Diff**: If the user includes a diff, commit hash range, or file list in the message, review that instead.

## Workflow
1. **Determine Scope**:
   - If the user provided a diff or specific files, use those as the review target.
   - If no scope is provided:
     - Use `git` MCP tools (e.g., `git_diff_unstaged`, `git_diff_staged`, `git_status`) to gather all pending changes.
     - Untracked files appear in `git_status`; read their contents with `view` and include them in the review material.
     - If `git` MCP tools are unavailable or fail, state the gap and ask the user to provide the diff.

2. **Delegate to Subagent**:
   - Use the `task` tool to launch a subagent.
   - Provide the subagent with:
     - The role: "You are an Expert Software Architect and Senior Code Reviewer."
     - The review rubric: Instruct the subagent to load `review-rubric.md` from this skills directory and follow it strictly.
     - The target code: The diff or file list.

3. **Synthesize**:
   - Wait for the subagent to return its findings.
   - Report the findings to the user clearly and concisely.

## Constraints
- **Review Only**: Do NOT modify any files. Do not apply fixes or suggestions directly.
- **Evidence**: Always cite the specific file path and line number for any finding.
