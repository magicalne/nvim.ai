local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}

M.API_KEY = "ANTHROPIC_API_KEY"

M.has = function() return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil end

M.parse_message = function(opts)
  local user_prompt = opts.base_prompt

  return {
    { role = "user", content = user_prompt },
  }
end

M.parse_response = function(data_stream, _, on_chunk)
  if data_stream == nil or data_stream == "" then return end
  local data_match = data_stream:match("^data: (.+)$")
  if data_match ~= nil then
    local json = vim.json.decode(data_match)
    if json.type == "content_block_delta" then
      on_chunk(json.delta.text)
      --elseif json.type == 'message_stop' then
      --  opts.on_complete(nil)
    end
  end
end

M.parse_curl_args = function(provider, request)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
    ["x-api-key"] = os.getenv(M.API_KEY),
    ["anthropic-version"] = "2023-06-01",
  }

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/messages",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      model = base.model,
      system = request.system_prompt,
      messages = request.messages,
      stream = true,
      max_tokens = base.max_tokens or 4096,
      temperature = base.temperature or 0.7,
    }, body_opts),
  }
end

return M
