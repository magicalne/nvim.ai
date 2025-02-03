local Utils = require("ai.utils")
local P = require("ai.providers")
local curl = require("plenary.curl")
local Config = require("ai.config")

local function generate_uuid_v4()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
    return string.format("%x", v)
  end)
end

local M = {}

M.AUTH_KEY = "GIGACHAT_AUTH_KEY"

function M.has() return vim.fn.executable("curl") == 1 and os.getenv(M.AUTH_KEY) ~= nil end

M.RqUID = os.getenv("GIGACHAT_RqUID")

local function get_rquid()
  if M.RqUID then
    return M.RqUID
  else
    M.RqUID = generate_uuid_v4()
    return M.RqUID
  end
end

M.api_key = nil
M.api_key_expires = 0
M.api_key_received_in = 0
M.api_key_timeout = 50000

local function update_api_key()
  local provider = Config.get_provider("gigachat")
  local base, body_opts = P.parse_config(provider)
  local rquid = get_rquid()
  local auth_key = os.getenv(M.AUTH_KEY)
  local response = curl.post({
    url = base.auth_endpoint,
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
      ["Accept"] = "application/json",
      ["RqUID"] = rquid,
      ["Authorization"] = "Bearer " .. auth_key,
    },
    body = {
      scope = "GIGACHAT_API_PERS",
    },
    follow_location = true,
  })

  if not response then error("Filed to update API key") end

  local body = vim.json.decode(response.body)
  M.api_key = body.access_token
  M.api_key_expires = body.expires_in
  M.api_key_received_in = os.time()
end

local function get_api_key()
  local now = os.time()
  if M.api_key == nil or now - M.api_key_received_in > M.api_key_timeout or now > M.api_key_expires then
    update_api_key()
  end
  return M.api_key
end

function M.parse_response(data_stream, _, on_chunk)
  if data_stream == nil or data_stream == "" then return end
  local data_match = data_stream:match("^data: (.+)$")
  if data_match == "[DONE]" or data_match == nil then
    --opts.on_complete(nil)
  else
    local json = vim.json.decode(data_match)
    if json.choices and #json.choices > 0 then
      local content = json.choices[1].delta.content or ""
      on_chunk(content)
    end
  end
end

function M.parse_curl_args(provider, request)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
    ["Accept"] = "application/json",
    ["Authorization"] = "Bearer " .. get_api_key(),
  }

  local messages = {
    {
      role = "system",
      content = request.system_prompt,
    },
  }

  for _, message in ipairs(request.messages) do
    table.insert(messages, message)
  end

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/chat/completions",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      messages = messages,
      model = base.model,
      temperature = base.temperature or 1,
      max_tokens = base.max_tokens or 1024,
      top_p = 1,
      stream = true,
    }, body_opts),
  }
end

return M
