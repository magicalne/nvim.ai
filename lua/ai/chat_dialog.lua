local Providers = require("ai.providers")
local Http = require("ai.http")
local config = require("ai.config")
local Utils = require("ai.utils")
local Assist = require("ai.assistant.assist")
local Prompts = require("ai.assistant.prompts")
local api = vim.api
local fn = vim.fn

local ChatDialog = {}
ChatDialog.ROLE_USER = "user"
ChatDialog.ROLE_ASSISTANT = "assistant"
local chat_dialog_group = vim.api.nvim_create_augroup("ChatDialogGroup", { clear = false })
local cmp_source_setup = false

ChatDialog.config = {
  width = 40,
  side = "right",
  borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
}

ChatDialog.state = {
  buf = nil,
  win = nil,
  last_saved_file = nil,
}

local function create_buf()
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(buf, "buflisted", false)
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_option(buf, "filetype", config.FILE_TYPE)
  return buf
end

local function get_win_config()
  local width_rate = ChatDialog.config.width
  local width

  if type(width_rate) == "string" then
    -- Calculate width based on percentage of the current screen width
    local screen_width = api.nvim_get_option("columns")
    -- 30%
    width = math.floor(screen_width * tonumber(width_rate:sub(1, -2)) / 100)
  elseif type(width_rate) == "number" then
    -- Use the fixed width value
    width = width_rate
  else
    -- Default to a fixed width if the configuration is invalid
    width = 40
  end
  local height = api.nvim_get_option("lines") - 4
  local col = ChatDialog.config.side == "left" and 0 or (api.nvim_get_option("columns") - width)

  return {
    relative = "editor",
    width = width,
    height = height,
    row = 0,
    col = col,
    style = "minimal",
    border = ChatDialog.config.borderchars,
  }
end

local function get_project_name()
  local cwd = vim.fn.getcwd()
  return vim.fn.fnamemodify(cwd, ":t")
end

local function generate_chat_filename()
  local project_name = get_project_name()
  local save_dir = config.config.saved_chats_dir .. "/" .. project_name

  -- Create the directory if it doesn't exist
  vim.fn.mkdir(save_dir, "p")

  -- Generate a unique filename based on timestamp
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local filename = save_dir .. "/chat_" .. timestamp .. ".md"
  return filename
end

function parse_messages(lines)
  local result = {}
  local current_role = nil
  local current_content = {}

  for _, line in ipairs(lines) do
    if line:match("^/you") then
      if current_role then
        table.insert(result, {
          role = current_role,
          content = table.concat(current_content, "\n"),
        })
        current_content = {}
      end
      current_role = ChatDialog.ROLE_USER
    elseif line:match("^/assistant") then
      if current_role then
        local content
        if current_role == ChatDialog.ROLE_USER then
          -- parse slash commands in user prompt
          content = Assist.parse_user_message(current_content)
        else
          content = table.concat(current_content, "\n")
        end

        table.insert(result, {
          role = current_role,
          content = content,
        })
        current_content = {}
      end
      current_role = ChatDialog.ROLE_ASSISTANT
    else
      if current_role then table.insert(current_content, line) end
    end
  end

  if current_role and #current_content > 0 then
    local content
    if current_role == ChatDialog.ROLE_USER then
      -- parse slash commands in user prompt
      content = Assist.parse_user_message(current_content)
    else
      content = table.concat(current_content, "\n")
    end
    table.insert(result, {
      role = current_role,
      content = content,
    })
  end

  return result
end

function ChatDialog.save_file()
  if not (ChatDialog.state.buf and api.nvim_buf_is_valid(ChatDialog.state.buf)) then
    print("No valid chat buffer to save.")
    return
  end

  local filename = ChatDialog.state.last_saved_file
  if filename == nil or filename == "" then
    filename = generate_chat_filename()
  end

  -- Get buffer contents
  local lines = api.nvim_buf_get_lines(ChatDialog.state.buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Write to file
  local file = io.open(filename, "w")
  if file then
    file:write(content)
    file:close()
    print("Chat saved to: " .. filename)

    -- Set the buffer name to the saved file path
    api.nvim_buf_set_name(ChatDialog.state.buf, filename)

    -- Update the last saved file
    ChatDialog.state.last_saved_file = filename
  else
    print("Failed to save chat to file: " .. filename)
  end
end

function ChatDialog.get_chat_histories()
  local project_name = get_project_name()
  local save_dir = config.config.saved_chats_dir .. "/" .. project_name

  local files = vim.fn.glob(save_dir .. "/chat_*.md", 0, 1)
  table.sort(files, function(a, b) return a > b end) -- Sort in descending order

  return files
end

function ChatDialog.get_previous_chat()
  local histories = ChatDialog.get_chat_histories()
  if #histories == 0 then
    print("No chat histories found.")
    return
  end

  local current_file = ChatDialog.state.last_saved_file or histories[1]
  local current_index = vim.fn.index(histories, current_file)

  if current_index == -1 or current_index == #histories - 1 then
    print("No previous chat file available.")
    return
  end

  local previous_file = histories[current_index + 2]
  ChatDialog.load_chat_file(previous_file)
end

function ChatDialog.get_next_chat()
  local histories = ChatDialog.get_chat_histories()
  if #histories == 0 then
    print("No chat histories found.")
    return
  end

  local current_file = ChatDialog.state.last_saved_file or histories[1]
  local current_index = vim.fn.index(histories, current_file)

  if current_index == -1 or current_index == 0 then
    print("No next chat file available.")
    return
  end

  local next_file = histories[current_index]
  ChatDialog.load_chat_file(next_file)
end

-- Helper function to load a chat file
function ChatDialog.load_chat_file(file_path)
  if not file_path or not vim.fn.filereadable(file_path) then
    print("Invalid or unreadable file: " .. tostring(file_path))
    return
  end

  ChatDialog.state.last_saved_file = file_path
  if ChatDialog.state.buf and api.nvim_buf_is_valid(ChatDialog.state.buf) then
    api.nvim_buf_set_lines(ChatDialog.state.buf, 0, -1, false, {})
    local lines = vim.fn.readfile(file_path)
    api.nvim_buf_set_lines(ChatDialog.state.buf, 0, -1, false, lines)
    print("Loaded chat file: " .. file_path)
  else
    print("Chat buffer is not valid. Please open the chat dialog first.")
  end
end

function ChatDialog.open()
  if ChatDialog.state.win and api.nvim_win_is_valid(ChatDialog.state.win) then
    api.nvim_set_current_win(ChatDialog.state.win)
    return
  end

  local file_to_load = ChatDialog.state.last_saved_file or ChatDialog.get_chat_histories()[1]

  if file_to_load then
    ChatDialog.state.buf = vim.fn.bufadd(file_to_load)
    vim.fn.bufload(ChatDialog.state.buf)
    api.nvim_buf_set_option(ChatDialog.state.buf, "buftype", "nofile")
    api.nvim_buf_set_option(ChatDialog.state.buf, "bufhidden", "wipe")
    api.nvim_buf_set_option(ChatDialog.state.buf, "buflisted", false)
    api.nvim_buf_set_option(ChatDialog.state.buf, "swapfile", false)
    api.nvim_buf_set_option(ChatDialog.state.buf, "filetype", config.FILE_TYPE)
  else
    ChatDialog.state.buf = ChatDialog.state.buf or create_buf()
  end
  local win_config = get_win_config()
  ChatDialog.state.win = api.nvim_open_win(ChatDialog.state.buf, true, win_config)

  -- Set window options
  api.nvim_win_set_option(ChatDialog.state.win, "wrap", true)
  api.nvim_win_set_option(ChatDialog.state.win, "linebreak", true) -- Wrap at word boundaries
  api.nvim_win_set_option(ChatDialog.state.win, "cursorline", true)
end

function ChatDialog.close()
  if ChatDialog.state.win and api.nvim_win_is_valid(ChatDialog.state.win) then
    api.nvim_win_close(ChatDialog.state.win, true)
  end
  ChatDialog.state.win = nil
  ChatDialog.state.buf = nil
end

function ChatDialog.toggle()
  if ChatDialog.state.win and api.nvim_win_is_valid(ChatDialog.state.win) then
    ChatDialog.close()
  else
    ChatDialog.open()
  end
end

function ChatDialog.on_complete(t)
  vim.defer_fn(function()
    api.nvim_buf_set_option(ChatDialog.state.buf, "modifiable", true)
    api.nvim_buf_set_lines(ChatDialog.state.buf, -1, -1, false, { "", "/you:", "" })
    ChatDialog.save_file()
  end, 10) -- 10ms delay
end

function ChatDialog.append_text(text)
  if
    not ChatDialog.state.buf
    or not pcall(vim.api.nvim_buf_is_loaded, ChatDialog.state.buf)
    or not pcall(vim.api.nvim_buf_get_option, ChatDialog.state.buf, "buflisted")
  then
    return
  end

  vim.schedule(function()
    -- Get the last line and its content
    local last_line = api.nvim_buf_line_count(ChatDialog.state.buf)
    local last_line_content = api.nvim_buf_get_lines(ChatDialog.state.buf, -2, -1, false)[1] or ""

    -- Split the new text into lines
    local new_lines = vim.split(text, "\n", { plain = true })

    api.nvim_buf_set_option(ChatDialog.state.buf, "modifiable", true)
    -- Append the first line to the last line of the buffer
    local updated_last_line = last_line_content .. new_lines[1]
    api.nvim_buf_set_lines(ChatDialog.state.buf, -2, -1, false, { updated_last_line })

    -- Append the rest of the lines, if any
    if #new_lines > 1 then api.nvim_buf_set_lines(ChatDialog.state.buf, -1, -1, false, { unpack(new_lines, 2) }) end
    api.nvim_buf_set_option(ChatDialog.state.buf, "modifiable", false)

    -- Scroll to bottom
    if ChatDialog.state.win and api.nvim_win_is_valid(ChatDialog.state.win) then
      local new_last_line = api.nvim_buf_line_count(ChatDialog.state.buf)
      local last_col = #api.nvim_buf_get_lines(ChatDialog.state.buf, -2, -1, false)[1]
      api.nvim_win_set_cursor(ChatDialog.state.win, { new_last_line, last_col })
    end
  end)
end

function ChatDialog.clear()
  if not (ChatDialog.state.buf and api.nvim_buf_is_valid(ChatDialog.state.buf)) then return end

  api.nvim_buf_set_lines(ChatDialog.state.buf, 0, -1, false, {})
  ChatDialog.state.last_saved_file = nil
end

function ChatDialog.send()
  local system = ChatDialog.get_system_prompt() or Prompts.GLOBAL_SYSTEM_PROMPT
  local prompt = ChatDialog.last_user_request()
  local messages = ChatDialog.get_messages()

  ChatDialog.append_text("\n\n/assistant:\n")
  -- Assistant.ask(system, messages, ChatDialog.append_text, ChatDialog.on_complete)
  local provider = config.config.provider
  local p = Providers.get(provider)
  Http.stream(system, messages, ChatDialog.append_text, ChatDialog.on_complete)
end

function ChatDialog.get_system_prompt()
  if not (ChatDialog.state.buf and api.nvim_buf_is_valid(ChatDialog.state.buf)) then return nil end

  local lines = api.nvim_buf_get_lines(ChatDialog.state.buf, 0, -1, false)
  for _, line in ipairs(lines) do
    if line:match("^/system%s(.+)") then return line:match("^/system%s(.+)") end
  end
  return nil
end

function ChatDialog.get_messages()
  if not (ChatDialog.state.buf and api.nvim_buf_is_valid(ChatDialog.state.buf)) then return nil end
  local lines = api.nvim_buf_get_lines(ChatDialog.state.buf, 0, -1, false)
  return parse_messages(lines)
end

function ChatDialog.get_last_assist_message()
  local messages = ChatDialog.get_messages()
  if not messages then return nil end

  for i = #messages, 1, -1 do
    local message = messages[i]
    if message.role == ChatDialog.ROLE_ASSISTANT then return message end
  end

  return nil
end

-- Function to get the last user request from the buffer
function ChatDialog.last_user_request()
  if not (ChatDialog.state.buf and api.nvim_buf_is_valid(ChatDialog.state.buf)) then return nil end

  local lines = api.nvim_buf_get_lines(ChatDialog.state.buf, 0, -1, false)
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

function ChatDialog.setup_autocmd()
  -- Check if cmp is available
  local has_cmp, cmp = pcall(require, "cmp")
  if not has_cmp then return end

  -- Create an autocmd that sets up the cmp source when entering the chat buffer
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = chat_dialog_group,
    once = false,
    callback = function()
      -- Check if the cmp source is already set up for this buffer
      -- This is important. Otherwise duplicated source will be inserted into cmp.sources.
      if not cmp_source_setup then
        -- Register our custom source
        cmp.register_source("nvimai_cmp_source", require("ai.cmp_source").new())
        -- Set up cmp for this buffer with the updated sources
        cmp_source_setup = true
        -- Get the current buffer's sources
        local sources = cmp.get_config().sources
        -- Add our custom source to the beginning of the sources list
        table.insert(sources, 1, { name = "nvimai_cmp_source", group_index = 2, })
        cmp.setup.buffer({
          sources
        })
      end
    end,
  })
end

function ChatDialog.setup()
  ChatDialog.config = vim.tbl_deep_extend("force", ChatDialog.config, config.config.ui or {})
  ChatDialog.setup_autocmd()
end

return ChatDialog
