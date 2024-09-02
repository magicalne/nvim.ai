local Utils = require("ai.utils")
local Config = require("ai.config")
local ChatDialog = require("ai.chat_dialog")
local P = require("ai.providers")

local M = {}

M.API_KEY = "GOOGLE_API_KEY"

function M.has()
  return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil
end

function M.parse_response(data_stream, _, on_chunk)
  if data_stream == nil or data_stream == "" then
    return
  end
  local data_match = data_stream:match("^data: (.+)$")
  local json = vim.json.decode(data_match)
  if json.candidates and #json.candidates > 0 then
    for _, candidate in pairs(json.candidates) do
      if candidate.content.parts and #candidate.content.parts > 0 then
        for _, part in ipairs(candidate.content.parts) do
          if part.text ~= nil then
            on_chunk(part.text)
          end
        end
      end
    end

  end

end

function M.parse_curl_args(provider, request)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
  }
  local contents = {}
  for _, message in ipairs(request.messages) do
    local m
    if message.role == ChatDialog.ROLE_USER then
      m = {
        role = "user",
        parts = {{
          text = message.content
        }}
      }
    elseif message.role == ChatDialog.ROLE_ASSISTANT then
      m = {
        role = "model",
        parts = {{
          text = message.content
        }}
      }
    table.insert(contents, m)
    end
  end

  local system_instruction = {
    parts = {
      text = request.system_prompt
    }
  }

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1beta/models/".. base.model ..":streamGenerateContent?alt=sse&key=" .. os.getenv(M.API_KEY),
    no_buffer = true,
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    raw = { "--no-buffer" },
    body = {
      system_instruction = system_instruction,
      contents = contents,
      generation_config = {
        temperature = base.temperature or 0,
        max_output_tokens = base.max_tokens or 1024,
        top_p = base.top_p or 1,
      }
    }
  }
end

return M


