local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}

M.API_KEY = "GROQ_API_KEY"

function M.has()
  return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil
end

function M.parse_response(data_stream, _, opts)
  if data_stream == nil or data_stream == "" then
    return
  end
  local data_match = data_stream:match("^data: (.+)$")
  if data_match == '[DONE]' then
    opts.on_complete(nil)
  else
    local json = vim.json.decode(data_match)
    if json.choices and #json.choices > 0 then
      local content = json.choices[1].delta.content or ''
      opts.on_chunk(content)
    end
  end
end

function M.parse_curl_args(provider, code_opts)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. os.getenv(M.API_KEY),
  }

  local messages = {
    {
      role = "system",
      content = code_opts.system_prompt
    },
    {
      role = "user",
      content = code_opts.base_prompt
    }
  }

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/openai/v1/chat/completions",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      messages = messages,
      model = base.model or "llama3-8b-8192",
      temperature = base.temperature or 1,
      max_tokens = base.max_tokens or 1024,
      top_p = 1,
      stream = true,
    }, body_opts),
  }
end

return M

