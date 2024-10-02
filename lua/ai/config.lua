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
    width = 80, -- Width of the chat dialog window
    side = "right", -- Side of the editor to open the dialog ('left' or 'right')
    borderchars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
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
  -- api: https://aistudio.google.com/app/apikey
  -- models: https://ai.google.dev/gemini-api/docs/models/gemini#gemini-1.5-pro
  gemini = {
    endpoint = "https://generativelanguage.googleapis.com",
    model = "gemini-1.5-flash-latest", -- or gemini-1.5-pro-latest
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
  hyperbolic = {
    endpoint = "https://api.hyperbolic.xyz",
    model = "meta-llama/Meta-Llama-3.1-70B-Instruct", -- or meta-llama/Meta-Llama-3.1-405B
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
  cerebras = {
    endpoint = "https://api.cerebras.ai",
    model = "llama3.1-70b", -- or llama3.1-8b
    temperature = 0,
    max_tokens = 8192,
    ["local"] = false,
  },
  snova = {
    endpoint = "https://fast-api.snova.ai",
    model = "Meta-Llama-3.1-70B-Instruct", -- or Meta-Llama-3.1-70B-Instruct, Meta-Llama-3.1-8B-Instruct, Meta-Llama-3.1-405B-Instruct
    temperature = 0,
    max_tokens = 3000, --sambanova's context is smaller: https://community.sambanova.ai/t/quick-start-guide/104
    ["local"] = false,
  },
  groq = {
    endpoint = "https://api.groq.com",
    model = "llama-3.1-70b-versatile", -- or llama3.1-7b-instant, llama3.1:405b, gemma2-9b-it
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
    toggle          = "<leader>c", -- Toggle chat dialog
    send            = "<CR>",      -- Send message in normal mode
    close           = "q",         -- Close chat dialog
    clear           = "<C-l>",     -- Clear chat history
    previous_chat   = "<leader>[", -- Open previous chat from history
    next_chat       = "<leader>]", -- Open next chat from history
    inline_assist   = "<leader>i", -- Run InlineAssist command with prompt
    stop_generate   = "<C-c>",     -- Stop generating
  },

  -- Behavior
  behavior = {
    auto_open = true, -- Automatically open dialog when sending a message
    save_history = true, -- Save chat history between sessions
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

M.has_provider = function(provider) return M.config[provider] ~= nil or M.vendors[provider] ~= nil end

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
  assert(M.config.ui.side == "left" or M.config.ui.side == "right", "UI side must be 'left' or 'right'")
end

function M.update_provider(new_provider) M.config.provider = new_provider end

function M.get(what) return M.config[what] end

return M
