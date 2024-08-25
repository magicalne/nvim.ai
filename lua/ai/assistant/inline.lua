local Config = require('ai.config')
local Assist = require('ai.assistant.assist')
local Http = require('ai.http')
local Prompts = require('ai.assistant.prompts')

local Inline = {
  state = {
    code_block = '',
    cursor_line = nil,
    start_line = nil,
    end_line = nil
  }
}

function Inline:insert_lines()
  vim.schedule(function()
    local lines = vim.split(self.state.code_block, '\n', true)
    for i, line in ipairs(lines) do
      vim.api.nvim_buf_set_lines(0, self.state.cursor_line, self.state.cursor_line, false, {line})
      self.state.cursor_line = self.state.cursor_line + 1
      vim.fn.cursor(self.state.cursor_line, 1)
    end
    self.state.end_line = self.state.cursor_line
  end)
end

function Inline:append_text(text)
  self.state.code_block = self.state.code_block .. text
end

function Inline:on_complete()
  self:insert_lines()
end

function Inline:accept_code()
  if not self.state.start_line or not self.state.end_line then
    print('No code to accept')
    return
  end

  vim.schedule(function()
    vim.api.nvim_buf_set_lines(0, self.state.start_line, self.state.start_line + 1, false, {})
    self.state.cursor_line = self.state.cursor_line - 1
    vim.fn.cursor(self.state.cursor_line, 1)

    if self.state.end_line > self.state.start_line then
      vim.api.nvim_buf_set_lines(0, self.state.end_line - 2, self.state.end_line - 1, false, {})
      self.state.cursor_line = self.state.cursor_line - 1
      vim.fn.cursor(self.state.cursor_line, 1)
    end
  end)
end

function Inline:reject_code()
  if not self.state.start_line or not self.state.end_line then
    print('No code to reject')
    return
  end

  vim.schedule(function()
    vim.api.nvim_buf_set_lines(0, self.state.start_line, self.state.end_line, false, {})
    self.state.cursor_line = self.state.cursor_line - (self.state.end_line - self.state.start_line)
    vim.fn.cursor(self.state.cursor_line, 1)
  end)
end

function Inline:insert(prompt)
  local system_prompt = Prompts.GLOBAL_SYSTEM_PROMPT
  Http.stream(system_prompt, prompt, function(text) self:append_text(text) end, function() self:on_complete() end)
end

function Inline:new(prompt)
  self.state.code_block = ''
  self.state.cursor_line = vim.fn.line('.') - 1
  self.state.start_line = self.state.cursor_line
  local parsed_prompt = Assist.parse_inline_assist_prompt(prompt, nil, true)
  self:insert(parsed_prompt)
end

return Inline
