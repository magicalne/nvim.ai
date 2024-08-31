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
