local Utils = require("ai.utils")
local P = require("ai.providers")

local M = {}

M.API_KEY = "DEEPSEEK_API_KEY"

function M.has() return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil end

function M.parse_response(data_stream, _, on_chunk)
  if data_stream == nil or data_stream == "" then return end
  local data_match = data_stream:match("^data: (.+)$")
  if data_match == "[DONE]" or data_match == nil then
    --opts.on_complete(nil)
  else
    local json = vim.json.decode(data_match)
    if json.choices and #json.choices > 0 then
      local content = json.choices[1].delta.content or ""
      on_chunk(content)
    end
  end
end

function M.parse_curl_args(provider, request)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. os.getenv(M.API_KEY),
  }

  local messages = {
    {
      role = "system",
      content = request.system_prompt,
    },
  }

  for _, message in ipairs(request.messages) do
    table.insert(messages, message)
  end

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/chat/completions",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      messages = messages,
      model = base.model,
      temperature = base.temperature or 1,
      max_tokens = base.max_tokens or 1024,
      top_p = 1,
      stream = true,
    }, body_opts),
  }
end

return M
