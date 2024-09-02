local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}


M.has = function()
    return false
end

M.parse_message = function(request)
  local messages = {
    { role = "system", content = request.system_prompt },
  }

  for _, message in ipairs(request.messages) do
    table.insert(messages, message)
  end
  return messages
end

M.parse_response = function(data_stream, _, on_chunk)
    local json = vim.json.decode(data_stream)
    if json.done then
        --opts.on_complete(nil)
        return
    else
        on_chunk(json.message.content)
    end
end

M.parse_curl_args = function(provider, request)
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
            messages = M.parse_message(request),
            stream = true,
        }, body_opts),
    }
end

return M
