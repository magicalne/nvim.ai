local api = vim.api

local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local curl = require("plenary.curl")

---@class avante.LLM
local M = {}

M.CANCEL_PATTERN = "NVIMAIHTTPEscape"

------------------------------Prompt and type------------------------------

---@alias AvanteSystemPrompt string
local system_prompt = [[
You are an excellent programming expert.
]]


local group = api.nvim_create_augroup("NVIMAIHTTP", { clear = true })
local active_job = nil

---@param question string
---@param code_lang string
---@param code_content string
---@param selected_content_content string | nil
---@param on_chunk AvanteChunkParser
---@param on_complete AvanteCompleteParser
M.stream = function(prompt, on_chunk, on_complete)
  local provider = Config.config.provider

  ---@type AvantePromptOptions
  local code_opts = {
    base_prompt = prompt,
    system_prompt = system_prompt,
  }

  ---@type string
  local current_event_state = nil

  ---@type AvanteProviderFunctor
  local Provider = P[provider]

  ---@type AvanteHandlerOptions
  local handler_opts = { on_chunk = on_chunk, on_complete = on_complete }
  ---@type AvanteCurlOutput
  local spec = Provider.parse_curl_args(Config.get_provider(provider), code_opts)

  ---@param line string
  local function parse_stream_data(line)
    print('line', line)
    local event = line:match("^event: (.+)$")
    if event then
      current_event_state = event
      return
    end
    -- local data_match = line:match("^data: (.+)$")
    Provider.parse_response(line, current_event_state, handler_opts)
  end

  if active_job then
    active_job:shutdown()
    active_job = nil
  end

  active_job = curl.post(spec.url, {
    headers = spec.headers,
    proxy = spec.proxy,
    insecure = spec.insecure,
    body = vim.json.encode(spec.body),
    stream = function(err, data, _)
      if err then
        on_complete(err)
        return
      end
      if not data then
        return
      end
      vim.schedule(function()
        if Config.config[provider] == nil and Provider.parse_stream_data ~= nil then
          print('data', data)
          if Provider.parse_response ~= nil then
            Utils.warn(
              "parse_stream_data and parse_response_data are mutually exclusive, and thus parse_response_data will be ignored. Make sure that you handle the incoming data correctly.",
              { once = true }
            )
          end
          Provider.parse_stream_data(data, handler_opts)
        else
          parse_stream_data(data)
        end
      end)
    end,
    on_error = function(err)
      on_complete(err)
    end,
    callback = function(_)
      active_job = nil
    end,
  })

  api.nvim_create_autocmd("User", {
    group = group,
    pattern = M.CANCEL_PATTERN,
    callback = function()
      if active_job then
        active_job:shutdown()
        Utils.debug("LLM request cancelled", { title = "Avante" })
        active_job = nil
      end
    end,
  })

  return active_job
end

return M

