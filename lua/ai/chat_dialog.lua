local Http = require("ai.http")
local config = require("ai.config")
local Assist = require("ai.assistant.assist")
local Prompts = require("ai.assistant.prompts")
local api = vim.api

local ChatDialog = {}
ChatDialog.ROLE_USER = "user"
ChatDialog.ROLE_ASSISTANT = "assistant"
local chat_dialog_group = vim.api.nvim_create_augroup("ChatDialogGroup", { clear = false })

ChatDialog.config = {
  width = 40,
  side = "right",
  borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
}

ChatDialog.state = {
  buf = nil,
  win = nil,
  last_saved_file = nil,
  metadata = {
    provider = nil,
    model = nil,
    temperature = nil,
    max_tokens = nil,
    system_prompt = nil,
  },
}

local function init_buf_content(bufnr)
  local content_table = {
    "---",
    "provider: " .. (ChatDialog.state.metadata.provider or ""),
    "model: " .. (ChatDialog.state.metadata.model or ""),
    "temperature: " .. (ChatDialog.state.metadata.temperature or ""),
    "max_tokens: " .. (ChatDialog.state.metadata.max_tokens or ""),
    "---",
    "",
  }

  -- Split the system_prompt into lines and insert each line into the metadata table
  local system_prompt_lines = ChatDialog.state.metadata.system_prompt or ""

  local split_lines = vim.split(system_prompt_lines, "\n")
  -- Combine the "system_prompt: " label with the first line of the system_prompt
  if #split_lines > 0 then
    table.insert(content_table, "/system")
    -- Insert each subsequent line of the system_prompt
    for i = 1, #split_lines do
      table.insert(content_table, split_lines[i])
    end
  else
    table.insert(content_table, "/system")
    table.insert(content_table, system_prompt_lines)
  end

  -- Continue with the rest of the content
  table.insert(content_table, "")
  table.insert(content_table, "/you")
  table.insert(content_table, "")

  -- Set the lines in the buffer
  api.nvim_buf_set_lines(bufnr, 0, -1, false, content_table)
end

local function create_buf()
  local buf = api.nvim_create_buf(false, false)

  api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  api.nvim_set_option_value("buflisted", false, { buf = buf })
  api.nvim_set_option_value("swapfile", false, { buf = buf })
  api.nvim_set_option_value("filetype", config.FILE_TYPE, { buf = buf })

  -- init states
  ChatDialog.state.metadata.provider = config.config.provider
  ChatDialog.state.metadata.model = config.config[config.config.provider].model
  ChatDialog.state.metadata.temperature = config.config[config.config.provider].temperature
  ChatDialog.state.metadata.max_tokens = config.config[config.config.provider].max_tokens
  ChatDialog.state.metadata.system_prompt = Prompts.GLOBAL_SYSTEM_PROMPT
  init_buf_content(buf)
  return buf
end

local function get_win_config()
  local width_rate = ChatDialog.config.width
  local width

  if type(width_rate) == "string" then
    -- Calculate width based on percentage of the current screen width
    local screen_width = api.nvim_get_option_value("columns", {})
    -- 30%
    width = math.floor(screen_width * tonumber(width_rate:sub(1, -2)) / 100)
  elseif type(width_rate) == "number" then
    -- Use the fixed width value
    width = width_rate
  else
    -- Default to a fixed width if the configuration is invalid
    width = 40
  end
  local height = api.nvim_get_option_value("lines", {}) - 4
  local col = ChatDialog.config.side == "left" and 0 or (api.nvim_get_option_value("columns", {}) - width)

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

local function parse_metadata(lines)
  local markdown_content = table.concat(lines, "\n")
  -- Trim leading and trailing whitespace
  local function trim(s) return s:match("^%s*(.-)%s*$") end

  -- Extract the metadata section between the first two ---
  local metadata_content = markdown_content:match("^%s*---%s*\n(.-)\n%s*---%s*")
  if not metadata_content then return nil end

  local metadata = {}

  -- Iterate through lines
  for line in metadata_content:gmatch("[^\n]+") do
    line = trim(line)

    -- Check if this is a new key-value pair
    local key, value = line:match("^(%w+):%s*(.*)$")
    if key then metadata[key] = trim(value or "") end
  end

  return metadata
end

local function parse_system_prompt(lines)
  -- process single line system prompt
  local system_prompt_lines = {}
  local flag = false
  for _, line in ipairs(lines) do
    if line:match("^/system%s(.+)") then
      flag = true
      table.insert(system_prompt_lines, line:match("^/system%s(.+)"))
    elseif flag and line ~= "/you" then
      table.insert(system_prompt_lines, line)
    else
      break
    end
  end
  if #system_prompt_lines > 0 then
    return table.concat(system_prompt_lines, "\n")
  else
    return Prompts.GLOBAL_SYSTEM_PROMPT
  end
end

local function parse_messages(lines)
  local result = {}
  local current_role = nil
  local current_content = {}
  local function escape_quotes(text) return text:gsub('"', '\\"') end

  for _, line in ipairs(lines) do
    if line:match("^/you") then
      if current_role then
        table.insert(result, {
          role = current_role,
          content = escape_quotes(table.concat(current_content, "\n")),
          -- content = table.concat(current_content, "\n"),
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
          -- content = content,
          content = escape_quotes(content),
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
      -- content = content,
      content = escape_quotes(content),
    })
  end

  return result
end

local function parse_content(lines)
  local metadata = parse_metadata(lines)
  local system_prompt = parse_system_prompt(lines)
  local messages = parse_messages(lines)

  return metadata, system_prompt, messages
end

function ChatDialog.save_file()
  if not (ChatDialog.state.buf and api.nvim_buf_is_valid(ChatDialog.state.buf)) then
    print("No valid chat buffer to save.")
    return
  end

  local filename = ChatDialog.state.last_saved_file
  if filename == nil or filename == "" then filename = generate_chat_filename() end

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

  local files = vim.fn.glob(save_dir .. "/chat_*.md", true, 1)
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

  -- get original window options
  local original_win_opts = {}
  local win_number = api.nvim_get_current_win()
  local v = vim.wo[win_number]
  local all_options = api.nvim_get_all_options_info()
  for key, val in pairs(all_options) do
    if val.global_local == false and val.scope == "win" then original_win_opts[key] = v[key] end
  end

  -- Open last saved file instead of creating a new file
  ChatDialog.state.last_saved_file = ChatDialog.get_chat_histories()[1]

  if ChatDialog.state.last_saved_file then
    -- load from last saved file
    ChatDialog.state.buf = vim.fn.bufadd(ChatDialog.state.last_saved_file)
    vim.fn.bufload(ChatDialog.state.buf)
    -- api.nvim_buf_set_option(ChatDialog.state.buf, "buftype", "nofile")

    api.nvim_set_option_value("bufhidden", "wipe", { buf = ChatDialog.state.buf })
    api.nvim_set_option_value("buflisted", false, { buf = ChatDialog.state.buf })
    api.nvim_set_option_value("swapfile", false, { buf = ChatDialog.state.buf })
    api.nvim_set_option_value("filetype", config.FILE_TYPE, { buf = ChatDialog.state.buf })
  else
    -- create a new buf
    ChatDialog.state.buf = ChatDialog.state.buf or create_buf()
  end
  local win_config = get_win_config()
  ChatDialog.state.win = api.nvim_open_win(ChatDialog.state.buf, true, win_config)

  -- Set window options
  -- Copy all options from the original window to the new window
  for opt, value in pairs(original_win_opts) do
    api.nvim_set_option_value(opt, value, { win = ChatDialog.state.win })
  end
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

local function dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then k = '"' .. k .. '"' end
      s = s .. "[" .. k .. "] = " .. dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

function ChatDialog.on_complete(err_msg)
  vim.defer_fn(function()
    api.nvim_set_option_value("modifiable", true, { buf = ChatDialog.state.buf })
    if err_msg then
      ChatDialog.append_text("An error occurred: " .. dump(err_msg))
    else
      api.nvim_buf_set_lines(ChatDialog.state.buf, -1, -1, false, { "", "/you", "" })
    end
  end, 50)
  vim.defer_fn(function() ChatDialog.save_file() end, 500)
end

function ChatDialog.append_text(text)
  if not ChatDialog.state.buf or not pcall(api.nvim_buf_is_loaded, ChatDialog.state.buf) then return end

  vim.schedule(function()
    -- Get the last line and its content
    local last_line_content = api.nvim_buf_get_lines(ChatDialog.state.buf, -2, -1, false)[1] or ""

    -- Split the new text into lines
    local new_lines = vim.split(text, "\n", { plain = true })

    api.nvim_set_option_value("modifiable", true, { buf = ChatDialog.state.buf })
    -- Append the first line to the last line of the buffer
    local updated_last_line = last_line_content .. new_lines[1]
    api.nvim_buf_set_lines(ChatDialog.state.buf, -2, -1, false, { updated_last_line })

    -- Append the rest of the lines, if any
    if #new_lines > 1 then api.nvim_buf_set_lines(ChatDialog.state.buf, -1, -1, false, { unpack(new_lines, 2) }) end
    api.nvim_set_option_value("modifiable", false, { buf = ChatDialog.state.buf })

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
  local status, metadata, system_prompt, messages = pcall(ChatDialog.get_messages)
  if not status then
    print("Failed to parse chat. Please check your slash commands. " .. metadata)
  else
    ChatDialog.append_text("\n\n/assistant:\n")
    Http.stream(metadata, system_prompt, messages, ChatDialog.append_text, ChatDialog.on_complete)
  end
end

function ChatDialog.get_messages()
  if not (ChatDialog.state.buf and api.nvim_buf_is_valid(ChatDialog.state.buf)) then return nil end
  local lines = api.nvim_buf_get_lines(ChatDialog.state.buf, 0, -1, false)
  return parse_content(lines)
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
  cmp.register_source("nvimai_cmp_source", require("ai.cmp_source").new())

  -- Create an autocmd that sets up the cmp source when entering the chat buffer
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = chat_dialog_group,
    once = false,
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local sources = cmp.get_config().sources or {}
      local source_name = "nvimai_cmp_source"
      if bufnr == ChatDialog.state.buf then
        -- Check if the source is inserted before.
        if sources[1].name ~= source_name then
          -- table.insert(sources, 1, { name = source_name, group_index = 2 })
          -- NOTE: user complains about cannot see the keywords in the cmp list after lowering the priorty of the source
          table.insert(sources, 1, { name = source_name, group_index = 0 })
          cmp.setup.filetype({ "markdown", config.FILE_TYPE }, {
            sources,
          })
        end
      elseif sources[1].name == source_name then
        -- Remove source for other buffers
        table.remove(sources, 1)
      end
    end,
  })
end

function ChatDialog.setup()
  ChatDialog.config = vim.tbl_deep_extend("force", ChatDialog.config, config.config.ui or {})
  ChatDialog.setup_autocmd()
end

return ChatDialog
