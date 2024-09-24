-- https://inference-docs.cerebras.ai/introduction
local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local OpenAI = require("ai.providers.openai")

local M = {}

M.API_KEY = "CEREBRAS_API_KEY"

function M.has() return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil end

function M.parse_response(data_stream, data_event_state, on_chunk)
  return OpenAI.parse_response(data_stream, data_event_state, on_chunk)
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
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/chat/completions",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      messages = messages,
      model = base.model,
      temperature = base.temperature or 0.1,
      max_tokens = base.max_tokens or 4096,
      top_p = 1,
      stream = true,
    }, body_opts),
  }
end

return M
