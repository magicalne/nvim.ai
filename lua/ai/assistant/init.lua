local Providers = require('ai.providers')
local Config = require('ai.config')
local Http = require('ai.http')
local M = {}

M.llm = function(prompt, on_chunk, on_complete)
  local provider = Config.config.provider
  print('provider:', provider)
  local p = Providers.get(provider)
  Http.stream(prompt, on_chunk, on_complete)
end

return M
