-- Reuse the banned commands from the upstream bash tool
-- Note: We try to get them from the upstream module, but fall back to the hardcoded list
local banned_commands = {
  'alias',
  'curl',
  'curlie',
  'wget',
  'axel',
  'aria2c',
  'nc',
  'telnet',
  'lynx',
  'w3m',
  'links',
  'httpie',
  'xh',
  'http-prompt',
  'chrome',
  'firefox',
  'safari',
}
local ok, upstream_bash = pcall(require, 'avante.llm_tools.bash')
---@diagnostic disable-next-line: undefined-field
if ok and upstream_bash and upstream_bash.banned_commands then
  ---@diagnostic disable-next-line: undefined-field
  banned_commands = upstream_bash.banned_commands
end

-- Additional commands banned by our custom bash tool
local custom_banned_commands = {
  'git', -- No git commands allowed in bash, use the git tool instead
  'gh', -- No GitHub CLI commands, use dedicated tools if needed
  'svn', -- No version control from bash
  'hg', -- No Mercurial from bash
  'cvs', -- No CVS from bash
}

-- Combine all banned commands
local all_banned_commands = vim.deepcopy(banned_commands)
vim.list_extend(all_banned_commands, custom_banned_commands)

-- Lazy-loaded avante module references (populated when tools are first used)
local Path, Utils, Helpers, Base, Config, Providers

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
-- Custom bash tool (bash_cmd)
-- ============================================================
local BashCmd
BashCmd = {
  name = 'bash_cmd',

  get_description = function()
    -- Lazy-load avante modules
    if not Config then
      Config = require 'avante.config'
    end
    if not Providers then
      Providers = require 'avante.providers'
    end
    -- See https://github.com/yetone/avante.nvim/pull/1700
    -- Guard against nil provider (e.g. for custom/openrouter providers)
    local provider = Providers[Config.provider]
    if Config.provider:match 'copilot' and provider and provider.model and provider.model:match 'gpt' then
      return [[Executes a given bash command in a persistent shell session with optional timeout, ensuring proper handling and security measures. Do not use bash command to read or modify files, or you will be fired!]]
    end

    local res = ([[Executes a given bash command in a persistent shell session with optional timeout, ensuring proper handling and security measures.
Do not use bash command to read or modify files, or you will be fired!

Before executing the command, please follow these steps:

1. Directory Verification:

 - If the command will create new directories or files, first use the LS tool to verify the parent directory exists and is the correct location

 - For example, before running "mkdir foo/bar", first use LS to check that "foo" exists and is the intended parent directory

2. Security Check:

 - For security and to limit the threat of a prompt injection attack, some commands are limited or banned. If you use a disallowed command, you will receive an error message explaining the restriction. Explain the error to the User.

 - Verify that the command is not one of the banned commands: ${BANNED_COMMANDS}.

 - IMPORTANT: Git commands are NOT allowed in bash. Use the git tool for all version control operations.

3. Command Execution:

 - After ensuring proper quoting, execute the command.

 - Capture the output of the command.

4. Output Processing:

 - If the output exceeds ${MAX_OUTPUT_LENGTH} characters, output will be truncated before being returned to you.

 - Prepare the output for display to the user.

5. Return Result:

 - Provide the processed output of the command.

 - If any errors occurred during execution, include those in the output.

Usage notes:

 - The command argument is required.

 - You can specify an optional timeout in milliseconds (up to 600000ms / 10 minutes). If not specified, commands will timeout after 10 minutes.

 - VERY IMPORTANT: You MUST avoid using search commands like \`find\` and \`grep\`. Instead use ${GrepTool.name}, ${GlobTool.name}, or ${AgentTool.name} to search. You MUST avoid read tools like \`cat\`, \`head\`, \`tail\`, and \`ls\`, and use ${FileReadTool.name} and ${LSTool.name} to read files.

 - When issuing multiple commands, use the ';' or '&&' operator to separate them. DO NOT use newlines (newlines are ok in quoted strings).

 - IMPORTANT: All commands share the same shell session. Shell state (environment variables, virtual environments, current directory, etc.) persist between commands. For example, if you set an environment variable as part of a command, the environment variable will persist for subsequent commands.

 - Try to maintain your current working directory throughout the session by using absolute paths and avoiding usage of \`cd\`. You may use \`cd\` if the User explicitly requests it.

 <good-example>

 pytest /foo/bar/tests

 </good-example>

 <bad-example>

 cd /foo/bar && pytest tests

 </bad-example>

Note: For all git operations (diff, commit, add, reset, status, log, stash, branch, checkout, switch, merge, pull, fetch, etc.), use the ${GitTool.name} tool instead of bash.]]):gsub(
      '${BANNED_COMMANDS}',
      table.concat(all_banned_commands, ', ')
    ):gsub('${MAX_OUTPUT_LENGTH}', '16384'):gsub('${GrepTool.name}', 'search_keyword'):gsub('${GlobTool.name}', 'glob'):gsub('${AgentTool.name}', 'agent'):gsub(
      '${FileReadTool.name}',
      'read_file'
    ):gsub('${LSTool.name}', 'ls'):gsub('${GitTool.name}', 'git')

    return res
  end,
}

---@type AvanteLLMToolParam
BashCmd.param = {
  type = 'table',
  fields = {
    {
      name = 'path',
      description = 'Relative path to the project directory, as cwd',
      type = 'string',
    },
    {
      name = 'command',
      description = 'Command to run',
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
    command = 'Command to run',
    timeout = 'Optional timeout in milliseconds (max 600000)',
  },
}

---@type AvanteLLMToolReturn[]
BashCmd.returns = {
  {
    name = 'stdout',
    description = 'Output of the command',
    type = 'string',
  },
  {
    name = 'error',
    description = 'Error message if the command was not run successfully',
    type = 'string',
    optional = true,
  },
}

--- Tokenize a command string, respecting single and double quotes.
---@param command string
---@return string[]
local function tokenize(command)
  local tokens = {}
  local i = 1
  while i <= #command do
    local c = command:sub(i, i)
    -- Skip whitespace
    if c:match '%s' then
      i = i + 1
    -- Single-quoted string
    elseif c == "'" then
      local close = command:find("'", i + 1)
      if close then
        table.insert(tokens, command:sub(i + 1, close - 1))
        i = close + 1
      else
        -- Unclosed quote; treat rest as token
        table.insert(tokens, command:sub(i + 1))
        break
      end
    -- Double-quoted string
    elseif c == '"' then
      local close = command:find('"', i + 1)
      if close then
        table.insert(tokens, command:sub(i + 1, close - 1))
        i = close + 1
      else
        table.insert(tokens, command:sub(i + 1))
        break
      end
    else
      -- Regular word: read until whitespace or quote
      local word_start = i
      while i <= #command do
        local nc = command:sub(i, i)
        if nc:match '%s' or nc == "'" or nc == '"' then
          break
        end
        i = i + 1
      end
      table.insert(tokens, command:sub(word_start, i - 1))
    end
  end
  return tokens
end

--- Check if a command contains any banned command.
--- Checks the first word of each sub-command (after &&, ||, ;, |, etc.).
---@param command string
---@return boolean, string|nil Returns true if banned, and the banned command if found
local function check_banned_command(command)
  if not command or command == '' then
    return false, nil
  end

  -- Tokenize the full command
  local tokens = tokenize(command)

  -- Build a set of banned commands for fast lookup
  local banned_set = {}
  for _, cmd in ipairs(all_banned_commands) do
    banned_set[cmd] = true
  end

  -- Separator tokens that start a new sub-command
  local separators = {
    ['&&'] = true,
    ['||'] = true,
    [';'] = true,
    ['|'] = true,
    ['&'] = true,
  }

  -- Check the first token
  if #tokens > 0 and banned_set[tokens[1]] then
    return true, tokens[1]
  end

  -- Walk through tokens looking for separators; the next non-separator token is a command
  for idx = 2, #tokens do
    if separators[tokens[idx]] then
      -- Look ahead for the next non-separator, non-whitespace token
      for j = idx + 1, #tokens do
        if not separators[tokens[j]] then
          if banned_set[tokens[j]] then
            return true, tokens[j]
          end
          break
        end
      end
    end
  end

  return false, nil
end

---@type AvanteLLMToolFunc<{ path: string, command: string }>
function BashCmd.func(input, opts)
  ensure_modules()
  local is_streaming = opts.streaming or false
  if is_streaming then
    -- wait for stream completion as command may not be complete yet
    return
  end

  local is_banned, cmd = check_banned_command(input.command)
  if is_banned then
    return false, 'Command is banned: ' .. cmd
  end

  local abs_path = Helpers.get_abs_path(input.path)
  if not Helpers.has_permission_to_access(abs_path) then
    return false, 'No permission to access path: ' .. abs_path
  end
  if not Path:new(abs_path):exists() then
    return false, 'Path not found: ' .. abs_path
  end
  if not input.command then
    return false, 'Command is required'
  end
  if opts.on_log then
    opts.on_log('command: ' .. input.command)
  end

  ---change cwd to abs_path
  ---@param output string
  ---@param exit_code integer
  ---@return string | boolean | nil result
  ---@return string | nil error
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
  Helpers.confirm(
    'Are you sure you want to run the command: `' .. input.command .. '` in the directory: ' .. abs_path,
    function(ok, reason)
      if not ok then
        opts.on_complete(false, 'User declined, reason: ' .. (reason and reason or 'unknown'))
        return
      end
      Utils.shell_run_async(input.command, 'bash -c', function(output, exit_code)
        local result, err = handle_result(output, exit_code)
        opts.on_complete(result, err)
      end, abs_path, 1000 * 60 * 2)
    end,
    { focus = true },
    opts.session_ctx,
    BashCmd.name -- Pass the tool name for permission checking
  )
end

return BashCmd
