# nvim.ai

`nvim.ai` is a powerful Neovim plugin that brings AI-assisted coding and chat capabilities directly into your favorite editor. Inspired by Zed AI, it allows you to chat with your `buffers`, insert code with an inline assistant, and leverage various LLM providers for context-aware AI assistance.

## Chat with buffers

![Chat with buffers](https://github.com/user-attachments/assets/32f9b649-32af-4a0c-8c79-be3647ccc953)

## Features

- 🤖 Chat with buffers: Interact with AI about your code and documents
- 🧠 Context-aware AI assistance: Get relevant help based on your current work
- 📝 Inline assistant:
 - ✅ Code insertion
 - 🚧 Code rewriting (Work in Progress)
- 🌐 Multiple LLM provider support:
   - Ollama (local)
   - Anthropic
   - Deepseek
   - Groq
   - Cohere
   - OpenAI (not tested)
- 🔧 Easy integration with nvim-cmp for command autocompletion

## Install

```
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-lua/plenary.nvim'
Plug 'magicalne/nvim.ai', {'branch': 'main'}
```

## Config

You can find all the config from [here](https://github.com/magicalne/nvim.ai/blob/main/lua/ai/config.lua#L16).

### Ollama

```Lua
local ai = require('ai')
ai.setup({
  provider = "ollama",
  ollama = {
    model = "llama3.1:70b", -- You can start with smaller one like `gemma2` or `llama3.1`
    --endpoint = "http://192.168.2.47:11434", -- In case you access ollama from another machine
  }
})
```

### Others

```Lua
local ai = require('ai')
ai.setup({
  provider = "deepseek", --  "anthropic", "groq", "cohere"
})
```

### Integrate with cmp

If may want to autocomplete commands with `cmp`:

```Lua
sources = cmp.config.sources({
  { name = 'nvimai_cmp_source' },
  --...
}
```

### Default Keymaps

#### Chat
- <kbd>Leader</kbd><kbd>c</kbd> -- Toggle chat
- <kbd>q</kbd> -- Close chat
- <kbd>Enter</kbd> -- Send message in normal mode
- <kbd>Contrl</kbd><kbd>l</kbd> -- Clear chat history

#### Inline Assist

- <kbd>Leader</kbd><kbd>i</kbd> — Insert code in normal mode with prompt
- <kbd>Leader</kbd><kbd>i</kbd><kbd>a</kbd> — Accept the inserted code
- <kbd>Leader</kbd><kbd>i</kbd><kbd>j</kbd> — Reject the inserted code

## Usage

### Chat

The chat dialog is a special buffer. `nvim.ai` will parse the content with keywords. There are 3 roles in the buffer:
- **/system**: You can overwrite the system prompt by inserting `/system your_system_prompt` in the first line.
- **/you**: Lines after this are your prompt.
  - You can add buffers with `/buf {bufnr}` (Autocomplete with `nvim_cmp_source` in `cmp` is recommended.)
  - Once you finish your prompt, you can send the request by pressing `Enter` in normal mode.
- **/assistant**: The streaming content from LLM will appear below this line.
Since the chat dialog is just a buffer, you can edit anything in it. Be aware that only the last block of `/you` will be treated as the prompt.
Just like Zed AI, this feature is called "chat with context." You can edit the last prompt if you don't like the response, and you can do this back and forth.

Here is an example:

```
/system You are an expert on lua and neovim plugin development.

/you

/buf 1: init.lua

How to blablabla?

/assistance:
...
```

### Context-Aware Assistance

#### Inline Assist

By pressing <kbd>leader</kbd><kbd>i</kbd> and typing your instruction, you can insert a code block anywhere in the current file.
Alternatively, you can run the command with `:NvimAIInlineAssist {YOUR_PROMPT}`.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgements

This project is inspired by:
- [Zed Editor](https://zed.dev/)
- [avante.nvim](https://github.com/yetone/avante.nvim)

## License

nvim.ai is licensed under the Apache License. For more details, please refer to the [LICENSE](https://github.com/magicalne/nvim.ai/blob/main/LICENSE) file.


---

⚠️ Note: This plugin is under active development. Features and usage may change.
