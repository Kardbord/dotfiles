local M = {}

local home = os.getenv 'HOME' or ''

---Additional sensitive paths to hide via tmpfs overlay.
---Only existing directories are hidden; missing ones are silently skipped.
M.hidden_paths = {
  home .. '/.ssh',
  home .. '/.gnupg',
  os.getenv 'PASSAGE_DIR' or (home .. '/.passage'),
}

---@return boolean
local function has_bwrap()
  return vim.fn.executable 'bwrap' == 1
end

---Build bwrap args (everything between 'bwrap' and '--').
---The root fs is read-only; HOME and /tmp are writable.
---Sensitive paths are overlaid with empty tmpfs.
---@param network boolean Whether to allow network access (omit --unshare-net)
---@return table
local function bwrap_prefix(network)
  local args = {
    '--ro-bind',
    '/',
    '/',
    '--dev',
    '/dev',
    '--proc',
    '/proc',
    '--bind',
    '/tmp',
    '/tmp',
    '--bind',
    home,
    home,
  }

  if not network then
    args[#args + 1] = '--unshare-net'
  end

  for _, path in ipairs(M.hidden_paths) do
    if vim.fn.isdirectory(path) == 1 then
      args[#args + 1] = '--tmpfs'
      args[#args + 1] = path
    end
  end

  return args
end

---Wrap a command in a bwrap sandbox with network isolation.
---Returns (command, args) suitable for avante's acp_providers config.
---Falls back to the unwrapped command if bwrap is unavailable.
---@param cmd string The executable to sandbox (e.g. "npx")
---@param ... string Static args to pass through
---@return string command, table args
function M.sandbox(cmd, ...)
  if not has_bwrap() then
    vim.notify('[secrets] bwrap not found, running unsandboxed: ' .. cmd, vim.log.levels.WARN)
    return cmd, { ... }
  end

  local args = bwrap_prefix(false)
  args[#args + 1] = '--'
  args[#args + 1] = cmd
  for i = 1, select('#', ...) do
    args[#args + 1] = select(i, ...)
  end

  return 'bwrap', args
end

---Wrap a command in a bwrap sandbox with network access enabled.
---Same as sandbox() but without --unshare-net.
---@param cmd string The executable to sandbox (e.g. "npm")
---@param ... string Static args to pass through
---@return string command, table args
function M.sandbox_net(cmd, ...)
  if not has_bwrap() then
    vim.notify('[secrets] bwrap not found, running unsandboxed: ' .. cmd, vim.log.levels.WARN)
    return cmd, { ... }
  end

  local args = bwrap_prefix(true)
  args[#args + 1] = '--'
  args[#args + 1] = cmd
  for i = 1, select('#', ...) do
    args[#args + 1] = select(i, ...)
  end

  return 'bwrap', args
end

---Create a sandboxed build function for lazy.nvim plugin build commands.
---Captures cwd at call time (lazy.nvim cd's to the plugin dir before building).
---Network is enabled for registry access during builds.
---Falls back to unsandboxed execution if bwrap is unavailable.
---@param cmd string The build command (e.g. "make", "npm")
---@param ... string Additional args (e.g. "install")
---@return function build_fn Suitable for lazy.nvim `build` option
function M.build(cmd, ...)
  local extra = { ... }

  return function()
    local cwd = vim.fn.getcwd()

    if not has_bwrap() then
      vim.notify('[secrets] bwrap not found, running unsandboxed: ' .. cmd, vim.log.levels.WARN)
      local result = vim.system(vim.list_extend({ cmd }, extra), { cwd = cwd }):wait()
      if result.code ~= 0 then
        vim.notify('Build failed (' .. result.code .. '): ' .. (result.stderr or ''), vim.log.levels.ERROR)
      end
      return
    end

    local args = { 'bwrap' }
    vim.list_extend(args, bwrap_prefix(true))
    args[#args + 1] = '--'
    args[#args + 1] = cmd
    vim.list_extend(args, extra)

    local result = vim.system(args, { cwd = cwd }):wait()
    if result.code ~= 0 then
      vim.notify('Build failed (' .. result.code .. '): ' .. (result.stderr or ''), vim.log.levels.ERROR)
    end
  end
end

return M