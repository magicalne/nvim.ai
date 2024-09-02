local Utils = require("ai.utils")
local Config = require("ai.config")
local ChatDialog = require("ai.chat_dialog")
local P = require("ai.providers")

local M = {}

M.API_KEY = "CO_API_KEY"

M.has = function()
  return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil
end

M.parse_response = function(data_stream, _, on_chunk)
  local json = vim.json.decode(data_stream)
  -- {"is_finished":false,"event_type":"text-generation","text":" person"}
  if json.is_finished then
    --opts.on_complete(nil)
    return
  else
    if json.text ~= nil then
      on_chunk(json.text)
    end
  end
end

local function divide_table(t)
  local last_element = t[#t]
  local rest_of_table = {}

  for i = 1, #t - 1 do
    rest_of_table[i] = t[i]
  end

  return rest_of_table, last_element
end
M.parse_curl_args = function(provider, request)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "bearer " .. os.getenv(M.API_KEY),
  }

  local messages = {}
  for i = 1, #request.messages - 1 do
    local message = request.messages[i]
    if message.role == ChatDialog.ROLE_USER then
      table.insert(messages, { role = "USER", message = message.content })
    elseif message.role == ChatDialog.ROLE_ASSISTANT then
      table.insert(messages, { role = "CHATBOT", message = message.content })
    end
  end
  local prompt = request.messages[#request.messages].content

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/chat",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      model = base.model,
      message = prompt,
      premble = {
        role = "SYSTEM",
        message = request.system_prompt
      },
      chat_history = messages,
      stream = true,
      max_tokens = base.max_tokens or 4096,
      temperature = base.temperature or 0.7,
    }, body_opts),
  }
end

return M
