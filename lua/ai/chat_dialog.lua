local config = require('ai.config')
local Utils = require('ai.utils')
local Assistant = require('ai.assistant')
local api = vim.api
local fn = vim.fn

local ChatDialog = {}

ChatDialog.config = {
  width = 40,
  side = 'right',
  borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
}

local state = {
  buf = nil,
  win = nil,
  last_saved_file = nil,
}

local function create_buf()
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  api.nvim_buf_set_option(buf, 'buflisted', false)
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_option(buf, 'filetype', config.FLIE_TYPE)
  return buf
end

local function get_win_config()
  local width = ChatDialog.config.width
  local height = api.nvim_get_option('lines') - 4
  local col = ChatDialog.config.side == 'left' and 0 or (api.nvim_get_option('columns') - width)

  return {
    relative = 'editor',
    width = width,
    height = height,
    row = 0,
    col = col,
    style = 'minimal',
    border = ChatDialog.config.borderchars,
  }
end

local function get_project_name()
  local cwd = vim.fn.getcwd()
  return vim.fn.fnamemodify(cwd, ':t')
end

local function generate_chat_filename()
  local project_name = get_project_name()
  local save_dir = config.config.saved_chats_dir .. '/' .. project_name

  -- Create the directory if it doesn't exist
  vim.fn.mkdir(save_dir, 'p')

  -- Generate a unique filename based on timestamp
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local filename = save_dir .. '/chat_' .. timestamp .. '.md'
  return filename
end

function ChatDialog.save_file()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    print("No valid chat buffer to save.")
    return
  end

  local filename = state.last_saved_file or generate_chat_filename()

  -- Get buffer contents
  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local content = table.concat(lines, '\n')

  -- Write to file
  local file = io.open(filename, 'w')
  if file then
    file:write(content)
    file:close()
    print("Chat saved to: " .. filename)

    -- Set the buffer name to the saved file path
    api.nvim_buf_set_name(state.buf, filename)

    -- Update the last saved file
    state.last_saved_file = filename
  else
    print("Failed to save chat to file: " .. filename)
  end
end

local function find_most_recent_chat_file()
  local project_name = get_project_name()
  local save_dir = config.config.saved_chats_dir .. '/' .. project_name

  local files = vim.fn.glob(save_dir .. '/chat_*.md', 0, 1)
  table.sort(files, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end)

  if state.last_saved_file == nil then
    state.last_saved_file = files[1]
  end

  return files[1] -- Return the most recent file, or nil if no files found
end

function ChatDialog.open()
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_set_current_win(state.win)
    return
  end

  local file_to_load = state.last_saved_file or find_most_recent_chat_file()

  if file_to_load then
    state.buf = vim.fn.bufadd(file_to_load)
    vim.fn.bufload(state.buf)
    api.nvim_buf_set_option(state.buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(state.buf, 'bufhidden', 'hide')
    api.nvim_buf_set_option(state.buf, 'swapfile', false)
    api.nvim_buf_set_option(state.buf, 'filetype', config.FLIE_TYPE)
  else
    state.buf = state.buf or create_buf()
  end
  local win_config = get_win_config()
  state.win = api.nvim_open_win(state.buf, true, win_config)

  -- Set window options
  api.nvim_win_set_option(state.win, 'wrap', true)
  api.nvim_win_set_option(state.win, 'linebreak', true) -- Wrap at word boundaries
  api.nvim_win_set_option(state.win, 'cursorline', true)
  -- Return focus to the main window
  vim.cmd('wincmd p')
end

function ChatDialog.close()
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

function ChatDialog.toggle()
  if state.win and api.nvim_win_is_valid(state.win) then
    ChatDialog.close()
  else
    ChatDialog.open()
  end
end

function ChatDialog.on_complete(t)
  ChatDialog.append_text("\n\n/you:\n")
  vim.schedule(function()
    ChatDialog.save_file()
  end)
end

function ChatDialog.append_text(text)
  if not state.buf or not pcall(vim.api.nvim_buf_is_loaded, state.buf) or not pcall(vim.api.nvim_buf_get_option, state.buf, 'buflisted') then
    return
  end

  vim.schedule(function()
    -- Get the last line and its content
    local last_line = api.nvim_buf_line_count(state.buf)
    local last_line_content = api.nvim_buf_get_lines(state.buf, -2, -1, false)[1] or ""

    -- Split the new text into lines
    local new_lines = vim.split(text, "\n", { plain = true })

    -- Append the first line to the last line of the buffer
    local updated_last_line = last_line_content .. new_lines[1]
    api.nvim_buf_set_lines(state.buf, -2, -1, false, { updated_last_line })

    -- Append the rest of the lines, if any
    if #new_lines > 1 then
      api.nvim_buf_set_lines(state.buf, -1, -1, false, { unpack(new_lines, 2) })
    end

    -- Scroll to bottom
    if state.win and api.nvim_win_is_valid(state.win) then
      local new_last_line = api.nvim_buf_line_count(state.buf)
      local last_col = #api.nvim_buf_get_lines(state.buf, -2, -1, false)[1]
      api.nvim_win_set_cursor(state.win, { new_last_line, last_col })
    end
  end)
end

function ChatDialog.clear()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then return end

  api.nvim_buf_set_option(state.buf, "modifiable", true)
  api.nvim_buf_set_lines(state.buf, 0, -1, false, {})
  state.last_saved_file = nil
end

function ChatDialog.send()
  local system = ChatDialog.get_system_prompt()
  local prompt = ChatDialog.last_user_request()

  ChatDialog.append_text("\n\n/assistant:\n")
  Assistant.ask(system, prompt, ChatDialog.append_text, ChatDialog.on_complete)
end

function ChatDialog.get_system_prompt()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then return nil end

  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  for _, line in ipairs(lines) do
    if line:match("^/system%s(.+)") then
      return line:match("^/system%s(.+)")
    end
  end
  return nil
end

-- Function to get the last user request from the buffer
function ChatDialog.last_user_request()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then return nil end

  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local last_request = {}

  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:match("^/you") then
      -- We've found the start of the last user block
      break
    else
      table.insert(last_request, 1, line)
    end
  end

  if #last_request > 0 then
    return table.concat(last_request, "\n")
  else
    return nil
  end
end

function ChatDialog.setup()
  ChatDialog.config = vim.tbl_deep_extend("force", ChatDialog.config, config.config.ui or {})
  -- Create user commands
  api.nvim_create_user_command("ChatDialogToggle", ChatDialog.toggle, {})
  api.nvim_create_user_command("ChatDialogClear", ChatDialog.clear, {})
end

return ChatDialog
