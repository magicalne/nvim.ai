local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}


M.has = function()
  return false
end

M.parse_message = function(opts)
  local user_prompt = opts.base_prompt

  return {
    { role = "system", content = opts.system_prompt },
    { role = "user", content = user_prompt },
  }
end

M.parse_response = function(data_stream, _, opts)
  if data_stream:match('"%[done%]":') then
    opts.on_complete(nil)
    return
  else
    local json = vim.json.decode(data_stream)
    opts.on_chunk(json.response)
  end
end

M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
  }
  if not P.env.is_local("ollama") then
    headers["Authorization"] = "Bearer " .. os.getenv(M.API_KEY)
  end

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/api/chat",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      model = base.model,
      messages = M.parse_message(code_opts),
      stream = true,
    }, body_opts),
  }
end

return M


