local api = vim.api

local Config = require("ai.config")
local Utils = require("ai.utils")

local M = {}

setmetatable(M, {
  __index = function(t, k)
    if Config.config.vendors[k] ~= nil then
      local v = Config.config.vendors[k]

      -- Patch from vendors similar to supported providers.
      t[k] = setmetatable({}, { __index = v })
      t[k].API_KEY = v.api_key_name
      -- Hack for aliasing and makes it sane for us.
      t[k].parse_response = v.parse_response_data
      t[k].has = function()
        return os.getenv(v.api_key_name) and true or false
      end

      return t[k]
    end

    t[k] = require("ai.providers." .. k)
    return t[k]
  end,
})

---@class EnvironmentHandler
local E = {}

---@private
E._once = false

--- intialize the environment variable for current neovim session.
--- This will only run once and spawn a UI for users to input the envvar.
---@private
E.setup = function(opts)
end

---@param provider Provider
E.is_local = function(provider)
  local cur = M.get(provider)
  return cur["local"] ~= nil and cur["local"] or false
end

M.env = E

M.setup = function()
  M.commands()
end

---@private
---@param provider Provider
function M.refresh(provider)
  local p = M[Config.config.provider]
  if not p.has() then
    E.setup({ provider = p, refresh = true })
  else
    Utils.info("Switch to provider: " .. provider, { once = true, title = "nvim.ai" })
  end
  require("ai.config").override({ provider = provider })
end

local default_providers = { "openai", "anthropic", "deepseek", "groq", "gemini", "cohere", "hyperbolic", "mistral", "ollama" }

---@private
M.commands = function()
  api.nvim_create_user_command("NvimAISwitchProvider", function(args)
    local cmd = vim.trim(args.args or "")
    M.refresh(cmd)
  end, {
    nargs = 1,
    desc = "nvim.ai: switch provider",
    complete = function(_, line)
      if line:match("^%s*NvimAISwitchProvider %w") then
        return {}
      end
      local prefix = line:match("^%s*NvimAISwitchProvider (%w*)") or ""
      -- join two tables
      local Keys = vim.list_extend(default_providers, vim.tbl_keys(Config.config.vendors or {}))
      return vim.tbl_filter(function(key)
        return key:find(prefix) == 1
      end, Keys)
    end,
  })
end

M.parse_config = function(opts)
  ---@type BaseProvider
  local s1 = {}
  ---@type table<string, any>
  local s2 = {}

  for key, value in pairs(opts) do
    if vim.tbl_contains(Config.BASE_PROVIDER_KEYS, key) then
      s1[key] = value
    else
      s2[key] = value
    end
  end

  return s1,
      vim
      .iter(s2)
      :filter(function(k, v)
        return type(v) ~= "function"
      end)
      :fold({}, function(acc, k, v)
        acc[k] = v
        return acc
      end)
end

---@private
---@param provider Provider
M.get = function(provider)
  local cur = Config.get_provider(provider or Config.config.provider)
  return type(cur) == "function" and cur() or cur
end

return M
