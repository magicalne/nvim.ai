local api = vim.api

local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local curl = require("plenary.curl")

local M = {}

M.CANCEL_PATTERN = "NVIMAIHTTPEscape"

------------------------------Prompt and type------------------------------

local group = api.nvim_create_augroup("NVIMAIHTTP", { clear = true })
local active_job = nil

M.stream = function(system_prompt, prompt, on_chunk, on_complete)
  local provider = Config.config.provider
  local code_opts = {
    base_prompt = prompt,
    system_prompt = system_prompt,
  }

  ---@type string
  local current_event_state = nil

  local Provider = P[provider]

  local handler_opts = { on_chunk = on_chunk, on_complete = on_complete }
  local spec = Provider.parse_curl_args(Config.get_provider(provider), code_opts)

  ---@param line string
  local function parse_stream_data(line)
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
      print('http error', vim.inspect(err))
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
        Utils.debug("LLM request cancelled", { title = "NVIM.AI" })
        active_job = nil
      end
    end,
  })

  return active_job
end

return M
