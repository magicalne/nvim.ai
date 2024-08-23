local M = {}

M.BASE_PROVIDER_KEYS = { "endpoint", "model", "local", "deployment", "api_version", "proxy", "allow_insecure" }
M.FLIE_TYPE = "chat-dialog"

-- Add this near the top of the file, after the local M = {} line
local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

-- Default configuration
M.defaults = {
  debug = true,
  -- Chat Dialog UI configuration
  ui = {
    width = 80,     -- Width of the chat dialog window
    side = 'right', -- Side of the editor to open the dialog ('left' or 'right')
    borderchars = { '╭', '─', '╮', '│', '╯', '─', '╰', '│', },
    highlight = {
      border = "FloatBorder", -- Highlight group for the border
      background = "NormalFloat", -- Highlight group for the background
    },
    prompt_prefix = "❯ ", -- Prefix for the input prompt
  },

  -- LLM configuration
  provider = "ollama",
  openai = {
    endpoint = "https://api.openai.com",
    model = "gpt-4o",
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
  ollama = {
    endpoint = "http://localhost:11434",
    model = "gemma2",
    temperature = 0,
    max_tokens = 4096,
    ["local"] = true,
  },

  vendors = {},

  -- Keymaps
  keymaps = {
    toggle = "<leader>ct", -- Toggle chat dialog
    send = "<CR>",         -- Send message in normal mode
    newline = "<C-j>",     -- Insert newline in insert mode
    close = "q",           -- Close chat dialog
    clear = "<C-l>",       -- Clear chat history
  },

  -- Behavior
  behavior = {
    auto_open = true,                                              -- Automatically open dialog when sending a message
    save_history = true,                                           -- Save chat history between sessions
    history_file = vim.fn.stdpath("data") .. "/chat_history.json", -- Path to save chat history
    context_lines = 10,                                            -- Number of lines of code context to include in prompts
  },

  -- Appearance
  appearance = {
    icons = {
      user = "🧑", -- Icon for user messages
      assistant = "🤖", -- Icon for assistant messages
      system = "🖥️", -- Icon for system messages
      error = "❌", -- Icon for error messages
    },
    syntax_highlight = true, -- Syntax highlight code in responses
  },
}

M.has_provider = function(provider)
  return M.config[provider] ~= nil or M.vendors[provider] ~= nil
end

M.get_provider = function(provider)
  if M.config[provider] ~= nil then
    return vim.deepcopy(M.config[provider], true)
  elseif M.config.vendors[provider] ~= nil then
    return vim.deepcopy(M.config.vendors[provider], true)
  else
    error("Failed to find provider: " .. provider, 2)
  end
end

-- Function to merge user config with defaults
function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.defaults, user_config or {})

  -- Validate configuration
  assert(M.config.ui.side == 'left' or M.config.ui.side == 'right', "UI side must be 'left' or 'right'")
  assert(type(M.config.ui.width) == "number", "UI width must be a number")

  -- Set up API key
  -- if not M.config.llm.api_key then
  --   local env_var = M.config.llm.provider == "openai" and "OPENAI_API_KEY" or "ANTHROPIC_API_KEY"
  --   M.config.llm.api_key = vim.env[env_var]
  --   assert(M.config.llm.api_key, env_var .. " environment variable not set")
  -- end
end

function M:get(what)
  return M.config[what]
end

return M
