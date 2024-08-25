local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}

M.API_KEY = "CO_API_KEY"

M.has = function()
  return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil
end

M.parse_response = function(data_stream, _, opts)
  local json = vim.json.decode(data_stream)
  -- {"is_finished":false,"event_type":"text-generation","text":" person"}
  if json.is_finished then
    opts.on_complete(nil)
    return
  else
    if json.text ~= nil then
      opts.on_chunk(json.text)
    end
  end
end

M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "bearer " .. os.getenv(M.API_KEY),
  }

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/chat",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      model = base.model,
      message = code_opts.base_prompt,
      premble = {
        role = "SYSTEM",
        message = code_opts.system_prompt
      },
      stream = true,
      max_tokens = base.max_tokens or 4096,
      temperature = base.temperature or 0.7,
    }, body_opts),
  }
end

return M
