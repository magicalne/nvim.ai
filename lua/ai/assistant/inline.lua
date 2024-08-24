local Config = require('ai.config')
local Assist = require('ai.assistant.assist')
local Http = require('ai.http')
local Prompts = require('ai.assistant.prompts')
local Inline = {}
local state = {
  code_block = '',
  cursor_line = nil,
  start_line = nil,
  end_line = nil
}

local function insert_lines()
  local lines = vim.split(state.code_block, '\n', true)
  for i, line in ipairs(lines) do
    vim.api.nvim_buf_set_lines(0, state.cursor_line, state.cursor_line, false, {line})
    state.cursor_line = state.cursor_line + 1
    vim.fn.cursor(state.cursor_line, 1)
  end
  state.end_line = state.cursor_line
end

function Inline.append_text(text)
  state.code_block = state.code_block .. text
end

function Inline.on_complete(t)

  vim.schedule(function()
    insert_lines()
  end)
end

function Inline.accept_code()
  if state.start_line == nil or state.end_line == nil then
    print('No code to accept')
    return
  end

  vim.api.nvim_buf_set_lines(0, state.start_line, state.start_line + 1, false, {})
  state.cursor_line = state.cursor_line - 1
  vim.fn.cursor(state.cursor_line, 1)

  if state.end_line > state.start_line then
    vim.api.nvim_buf_set_lines(0, state.end_line - 2, state.end_line - 1, false, {})
    state.cursor_line = state.cursor_line - 1
    vim.fn.cursor(state.cursor_line, 1)
  end
end

function Inline.reject_code()
  if state.start_line == nil or state.end_line == nil then
    print('No code to reject')
    return
  end
  vim.api.nvim_buf_set_lines(0, state.start_line, state.end_line, false, {})
  state.cursor_line = state.cursor_line - (state.end_line - state.start_line)
  vim.fn.cursor(state.cursor_line, 1)
end


function Inline.insert(prompt)
  local system_prompt = Prompts.GLOBAL_SYSTEM_PROMPT
  Http.stream(system_prompt, prompt, Inline.append_text, Inline.on_complete)
end

function Inline:new(prompt)
  state.code_block = ''
  state.cursor_line = vim.fn.line('.') - 1
  state.start_line = state.cursor_line
  local prompt = Assist.parse_inline_assist_prompt(prompt, nil, true)
  --print('prompt', prompt)
  Inline.insert(prompt)

end

return Inline
