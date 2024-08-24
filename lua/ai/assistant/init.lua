local Providers = require('ai.providers')
local Config = require('ai.config')
local Http = require('ai.http')
local Assist = require('ai.assistant.assist')
local Prompts = require('ai.assistant.prompts')
local M = {}

M.ask = function(system_prompt, raw_prompt, on_chunk, on_complete)
  if system_prompt == nil then
    local system_prompt = Prompts.GLOBAL_SYSTEM_PROMPT
  end
  local provider = Config.config.provider
  local p = Providers.get(provider)
  local prompt = Assist.parse_chat_prompt(raw_prompt)
  Http.stream(system_prompt, prompt, on_chunk, on_complete)
end

return M
