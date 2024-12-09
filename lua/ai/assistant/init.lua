local Inline = require("ai.assistant.inline")
local M = {}

M.inline = function()
  vim.ui.input({ prompt = "Prompt:" }, function(input) Inline:new(input) end)
end

return M
