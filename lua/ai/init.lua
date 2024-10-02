local Config = require("ai.config")
local Assistant = require("ai.assistant")
local ChatDialog = require("ai.chat_dialog")
local Providers = require("ai.providers")

local M = {}

local function setup_keymaps()
  -- Global keymaps
  local keymaps = Config.get("keymaps")
  vim.keymap.set({ "n", "v" }, keymaps.toggle, ChatDialog.toggle, { noremap = true, silent = true })
  vim.keymap.set("n", keymaps.previous_chat, ChatDialog.get_previous_chat, { noremap = true, silent = true })
  vim.keymap.set("n", keymaps.next_chat, ChatDialog.get_next_chat, { noremap = true, silent = true })
  vim.keymap.set({ "n", "v" }, keymaps.inline_assist, Assistant.inline, { noremap = true, silent = true })
  -- Buffer-specific keymaps for ChatDialog
  local function set_chat_dialog_keymaps()
    local opts = { noremap = true, silent = true, buffer = true }
    vim.keymap.set("n", keymaps.close, ChatDialog.close, opts)
    vim.keymap.set("n", keymaps.send, ChatDialog.send, opts)
    vim.keymap.set("n", keymaps.clear, ChatDialog.clear, opts)
  end

  vim.api.nvim_set_keymap(
    "n",
    keymaps.stop_generate,
    ":doautocmd User NVIMAIHTTPEscape<CR>",
    { noremap = true, silent = true }
  )

  local M = {}

  -- Create an autocommand to set ChatDialog keymaps when entering the chat-dialog buffer
  vim.api.nvim_create_autocmd("FileType", {
    pattern = Config.FILE_TYPE,
    callback = set_chat_dialog_keymaps,
  })
  vim.treesitter.language.register("markdown", Config.FILE_TYPE)
end
--
-- Setup function to initialize the plugin
M.setup = function(opts)
  Config.setup(opts)
  -- Load the plugin's configuration
  ChatDialog:setup()
  Providers.setup()

  -- create commands
  local cmds = require("ai.cmds")
  for _, cmd in ipairs(cmds) do
    vim.api.nvim_create_user_command(cmd.cmd, cmd.callback, cmd.opts)
  end
  setup_keymaps()
end

return M
