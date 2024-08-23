local Providers = require('ai.providers')
local Config = require('ai.config')
local Http = require('ai.http')
local Assist = require('ai.assistant.assist')
local M = {}

M.ask = function(system_prompt, raw_prompt, on_chunk, on_complete)
  local provider = Config.config.provider
  local p = Providers.get(provider)
  local prompt = Assist.parse_prompt(raw_prompt, nil, true)
  Http.stream(system_prompt, prompt, on_chunk, on_complete)
end

return M
