# nvim.ai

`nvim.ai` is a powerful Neovim plugin that brings AI-assisted coding and chat capabilities directly into your favorite editor. Inspired by Zed AI, it allows you to chat with your `buffers`, insert code with an inline assistant, and leverage various LLM providers for context-aware AI assistance.

## Chat with buffers

https://github.com/user-attachments/assets/5897f318-bf2c-4bd2-b4d3-51ce5b06d049

## Inline Assist

https://github.com/user-attachments/assets/a4eeb475-c753-4f6e-9c41-71e21e636c6c

Set up context and ask LLM to generate code. Use inline assist to insert/rewrite the code.

## /diagnostics
https://github.com/user-attachments/assets/d36abc9d-a81e-4b2e-9410-e7d538a3ed7f

Set up context with diagnostics from LSP.

## Features

- 🤖 Chat with buffers: Interact with AI about your code and documents
- 🧠 Context-aware AI assistance: Get relevant help based on your current work
- 📝 Inline assistant: Code insertion and rewriting
- 🛠️Slash Commands:
   - /buf with bufnr
   - /diagnostics with bufnr
- 🌐 Multiple LLM provider support:
   - Ollama (local)
   - Anthropic
   - Deepseek
   - Cohere
   - Gemini
   - Mistral
   - Groq
   - Sambanova
   - Hyperbolic
   - OpenAI (not tested)
- 🔧 Easy integration with nvim-cmp for command autocompletion

## Install

### vim-plug
```
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-lua/plenary.nvim'
Plug 'magicalne/nvim.ai', {'branch': 'main'}
```

### Lazy

```Lua
-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    {"nvim-treesitter/nvim-treesitter", build = ":TSUpdate"}, -- nvim.ai depends on treesitter
    {
      "magicalne/nvim.ai",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
      },
      opts = {
        provider = "anthropic", -- You can configure your provider, model or keymaps here.
      }
    },

  },
  -- ...
})
```

## Config

You can find all the config and keymaps from [here](https://github.com/magicalne/nvim.ai/blob/main/lua/ai/config.lua#L16).

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

#### Add you api keys to your dotfile

I put my keys in `~/.config/.env` and `source` it in my `.zshrc`.

```sh
export ANTHROPIC_API_KEY=""
export CO_API_KEY=""
export GROQ_API_KEY=""
export DEEPSEEK_API_KEY=""
export MISTRAL_API_KEY=""
export GOOGLE_API_KEY=""
export HYPERBOLIC_API_KEY=""
export OPENROUTER_API_KEY=""
export FAST_API_KEY=""
```

```Lua
local ai = require('ai')
ai.setup({
  --provider = "snova",
  --provider = "hyperbolic",
  --provider = "gemini",
  --provider = "mistral",
  provider = "anthropic",
  --provider = "deepseek",
  --provider = "groq",
  --provider = "cohere",
})
```

### OpenAI compatible API

#### Local LLM like `llamacpp` and `koboldcpp`

```Lua
local ai = require('ai')
ai.setup({
  provider = "openai",
  openai = {
    ["local "] = true,
    model = "llama3.1:70b",
    endpoint = "http://localhost:8080",
  }
})
```

### Default Keymaps

#### Chat
- <kbd>Leader</kbd><kbd>c</kbd> -- Toggle chat
- <kbd>Leader</kbd><kbd>\[</kbd> -- Open previous chat
- <kbd>Leader</kbd><kbd>\]</kbd> -- Open next chat
- <kbd>q</kbd> -- Close chat
- <kbd>Enter</kbd> -- Send message in normal mode
- <kbd>Control</kbd><kbd>l</kbd> -- Clear chat history

#### Inline Assist

- <kbd>Leader</kbd><kbd>i</kbd> — Insert code in normal mode with prompt, or rewrite section with in visual/selection mode.

## Usage

### Chat


The chat dialog is a special buffer. `nvim.ai` will parse the content with keywords. There are 3 roles in the buffer:
- **/system**: You can overwrite the system prompt by inserting `/system your_system_prompt` in the first line.
- **/you**: Lines after this are your prompt.
  - You can add buffers with `/buf {bufnr}`
  - Once you finish your prompt, you can send the request by pressing `Enter` in normal mode.
- **/assistant**: The streaming content from LLM will appear below this line.
Since the chat dialog is just a buffer, you can edit anything in it. Be aware that only the last block of `/you` will be treated as the prompt.
Just like [Zed AI](https://zed.dev/docs/assistant/assistant-panel), this feature is called "chat with context." You can edit the last prompt if you don't like the response, and you can do this back and forth.

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

By pressing <kbd>leader</kbd><kbd>i</kbd> and typing your instruction, you can insert or rewrite a code block anywhere in the current file.
Note that the `inline assist` can read the chat messages in the sidebar. Therefore, you can ask the LLM about your code and instruct it to generate a new function. Then, you can insert this new function by running `inline assist` with the prompt: `Insert the function`.

### Workflow with nvim.ai

The new way of working with `nvim.ai` is:
- Build context by chatting with the LLM.
- Ask the LLM to generate code.
- Apply the changes from the last chat using `inline assist`.

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
