local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local M = {}

M.API_KEY = "OPENAI_API_KEY"

M.has = function()
  return os.getenv(M.API_KEY) and true or false
end

M.parse_message = function(opts)
  local user_prompt = opts.base_prompt

  return {
    { role = "system", content = opts.system_prompt },
    { role = "user",   content = opts.base_prompt },
  }
end

M.parse_response = function (data_stream, _, opts)
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

M.parse_curl_args = function(provider, request)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. os.getenv(M.API_KEY),
  }

  local messages = {
    {
      role = "system",
      content = request.system_prompt
    },
  }
  for _, message in ipairs(request.messages) do
    table.insert(messages, message)
  end

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/chat/completions",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      model = base.model,
      messages = messages,
      stream = true,
    }, body_opts),
  }
end

return M
