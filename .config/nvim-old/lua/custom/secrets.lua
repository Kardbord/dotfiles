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

---Verify a file's SHA256 hash against an expected value.
---@param filepath string
---@param expected_sha256 string
---@return boolean
function M.verify_hash(filepath, expected_sha256)
  local handle = io.popen(('sha256sum %q'):format(filepath))
  if not handle then
    return false
  end
  local result = handle:read '*l'
  handle:close()
  if not result then
    return false
  end
  local actual = result:match('%S+')
  return actual == expected_sha256
end

return M
