local Config = require("ai.config")
local Assist = require("ai.assistant.assist")
local Http = require("ai.http")
local ChatDialog = require("ai.chat_dialog")
local Prompts = require("ai.assistant.prompts")

local ESC_FEEDKEY = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)

local Inline = {
  state = {
    code_block = "",
    cursor_line = nil,
    start_line = nil,
    end_line = nil,
    original_code_block = {},
  },
}

function extract_code(text)
  local lines = {}
  local in_code_block = false

  -- Split the text into lines
  for line in text:gmatch("[^\r\n]+") do
    if line:match("^```") then
      in_code_block = not in_code_block
    elseif in_code_block then
      table.insert(lines, line)
    end
  end
  -- Join the lines back into a single string
  return table.concat(lines, "\n")
end

function Inline:insert_lines()
  vim.schedule(function()
    local lines = vim.split(self.state.code_block, "\n", true)
    local insert_position = self.state.cursor_line

    for i, line in ipairs(lines) do
      if not line:match("^```") then
        vim.api.nvim_buf_set_lines(0, insert_position, insert_position, false, { line })
        insert_position = insert_position + 1
      end
    end

    self.state.end_line = insert_position - 1
    vim.fn.cursor(self.state.end_line, 1)
  end)
end

function Inline:append_text(text) self.state.code_block = self.state.code_block .. text end

function Inline:on_complete(is_insert)
  if not is_insert then
    -- Schedule the buffer modification to run after the loop callback
    vim.schedule(function()
      -- Store old code block
      local old = {}
      for i = self.state.start_line, self.state.end_line do
        table.insert(old, vim.api.nvim_buf_get_lines(0, i - 1, i, true)[1])
      end
      self.state.original_code_block = old
      -- Delete lines for rewriting section
      vim.api.nvim_buf_set_lines(0, self.state.start_line - 1, self.state.end_line, false, { "" })
    end)
  end
  self:insert_lines()
end

function Inline:start(prompt, is_insert)
  local system_prompt = Prompts.GLOBAL_SYSTEM_PROMPT
  -- TODO: Cannot just get the last message from `asssitance`.
  -- Provider like anthropic requires first role must be `user`.
  -- Maybe just take the last 2 messages?
  local messages = ChatDialog.get_messages() or {}
  -- remove the last message if its role is user
  if #messages > 0 and messages[#messages].role == ChatDialog.ROLE_USER then table.remove(messages) end
  local user_message = {
    role = "user",
    content = prompt,
  }
  table.insert(messages, user_message)

  Http.stream(
    system_prompt,
    messages,
    function(text) self:append_text(text) end,
    function() self:on_complete(is_insert) end
  )
end

local function get_visual_selection_lines()
  local mode = vim.api.nvim_get_mode().mode
  -- Get the start and end positions of the visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  -- Extract the line numbers from the positions
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Return the line numbers
  return start_line, end_line
end

function Inline:new(prompt)
  -- Check if we are in visual mode
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "" then
    -- insert mode
    self.state.code_block = ""
    start_line = vim.fn.line(".")
    self.state.cursor_line = start_line - 1
    self.state.start_line = self.state.cursor_line
    self.state.end_line = start_line - 1
    local parsed_prompt = Assist.parse_inline_assist_prompt(prompt, nil, true, start_line, start_line)
    self:start(parsed_prompt, true)
  else
    vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)
    vim.api.nvim_feedkeys("gv", "x", false)
    vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)
    -- rewrite mode
    local start_line, end_line = get_visual_selection_lines()
    self.state.cursor_line = start_line
    self.state.start_line = start_line
    self.state.end_line = end_line
    local parsed_prompt = Assist.parse_inline_assist_prompt(prompt, nil, false, start_line, end_line)
    self:start(parsed_prompt, false)
  end
end

return Inline
