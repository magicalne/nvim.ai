local Config = require("ai.config")
local ChatDialog = require("ai.chat_dialog")
local Providers = require("ai.providers")
local CmpSource = require("ai.cmp_source")
local cmp = require('cmp')

local M = {}
-- New function to set up keymaps
M.setup_keymaps = function()
  -- Register the custom source
  cmp.register_source('nvimai_cmp_source', CmpSource.new())
  -- Global keymaps
  vim.keymap.set("n", "<leader>ct", ChatDialog.toggle, { noremap = true, silent = true })
  -- Buffer-specific keymaps for ChatDialog
  local function set_chat_dialog_keymaps()
    local opts = { noremap = true, silent = true, buffer = true }
    vim.keymap.set('n', 'q', ChatDialog.close, opts)
    vim.keymap.set("n", "<CR>", ChatDialog.send, opts)
  end

  -- Create an autocommand to set ChatDialog keymaps when entering the chat-dialog buffer
  vim.api.nvim_create_autocmd("FileType", {
    pattern = Config.FLIE_TYPE,
    callback = set_chat_dialog_keymaps
  })
  -- automatically setup Avante filetype to markdown
  vim.treesitter.language.register("markdown", Config.FLIE_TYPE)
end

-- Setup function to initialize the plugin
M.setup = function(opts)
  Config.setup(opts)
  print('prompt', Config.CONTENT_PROMPT)
  -- Load the plugin's configuration
  -- init chat dialog
  ChatDialog:setup()
  Providers.setup()

  M.setup_keymaps()
end

return M
