local Config = require("ai.config")
local ChatDialog = require("ai.chat_dialog")
local Providers = require("ai.providers")

local M = {}
--
-- Setup function to initialize the plugin
M.setup = function(opts)
  Config.setup(opts)
  -- Load the plugin's configuration
  -- init chat dialog
  ChatDialog:setup()
  Providers.setup()
  -- Initialize the plugin's functionality here
  -- For example:
  --vim.cmd("command! MyPluginCommand :call my_plugin.my_function()")

  -- Set up key mappings or other plugin-specific configurations
  --vim.keymap.set("n", "<leader>c", ":MyPluginCommand<CR>")

end

return M
