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

M.parse_response = function(data_stream, _, opts)
  if data_stream:match('"%[DONE%]":') then
    opts.on_complete(nil)
    return
  end
  if data_stream:match('"delta":') then
    ---@type OpenAIChatResponse
    local json = vim.json.decode(data_stream)
    if json.choices and json.choices[1] then
      local choice = json.choices[1]
      if choice.finish_reason == "stop" then
        opts.on_complete(nil)
      elseif choice.delta.content then
        opts.on_chunk(choice.delta.content)
      end
    end
  end
end

M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
  }
  if not P.env.is_local("openai") then
    headers["Authorization"] = "Bearer " .. os.getenv(M.API_KEY)
  end

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/chat/completions",
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
