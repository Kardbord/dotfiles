-- Lazy-loaded avante module references (populated when tools are first used)
local Utils, Helpers, Base, Config, Providers, Path

--- Ensure all avante modules are loaded before use
local function ensure_modules()
  if not Path then
    Path = require 'plenary.path'
  end
  if not Utils then
    Utils = require 'avante.utils'
  end
  if not Helpers then
    Helpers = require 'avante.llm_tools.helpers'
  end
  if not Base then
    Base = require 'avante.llm_tools.base'
  end
  if not Config then
    Config = require 'avante.config'
  end
  if not Providers then
    Providers = require 'avante.providers'
  end
end

-- ============================================================
-- Custom git tool (only whitelisted subcommands)
-- ============================================================
local GitTool = {}
GitTool.name = 'git'

-- Whitelist of allowed git subcommands
local ALLOWED_SUBCOMMANDS_LIST = {
  'add',
  'annotate',
  'blame',
  'branch',
  'checkout',
  'cherry-pick',
  'commit',
  'describe',
  'diff',
  'diff-index',
  'fetch',
  'log',
  'ls-files',
  'merge',
  'name-rev',
  'pull',
  'rebase', -- allowed but we block dangerous flags
  'reset',
  'rev-list',
  'rev-parse',
  'shortlog',
  'show',
  'stash',
  'status',
  'switch',
  'tag',
}

local ALLOWED_SUBCOMMANDS = {}
for _, cmd in ipairs(ALLOWED_SUBCOMMANDS_LIST) do
  ALLOWED_SUBCOMMANDS[cmd] = true
end

GitTool.get_description = function()
  local allowed_str = table.concat(ALLOWED_SUBCOMMANDS_LIST, ', ')

  return ([[Executes git commands for version control operations.
This tool ONLY allows whitelisted git subcommands and flags for safety.

Allowed subcommands: ${ALLOWED_SUBCOMMANDS}

Security restrictions:
1. NEVER use 'git push' - pushing to remote is not allowed
2. NEVER use force flags (-f, --force, --force-with-lease)
3. NEVER use 'git clean' or 'git gc'
4. NEVER use interactive rebase (-i) or --exec
5. Commands that contact remote without explicit need are discouraged

When using git commands, follow these best practices:

# Viewing changes (diff)

Use \`git diff\` to view unstaged changes:

<example>

git diff

</example>

Use \`git diff --staged\` to view staged changes:

<example>

git diff --staged

</example>

Use \`git diff main...HEAD\` to see commits since diverging from main:

<example>

git diff main...HEAD

</example>

# Committing changes

When the user asks you to create a new git commit, follow these steps carefully:

1. Start with a single message that contains exactly three tool_use blocks that do the following (it is VERY IMPORTANT that you send these tool_use blocks in a single message, otherwise it will feel slow to the user!):

 - Run a git status command to see all untracked files.
 - Run a git diff command to see both staged and unstaged changes that will be committed.
 - Run a git log command to see recent commit messages, so that you can follow this repository's commit message style.

2. Use the git context at the start of this conversation to determine which files are relevant to your commit. Add relevant untracked files to the staging area. Do not commit files that were already modified at the start of this conversation, if they are not relevant to your commit.

3. Analyze all staged changes (both previously staged and newly added) and draft a commit message. Wrap your analysis process in <commit_analysis> tags:

<commit_analysis>

\- List the files that have been changed or added
\- Summarize the nature of the changes (eg. new feature, enhancement to an existing feature, bug fix, refactoring, test, docs, etc.)
\- Brainstorm the purpose or motivation behind these changes
\- Do not use tools to explore code, beyond what is available in the git context
\- Assess the impact of these changes on the overall project
\- Check for any sensitive information that shouldn't be committed
\- Draft a concise (1-2 sentences) commit message that focuses on the "why" rather than the "what"
\- Ensure your language is clear, concise, and to the point
\- Ensure the message accurately reflects the changes and their purpose (i.e. "add" means a wholly new feature, "update" means an enhancement to an existing feature, "fix" means a bug fix, etc.)
\- Ensure the message is not generic (avoid words like "Update" or "Fix" without context)
\- Review the draft message to ensure it accurately reflects the changes and their purpose

</commit_analysis>

4. If the commit fails due to pre-commit hook changes, retry the commit ONCE to include these automated changes. If it fails again, it usually means a pre-commit hook is preventing the commit. If the commit succeeds but you notice that files were modified by the pre-commit hook, you MUST amend your commit to include them.

5. Finally, run git status to make sure the commit succeeded.

Important notes:

\- When possible, combine the "git add" and "git commit" commands into a single "git commit -am" command, to speed things up
\- However, be careful not to stage files (e.g. with \`git add .\`) for commits that aren't part of the change, they may have untracked files they want to keep around, but not commit.
\- NEVER update the git config
\- NEVER push to the remote repository
\- IMPORTANT: Never use git commands with the -i flag (like git rebase -i or git add -i) since they require interactive input which is not supported.
\- If there are no changes to commit (i.e., no untracked files and no modifications), do not create an empty commit
\- Ensure your commit message is meaningful and concise. It should explain the purpose of the changes, not just describe them.
\- Return an empty response - the user will see the git output directly

Note: Pull requests should not be created through git commands. Use the appropriate workflow for your project.]]):gsub('${ALLOWED_SUBCOMMANDS}', allowed_str)
end

GitTool.param = {
  type = 'table',
  fields = {
    {
      name = 'path',
      description = 'Relative path to the project directory, as cwd',
      type = 'string',
    },
    {
      name = 'command',
      description = "Git command to run (subcommand + flags, e.g., 'diff', 'commit -m \"message\"', 'add .')",
      type = 'string',
    },
    {
      name = 'timeout',
      description = 'Timeout in milliseconds (optional, up to 600000ms / 10 minutes)',
      type = 'integer',
      optional = true,
    },
  },
  usage = {
    path = 'Relative path to the project directory, as cwd',
    command = "Git command to run (e.g., 'diff', 'status', 'add .', 'commit -m \"message\"')",
    timeout = 'Optional timeout in milliseconds (max 600000)',
  },
}

GitTool.returns = {
  {
    name = 'stdout',
    description = 'Output of the git command',
    type = 'string',
  },
  {
    name = 'error',
    description = 'Error message if the command was not run successfully',
    type = 'string',
    optional = true,
  },
}

--- Parse git command to extract subcommand and remaining arguments.
---@param command string
---@return string, string Returns subcommand and the rest of arguments
local function parse_git_command(command)
  local parts = {}
  for part in command:gmatch '%S+' do
    table.insert(parts, part)
  end

  if #parts == 0 then
    return '', ''
  end

  -- Handle 'git' prefix (strip it if present)
  local start_idx = 1
  if parts[1] == 'git' then
    start_idx = 2
  end

  if start_idx > #parts then
    return '', ''
  end

  local subcommand = parts[start_idx]
  local args = table.concat(vim.list_slice(parts, start_idx + 1), ' ')

  return subcommand, args
end

--- Check if a flag appears as a standalone argument in an args string.
--- Handles flags at the start, end, and middle of the args string.
---@param args string
---@param flag string The flag to look for (e.g. "--force", "-f")
---@return boolean
local function has_flag(args, flag)
  local escaped = flag:gsub('%-', '%%-')
  return args == flag or args:match('^' .. escaped .. '%s') ~= nil or args:match('%s' .. escaped .. '$') ~= nil or args:match('%s' .. escaped .. '%s') ~= nil
end

--- Check if a git command contains dangerous flags.
---@param subcommand string The git subcommand (e.g., "branch", "tag", "switch")
---@param args string
---@return boolean, string|nil Returns true if dangerous, and description of the danger
local function check_dangerous_flags(subcommand, args)
  -- Force flags (-f, --force, --force-with-lease)
  if has_flag(args, '-f') or has_flag(args, '--force') or has_flag(args, '--force-with-lease') then
    return true, 'Force flags (-f, --force, --force-with-lease) are not allowed'
  end

  -- Force delete for branch -D (force-delete branch, equivalent to --delete --force)
  if subcommand == 'branch' and has_flag(args, '-D') then
    return true, '-D flag for branch is not allowed (force-deletes a branch)'
  end

  -- Force delete for tag -d (delete tag) and -D (force-delete tag)
  if subcommand == 'tag' and (has_flag(args, '-d') or has_flag(args, '-D')) then
    return true, 'tag delete flags (-d, -D) are not allowed'
  end

  -- --no-verify (skips hooks)
  if has_flag(args, '--no-verify') then
    return true, '--no-verify flag is not allowed'
  end

  -- --hard (destructive: destroys uncommitted changes)
  if has_flag(args, '--hard') then
    return true, '--hard flag is not allowed (would destroy uncommitted changes)'
  end

  -- Interactive mode: -i (short) or --interactive (long)
  if has_flag(args, '-i') or has_flag(args, '--interactive') then
    return true, 'Interactive mode (-i, --interactive) is not allowed'
  end

  -- --exec in rebase (executes arbitrary shell commands per commit)
  if has_flag(args, '--exec') then
    return true, '--exec flag in rebase is not allowed'
  end

  -- --onto in rebase (complex history rewriting)
  if has_flag(args, '--onto') then
    return true, '--onto in rebase requires explicit approval'
  end

  -- --autosquash (rewrites history)
  if has_flag(args, '--autosquash') then
    return true, '--autosquash is not allowed'
  end

  -- --discard-changes / --discard for switch (discards working tree changes)
  if subcommand == 'switch' and (has_flag(args, '--discard-changes') or has_flag(args, '--discard')) then
    return true, '--discard-changes / --discard for switch is not allowed (would discard working tree changes)'
  end

  return false, nil
end

GitTool.func = function(input, opts)
  ensure_modules()
  local is_streaming = opts.streaming or false
  if is_streaming then
    return
  end

  local abs_path = Helpers.get_abs_path(input.path)
  if not Helpers.has_permission_to_access(abs_path) then
    return false, 'No permission to access path: ' .. abs_path
  end
  if not Path:new(abs_path):exists() then
    return false, 'Path not found: ' .. abs_path
  end
  if not input.command then
    return false, 'Git command is required'
  end

  local subcommand, args = parse_git_command(input.command)

  if subcommand == '' then
    return false, 'Invalid git command: no subcommand specified'
  end

  -- Check if subcommand is whitelisted
  if not ALLOWED_SUBCOMMANDS[subcommand] then
    return false, "Git subcommand '" .. subcommand .. "' is not allowed. " .. 'Allowed subcommands: ' .. table.concat(ALLOWED_SUBCOMMANDS_LIST, ', ')
  end

  -- Check for dangerous flags
  local is_dangerous, danger_msg = check_dangerous_flags(subcommand, args)
  if is_dangerous then
    return false, danger_msg
  end

  -- Build the full git command
  local full_command = 'git ' .. subcommand .. (args ~= '' and ' ' .. args or '')

  if opts.on_log then
    opts.on_log('git command: ' .. full_command)
  end

  local function handle_result(output, exit_code)
    if exit_code ~= 0 then
      if output then
        return false, 'Error: ' .. output .. '; Error code: ' .. tostring(exit_code)
      end
      return false, 'Error code: ' .. tostring(exit_code)
    end
    return output, nil
  end

  if not opts.on_complete then
    return false, 'on_complete not provided'
  end

  -- Clamp timeout to the allowed maximum (600000ms / 10 minutes)
  local timeout_ms = math.min(input.timeout or 600000, 600000)

  -- Read-only commands that are safe to run without confirmation.
  -- Note: branch is excluded because it can also create/delete branches.
  -- Note: fetch is excluded because it contacts a remote server.
  local read_only_commands = {
    diff = true,
    log = true,
    status = true,
    show = true,
    ['ls-files'] = true,
    ['diff-index'] = true,
    ['rev-parse'] = true,
    ['rev-list'] = true,
    ['name-rev'] = true,
    describe = true,
    shortlog = true,
    blame = true,
    annotate = true,
  }

  if read_only_commands[subcommand] then
    -- Read-only commands run without a confirmation prompt
    Utils.shell_run_async(full_command, 'bash -c', function(output, exit_code)
      local result, err = handle_result(output, exit_code)
      opts.on_complete(result, err)
    end, abs_path, timeout_ms)
  else
    -- Modifying commands (commit, add, reset, stash, branch, fetch, etc.) need confirmation
    local confirm_msg
    if subcommand == 'fetch' or subcommand == 'pull' then
      confirm_msg = 'Are you sure you want to run: `' .. full_command .. '` (this will contact the remote repository)?'
    else
      confirm_msg = 'Are you sure you want to run: `' .. full_command .. '` in the directory: ' .. abs_path
    end

    Helpers.confirm(confirm_msg, function(confirmed, reason)
      if not confirmed then
        opts.on_complete(false, 'User declined, reason: ' .. (reason and reason or 'unknown'))
        return
      end

      Utils.shell_run_async(full_command, 'bash -c', function(output, exit_code)
        local result, err = handle_result(output, exit_code)
        opts.on_complete(result, err)
      end, abs_path, timeout_ms)
    end, { focus = true }, opts.session_ctx, GitTool.name)
  end
end

return GitTool
