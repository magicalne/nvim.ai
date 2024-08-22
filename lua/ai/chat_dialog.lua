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
}

local function create_buf()
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_option(buf, 'filetype', 'chat-dialog')
  return buf
end

local function get_win_config()
  local width = ChatDialog.config.width
  local height = api.nvim_get_option('lines')
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

function ChatDialog.open()
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_set_current_win(state.win)
    return
  end

  state.buf = state.buf or create_buf()
  local win_config = get_win_config()
  state.win = api.nvim_open_win(state.buf, true, win_config)

  -- Set window options
  api.nvim_win_set_option(state.win, 'wrap', false)
  api.nvim_win_set_option(state.win, 'cursorline', true)

  -- Set buffer options
  -- api.nvim_buf_set_option(state.buf, 'modifiable', false)

  -- Set keymaps
  local opts = { noremap = true, silent = true, buffer = state.buf }
  vim.keymap.set('n', 'q', ChatDialog.close, opts)
  -- vim.cmd("setlocal buftype=terminal")
  -- vim.cmd("termcmd ChatDialog")

  vim.keymap.set("n", "<CR>", function()
    local cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    local lines = vim.api.nvim_buf_get_lines(state.buf, 0, cursor_row, false)

    local prefix_lines = vim.list_slice(lines, 1, cursor_row)

    local prompt = table.concat(prefix_lines, "\n")

    Assistant.llm(prompt, ChatDialog.append_text, ChatDialog.on_complete)

    --llm.chat(prompt, function(response)
      --  vim.api.nvim_buf_set_text(buffer_id, -1, 0, -1, 1, { response })
      --end)
    end, { noremap = true })
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
    print('Done')
  end
  function ChatDialog.append_text(text)
    if not (state.buf and api.nvim_buf_is_valid(state.buf)) then return end

    -- FIXME: it's not a line
    local lines = vim.split(text, "\n")
    api.nvim_buf_set_option(state.buf, "modifiable", true)
    api.nvim_buf_set_lines(state.buf, -1, -1, false, lines)
    api.nvim_buf_set_option(state.buf, "modifiable", false)

    -- Scroll to bottom
    if state.win and api.nvim_win_is_valid(state.win) then
      local line_count = api.nvim_buf_line_count(state.buf)
      api.nvim_win_set_cursor(state.win, {line_count, 0})
    end

    --
    local scroll_to_bottom = function()
      local last_line = api.nvim_buf_line_count(state.buf)

      local current_lines = Utils.get_buf_lines(last_line - 1, last_line, state.buf)

      if #current_lines > 0 then
        local last_line_content = current_lines[1]
        local last_col = #last_line_content
        xpcall(function()
          api.nvim_win_set_cursor(state.win, { last_line, last_col })
        end, function(err)
        return err
      end)
    end
  end

  vim.schedule(function()
    if not state.buf or not api.nvim_buf_is_valid(state.buf) then
      return
    end
    scroll_to_bottom()
    local lines = vim.split(content, "\n")
    Utils.unlock_buf(state.buf)
    api.nvim_buf_call(state.buf)
    Utils.lock_buf(state.buf)
    api.nvim_set_option_value("filetype", "Avante", { buf = state.buf })
    if opts.scroll then
      scroll_to_bottom()
    end
    if opts.callback ~= nil then
      opts.callback()
    end
  end)
end

function ChatDialog.clear()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then return end

  api.nvim_buf_set_option(state.buf, "modifiable", true)
  api.nvim_buf_set_lines(state.buf, 0, -1, false, {})
  api.nvim_buf_set_option(state.buf, "modifiable", false)
end

function ChatDialog.prompt_user(prompt)
  return fn.input(prompt)
end

function ChatDialog.setup()

  ChatDialog.config = vim.tbl_deep_extend("force", ChatDialog.config, config.config.ui or {})
  -- Create user commands
  api.nvim_create_user_command("ChatDialogToggle", ChatDialog.toggle, {})

  -- Set up keymaps
  vim.keymap.set("n", "<leader>ct", ChatDialog.toggle, {noremap = true, silent = true})
end

return ChatDialog
