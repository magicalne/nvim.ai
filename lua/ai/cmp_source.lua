local cmp = require("cmp")
local source = {}

-- List of special commands
local special_commands = {
  { label = "/system", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/you", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/buf", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/diagnostics", kind = cmp.lsp.CompletionItemKind.Keyword },
}

source.new = function() return setmetatable({}, { __index = source }) end

source.get_trigger_characters = function() return { "/" } end

source.get_keyword_pattern = function() return [[\%(/\k*\)]] end

source.complete = function(self, request, callback)
  local input = string.sub(request.context.cursor_before_line, request.offset)
  local items = {}
  local function cmd(c)
    local buffers = vim.api.nvim_list_bufs()
    for _, bufnr in ipairs(buffers) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name ~= "" then
          local short_name = vim.fn.fnamemodify(name, ":t") -- Get the tail (filename) of the path
          table.insert(items, {
            label = string.format("%s %d: %s", c, bufnr, short_name),
            kind = cmp.lsp.CompletionItemKind.File,
            data = { bufnr = bufnr },
            documentation = {
              kind = cmp.lsp.MarkupKind.Markdown,
              value = string.format("Buffer: %d\nFull path: %s", bufnr, name),
            },
          })
        end
      end
    end
  end

  if input:match("^/buf") then
    -- Handle /buf command
    cmd("/buf")
  elseif input:match("^/diagnostics") then
    -- Handle /diagnostics command
    cmd("/diagnostics")
  else
    -- Handle other special commands
    for _, command in ipairs(special_commands) do
      if command.label:find(input, 1, true) == 1 then table.insert(items, command) end
    end
  end

  callback({ items = items, isIncomplete = true })
end

return source
