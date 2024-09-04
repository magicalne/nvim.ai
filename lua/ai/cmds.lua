local ChatDialog = require("ai.chat_dialog")
local Assistant = require('ai.assistant')
return {

  {
    cmd = "NvimAIToggleChatDialog",
    callback = function()
      ChatDialog.toggle()
    end,
    opts = {
      desc = "Insert code or rewrite a section",
    },
  },
  {
    cmd = "NvimAIPrevousChat",
    callback = function()
      ChatDialog.get_previous_chat()
    end,
    opts = {
      desc = "Get previous chat from history",
    },
  },
  {
    cmd = "NvimAINextChat",
    callback = function()
      ChatDialog.get_next_chat()
    end,
    opts = {
      desc = "Get next chat from history",
    },
  },
  {
    cmd = "NvimAIInlineAssist",
    callback = function(opts)
      Assistant.inline(opts.args)
    end,
    opts = {
      desc = "Insert code or rewrite a section",
      range = true,
      nargs = "*",
    },
  },
}
