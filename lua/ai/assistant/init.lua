local Providers = require('ai.providers')
local Config = require('ai.config')
local Http = require('ai.http')
local M = {}

M.llm = function(system_prompt, prompt, on_chunk, on_complete)
    local provider = Config.config.provider
    local p = Providers.get(provider)
    Http.stream(system_prompt, prompt, on_chunk, on_complete)
end

return M
