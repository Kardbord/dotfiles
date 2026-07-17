local M = {}

---@return boolean
local function has_firejail()
  return vim.fn.executable 'firejail' == 1
end

---Detect WSL2 and set the container=lxc env var required by firejail.
---Called once at module load time.
local function detect_wsl()
  if vim.fn.has 'wsl' == 1 then
    vim.env.container = 'lxc'
    return true
  end
  return false
end

detect_wsl()

---Wrap a command in a firejail sandbox.
---Firejail auto-detects the appropriate profile based on the command name.
---Falls back to the unwrapped command if firejail is unavailable.
---@param cmd string The executable to sandbox (e.g. "npx")
---@param ... string Static args to pass through
---@return string command, table args
function M.sandbox(cmd, ...)
  if not has_firejail() then
    vim.notify('[sandbox] firejail not found, running unsandboxed: ' .. cmd, vim.log.levels.WARN)
    return cmd, { ... }
  end

  local args = { cmd }
  for i = 1, select('#', ...) do
    args[#args + 1] = select(i, ...)
  end

  return 'firejail', args
end

---Create a sandboxed build function for lazy.nvim plugin build commands.
---Captures cwd at call time (lazy.nvim cd's to the plugin dir before building).
---Falls back to unsandboxed execution if firejail is unavailable.
---@param cmd string The build command (e.g. "make", "npm")
---@param ... string Additional args (e.g. "install")
---@return function build_fn Suitable for lazy.nvim `build` option
function M.build(cmd, ...)
  local extra = { ... }

  return function()
    local cwd = vim.fn.getcwd()

    if not has_firejail() then
      vim.notify('[sandbox] firejail not found, running unsandboxed: ' .. cmd, vim.log.levels.WARN)
      local result = vim.system(vim.list_extend({ cmd }, extra), { cwd = cwd }):wait()
      if result.code ~= 0 then
        vim.notify('Build failed (' .. result.code .. '): ' .. (result.stderr or ''), vim.log.levels.ERROR)
      end
      return
    end

    local args = { 'firejail', cmd }
    vim.list_extend(args, extra)

    local result = vim.system(args, { cwd = cwd }):wait()
    if result.code ~= 0 then
      vim.notify('Build failed (' .. result.code .. '): ' .. (result.stderr or result.stdout), vim.log.levels.ERROR)
    end
  end
end

return M
