local Assistant = require('ai.assistant')
return {
  {
    cmd = "InlineAssist",
    callback = function(opts)
      print('inline assist', opts.args)
      Assistant.inline(opts.args)

    end,
    opts = {
      desc = "Insert code or rewrite a section",
      range = true,
      nargs = "*",
    },
  },
  {
    cmd = "AcceptCode",
    callback = function(opts)
      Assistant.accept_code()
    end,
    opts = {
      desc = "Accept generated code",
      range = true,
      nargs = "*",
    },
  },
  {
    cmd = "RejectCode",
    callback = function(opts)
      Assistant.reject_code()
    end,
    opts = {
      desc = "Reject generated code",
      range = true,
      nargs = "*",
    },
  }
}
