local M = {}

M.BASE_PROVIDER_KEYS = { "endpoint", "model", "local", "deployment", "api_version", "proxy", "allow_insecure" }
M.FILE_TYPE = "chat-dialog"

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
  deepseek = {
    endpoint = "https://api.deepseek.com",
    model = "deepseek-chat", -- or command-r
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
  cohere = {
    endpoint = "https://api.cohere.com",
    model = "command-r-plus", -- or command-r
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
  groq = {
    endpoint = "https://api.groq.com",
    model = "llama-3.1-70b-versatile", -- or llama3.1-7b-instant, llama3.1:405b, gemma2-9b-it
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
  anthropic = {
    endpoint = "https://api.anthropic.com",
    model = "claude-3-5-sonnet-20240620",
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
  mistral = {
    endpoint = "https://api.mistral.ai",
    model = "mistral-large-latest", -- or open-mistral-nemo, codestral-latest, open-mistral-7b, open-mixtral-8x22b
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
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

  saved_chats_dir = vim.fn.stdpath("data") .. "/nvim.ai/saved_chats",

  -- Keymaps
  keymaps = {
    toggle = "<leader>c",       -- Toggle chat dialog
    send = "<CR>",               -- Send message in normal mode
    close = "q",                 -- Close chat dialog
    clear = "<C-l>",             -- Clear chat history
    inline_assist = "<leader>i", -- Run InlineAssist command with prompt
    accept_code = "<leader>ia",
    reject_code = "<leader>ij",
  },

  -- Behavior
  behavior = {
    auto_open = true,                     -- Automatically open dialog when sending a message
    save_history = true,                  -- Save chat history between sessions
    history_dir = vim.fn.stdpath("data"), -- Path to save chat history
  },

  -- TODO: Appearance
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

function M.get(what)
  return M.config[what]
end

return M
