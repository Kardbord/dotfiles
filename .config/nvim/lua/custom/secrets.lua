local M = {}

---Retrieve a secret from passage, returning nil on failure.
---@param key string The passage store path (e.g. "openrouter/api-key")
---@return string|nil
function M.from_pass(key)
  local handle = io.popen(('passage show %q'):format(key))
  if not handle then
    return nil
  end
  local value = handle:read '*l'
  handle:close()
  return value
end

return M
