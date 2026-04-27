return {
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  'farmergreg/vim-lastplace',
  'MunifTanjim/nui.nvim',
  'nvim-mini/mini.pick',
  'ibhagwan/fzf-lua',
  'stevearc/dressing.nvim',
  'folke/snacks.nvim',
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {},
  },
  {
    'yetone/avante.nvim',
    -- ⚠️ must add this setting! ! !
    build = vim.fn.has 'win32' ~= 0 and 'powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false' or 'make',
    event = 'VimEnter',
    version = false, -- Never set this value to "*"! Never!
    ---@module 'avante'
    ---@type avante.Config
    opts = {
      -- this file can contain specific instructions for your project
      instructions_file = 'avante.md',
      provider = 'openrouter_free',
      web_search_engine = {
        provider = 'tavily', -- tavily, serpapi, google, kagi, brave, or searxng
        proxy = nil,
      },
      providers = {
        openrouter_free = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'openrouter/free',
        },
        openrouter_auto = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'openrouter/auto',
        },
        openrouter_haiku = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'anthropic/claude-haiku-4.5:floor',
        },
        openrouter_sonnet = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'anthropic/claude-sonnet-4.6:floor',
        },
        openrouter_opus = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'anthropic/claude-opus-4.7:floor',
        },
        openrouter_deepseek_4_pro = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'deepseek/deepseek-v4-pro:floor',
        },
        openrouter_deepseek_4_flash = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'deepseek/deepseek-v4-flash:floor',
        },
        openrouter_qwen = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'qwen/qwen3-coder-next:floor',
        },
        openrouter_llama = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'nvidia/llama-3.3-nemotron-super-49b-v1.5:floor',
        },
        openrouter_mistral = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'mistralai/codestral-2508:floor',
        },
        openrouter_gemini = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'google/gemini-2.5-flash:floor',
        },
        openrouter_gemma = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'google/gemma-4-31b-it:floor',
        },
        openrouter_kimi = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'moonshotai/kimi-k2.6:floor',
        },
        openrouter_glm = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'z-ai/glm-5.1:floor',
        },
        openrouter_mimo = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'xiaomi/mimo-v2.5-pro:floor',
        },
        openrouter_minimax = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'minimax/minimax-m2.7:floor',
        },
      },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      --- The below dependencies are optional,
      'nvim-mini/mini.pick', -- for file_selector provider mini.pick
      'nvim-telescope/telescope.nvim', -- for file_selector provider telescope
      'hrsh7th/nvim-cmp', -- autocompletion for avante commands and mentions
      'ibhagwan/fzf-lua', -- for file_selector provider fzf
      'stevearc/dressing.nvim', -- for input provider dressing
      'folke/snacks.nvim', -- for input provider snacks
      'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
      --'zbirenbaum/copilot.lua', -- for providers='copilot'
      {
        -- support for image pasting
        'HakonHarnes/img-clip.nvim',
        event = 'VeryLazy',
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { 'markdown', 'Avante' },
        },
        ft = { 'markdown', 'Avante' },
      },
    },
  },
  {
    'folke/trouble.nvim',
    opts = {}, -- for default options, refer to the configuration section for custom setup.
    cmd = 'Trouble',
    keys = {
      {
        '<leader>xx',
        '<cmd>Trouble diagnostics toggle<cr>',
        desc = 'Diagnostics (Trouble)',
      },
      {
        '<leader>xX',
        '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
        desc = 'Buffer Diagnostics (Trouble)',
      },
      {
        '<leader>cs',
        '<cmd>Trouble symbols toggle focus=false<cr>',
        desc = 'Symbols (Trouble)',
      },
      {
        '<leader>cl',
        '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
        desc = 'LSP Definitions / references / ... (Trouble)',
      },
      {
        '<leader>xL',
        '<cmd>Trouble loclist toggle<cr>',
        desc = 'Location List (Trouble)',
      },
      {
        '<leader>xQ',
        '<cmd>Trouble qflist toggle<cr>',
        desc = 'Quickfix List (Trouble)',
      },
    },
  },
}
